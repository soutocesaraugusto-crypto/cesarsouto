#!/usr/bin/env bash
# fast-checker.sh - High-frequency Telegram + inbox poller
# Injects messages into the live Claude Code tmux session via send-keys
# Usage: fast-checker.sh <agent> <tmux_session> <agent_dir> <template_root>
# Lifecycle: started by agent-wrapper.sh after tmux session is created;
#            killed by agent-wrapper.sh when tmux session dies
#
# Modes:
#   ADAPTER_MODE=false (default) — polls Telegram via check-telegram.sh + checks agent inbox
#   ADAPTER_MODE=true            — reads channel-inbox/ (adapters write normalized JSON here)
#                                  + reads agent inbox (inter-agent messages)
#                                  No direct Telegram polling — adapters handle that
#   WEBHOOK_MODE=true            — legacy alias for ADAPTER_MODE=true (backward compat)

set -uo pipefail

AGENT="$1"
TMUX_SESSION="$2"
AGENT_DIR="$3"
TEMPLATE_ROOT="$4"

# Load runtime driver (Story 114.1) — provides runtime_detect_busy/idle, runtime_builtin_commands
export CRM_AGENT_NAME="${AGENT}"
_RUNTIME_AGENT_DIR="${AGENT_DIR}"
source "${TEMPLATE_ROOT}/core/runtimes/runtime.sh"
# Load instance ID
REPO_ENV="${TEMPLATE_ROOT}/.env"
if [[ -f "${REPO_ENV}" ]]; then
    CRM_INSTANCE_ID=$(grep '^CRM_INSTANCE_ID=' "${REPO_ENV}" | cut -d= -f2)
fi
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${HOME}/.claude-remote/${CRM_INSTANCE_ID}"
export CRM_ROOT
BUS_DIR="${TEMPLATE_ROOT}/core/bus"
LOG_FILE="${CRM_ROOT}/logs/${AGENT}/fast-checker.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [fast-checker/${AGENT}] $1" >> "$LOG_FILE"
}

# Build regex pattern for runtime built-in commands (runtime-agnostic)
BUILTIN_CMDS=$(runtime_builtin_commands)
BUILTIN_PATTERN="^/($(echo "${BUILTIN_CMDS}" | tr ' ' '|'))$"

log "Starting. Waiting for agent to finish bootstrapping..."

# Wait for Claude Code to be ready before injecting messages.
# Detects readiness by checking for the "permissions" status bar text
# in the tmux pane, which only appears once Claude Code's UI is fully
# initialized. Falls back to 30s fixed wait if the text is never found
# (e.g., if Claude Code changes its UI in a future version).
BOOT_TIMEOUT=30
BOOT_ELAPSED=0
while [[ ${BOOT_ELAPSED} -lt ${BOOT_TIMEOUT} ]]; do
    if tmux capture-pane -t "${TMUX_SESSION}:0.0" -p 2>/dev/null | grep -q "permissions"; then
        break
    fi
    sleep 2
    BOOT_ELAPSED=$((BOOT_ELAPSED + 2))
done

log "Bootstrap wait complete. Beginning poll loop."

# Detect if the runtime is actively processing (busy).
# Delegates to the runtime driver's detect_busy/detect_idle functions.
# Returns 0 if busy, 1 if idle (ready for input).
is_runtime_busy() {
    runtime_detect_busy "${TMUX_SESSION}"
}

# Inject a block of messages into the Claude Code session.
# If Claude is busy, waits up to BUSY_WAIT_MAX seconds for it to become idle.
inject_messages() {
    local content="$1"

    # Wait for Claude to be idle before injecting (Story 110.28 Phase 3)
    local busy_wait=0
    local busy_max=10  # Max 10s wait (reduced from 30s for faster response)
    while is_runtime_busy && [[ ${busy_wait} -lt ${busy_max} ]]; do
        if [[ ${busy_wait} -eq 0 ]]; then
            log "Claude busy — holding messages (up to ${busy_max}s)"
        fi
        sleep 2
        busy_wait=$((busy_wait + 2))
    done
    if [[ ${busy_wait} -gt 0 ]]; then
        log "Claude idle after ${busy_wait}s wait — injecting"
    fi

    local tmpfile
    tmpfile=$(mktemp "${CRM_ROOT}/logs/${AGENT}/.crm-msg-XXXXXX.txt" 2>/dev/null) || {
        log "mktemp failed - skipping injection to avoid bare Enter"
        return 1
    }
    chmod 600 "$tmpfile"
    printf '%s' "$content" > "$tmpfile"
    local byte_count
    byte_count=$(wc -c < "$tmpfile" | tr -d ' ')

    # load-buffer reads the file into tmux's paste buffer (handles raw bytes).
    # paste-buffer uses bracketed paste mode to inject the content directly
    # into Claude's input field inline. Enter submits.
    tmux load-buffer -b "crm-${AGENT}" "$tmpfile"
    tmux paste-buffer -t "${TMUX_SESSION}:0.0" -b "crm-${AGENT}"
    sleep 0.3  # Let paste content land in PTY buffer before sending Enter
    tmux send-keys -t "${TMUX_SESSION}:0.0" Enter
    rm -f "$tmpfile"

    log "Injected ${byte_count} bytes inline via paste-buffer"
}

# Main poll loop
cd "$AGENT_DIR"

# Determine reply command template based on mode (set once, used in message formatting)
# ADAPTER_MODE: agent replies via send-channel.sh <platform> <chat_id>
# Legacy mode: agent replies via send-telegram.sh <chat_id>
_ADAPTER_MODE="${ADAPTER_MODE:-${WEBHOOK_MODE:-false}}"
if [[ "${_ADAPTER_MODE}" == "true" ]]; then
    _reply_cmd() { echo "CRM_AGENT_NAME=${AGENT} bash ../../core/bus/send-channel.sh $1 $2 \"<your reply>\""; }
    _send_cmd() { echo "CRM_AGENT_NAME=${AGENT} bash ../../core/bus/send-channel.sh $1 $2"; }
else
    _reply_cmd() { echo "CRM_AGENT_NAME=${AGENT} bash ../../core/bus/send-telegram.sh $2 \"<your reply>\""; }
    _send_cmd() { echo "CRM_AGENT_NAME=${AGENT} bash ../../core/bus/send-telegram.sh $2"; }
fi

# Source Telegram helpers, typing indicator, and agent .env
source "${BUS_DIR}/_telegram-curl.sh"
source "${BUS_DIR}/_typing-indicator.sh" 2>/dev/null || true
ENV_FILE="${TEMPLATE_ROOT}/agents/${AGENT}/.env"
{ set +x; } 2>/dev/null
if [[ -f "$ENV_FILE" ]]; then
    set -a; source "$ENV_FILE"; set +a
elif [[ -f ".env" ]]; then
    set -a; source ".env"; set +a
fi

# Send a question from the ask state file to Telegram (inlined to avoid env issues)
send_next_question() {
    local q_idx="$1"
    local state_file="/tmp/crm-ask-state-${AGENT}.json"

    if [[ ! -f "$state_file" ]]; then
        log "send_next_question: state file not found"
        return 1
    fi

    local total_q q_text q_header q_multi q_options q_opt_count msg keyboard
    total_q=$(jq -r '.total_questions // 1' "$state_file")
    q_text=$(jq -r ".questions[${q_idx}].question // \"Question\"" "$state_file")
    q_header=$(jq -r ".questions[${q_idx}].header // empty" "$state_file" || echo "")
    q_multi=$(jq -r ".questions[${q_idx}].multiSelect // false" "$state_file")
    q_options=$(jq -c ".questions[${q_idx}].options // []" "$state_file")
    q_opt_count=$(echo "$q_options" | jq 'length')

    msg="QUESTION ($((q_idx+1))/${total_q}) - ${AGENT}:"
    [[ -n "$q_header" ]] && msg+=$'\n'"${q_header}"
    msg+=$'\n'"${q_text}"$'\n'

    if [[ "$q_multi" == "true" ]]; then
        msg+=$'\n'"(Multi-select: tap options to toggle, then tap Submit)"
    fi

    for i in $(seq 0 $((q_opt_count - 1))); do
        local label
        label=$(echo "$q_options" | jq -r ".[$i] // \"Option $((i+1))\"")
        msg+=$'\n'"$((i+1)). ${label}"
    done

    if [[ "$q_multi" == "true" ]]; then
        keyboard=$(echo "$q_options" | jq -c '[to_entries[] | [{
            text: (.value // "Option \(.key + 1)"),
            callback_data: "asktoggle_'"$q_idx"'_\(.key)"
        }]] + [[{text: "Submit Selections", callback_data: "asksubmit_'"$q_idx"'"}]]')
    else
        keyboard=$(echo "$q_options" | jq -c '[to_entries[] | [{
            text: (.value // "Option \(.key + 1)"),
            callback_data: "askopt_'"$q_idx"'_\(.key)"
        }]]')
    fi
    keyboard="{\"inline_keyboard\":${keyboard}}"

    telegram_api_post "sendMessage" \
        -H "Content-Type: application/json" \
        -d "$(jq -n -c \
            --arg chat_id "$CHAT_ID" \
            --arg text "$msg" \
            --argjson reply_markup "$keyboard" \
            '{chat_id: $chat_id, text: $text, reply_markup: $reply_markup}')" > /dev/null 2>&1

    log "Sent question $((q_idx+1))/${total_q} to Telegram"
}

while true; do
    # Exit if tmux session is gone
    if ! tmux has-session -t "${TMUX_SESSION}" 2>/dev/null; then
        log "Tmux session gone. Exiting."
        exit 0
    fi

    MESSAGE_BLOCK=""

    # --- Telegram (polling or webhook-via-inbox) ---
    # ADAPTER_MODE is the primary flag; WEBHOOK_MODE is a backward-compat alias
    ADAPTER_MODE="${ADAPTER_MODE:-${WEBHOOK_MODE:-false}}"
    TG_OUTPUT=""

    if [[ "${ADAPTER_MODE}" == "true" ]]; then
        # Adapter mode: read all messages from channel-inbox/ (adapters write normalized JSON here).
        # See core/schemas/adapter-message.schema.json for the message contract.
        CHANNEL_INBOX="${CRM_ROOT}/channel-inbox/${AGENT}"
        if [[ -d "${CHANNEL_INBOX}" ]]; then
            for wh_file in "${CHANNEL_INBOX}"/*.json; do
                [[ ! -f "${wh_file}" ]] && continue
                CONTENT=$(cat "${wh_file}" 2>/dev/null || echo "")
                if [[ -n "${CONTENT}" ]]; then
                    TG_OUTPUT+="${CONTENT}"$'\n'
                fi
                rm -f "${wh_file}"
            done
        fi
    else
        TG_OUTPUT=$(bash "${BUS_DIR}/check-telegram.sh" 2>/dev/null || echo "")
    fi
    # Typing loop is started per-message inside the processing loop below (after CHAT_ID is parsed)
    if [[ -n "$TG_OUTPUT" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            # Parse normalized fields (adapter-message schema or legacy check-telegram output)
            TYPE=$(echo "$line" | jq -r '._type // .type // "message"' 2>/dev/null || echo "message")
            FROM=$(echo "$line" | jq -r '.from // "unknown"' 2>/dev/null || echo "unknown")
            TEXT=$(echo "$line" | jq -r '.text // ""' 2>/dev/null || echo "")
            CHAT_ID=$(echo "$line" | jq -r '.chat_id // ""' 2>/dev/null || echo "")
            MSG_PLATFORM=$(echo "$line" | jq -r '.platform // ._source // "telegram"' 2>/dev/null || echo "telegram")
            REPLY_CMD=$(_reply_cmd "${MSG_PLATFORM}" "${CHAT_ID}")

            # Start persistent typing indicator (refreshes every 2s until response sent)
            # Uses shared _typing-indicator.sh module; stopped by send-{channel}.sh
            if [[ -n "${CHAT_ID}" && -n "${BOT_TOKEN:-}" ]]; then
                typing_start "${MSG_PLATFORM}" "${BOT_TOKEN:-}" "${CHAT_ID}"
            fi

            # Sanitize FROM to prevent header/newline injection (Story 110.26)
            FROM=$(printf '%s' "$FROM" | tr -d '\n\r' | tr -cd '[:alnum:]_ -')
            if [[ -z "${FROM}" ]]; then FROM="unknown"; fi

            if [[ "$TYPE" == "callback" ]]; then
                DATA=$(echo "$line" | jq -r '.callback_data // ""' 2>/dev/null || echo "")
                # Validate callback_data length (Telegram max: 64 bytes)
                if [[ ${#DATA} -gt 256 ]]; then
                    log "Rejected oversized callback_data (${#DATA} chars)"
                    continue
                fi
                MSG_ID=$(echo "$line" | jq -r '._message_id // .message_id // ""' 2>/dev/null || echo "")
                CALLBACK_QID=$(echo "$line" | jq -r '.callback_query_id // ""' 2>/dev/null || echo "")

                # Permission hook callbacks: write response file instead of injecting into tmux
                if [[ "$DATA" =~ ^perm_(allow|deny|continue)_([a-f0-9]+)$ ]]; then
                    PERM_DECISION="${BASH_REMATCH[1]}"
                    PERM_ID="${BASH_REMATCH[2]}"
                    RESPONSE_FILE="/tmp/crm-hook-response-${AGENT}-${PERM_ID}.json"

                    HOOK_DECISION="$PERM_DECISION"
                    if [[ "$PERM_DECISION" == "continue" ]]; then
                        HOOK_DECISION="deny"
                    fi

                    printf '{"decision":"%s"}\n' "$HOOK_DECISION" > "$RESPONSE_FILE"

                    bash "${BUS_DIR}/answer-callback.sh" "$CALLBACK_QID" "Got it" 2>/dev/null || true
                    DECISION_LABEL="$(echo "$PERM_DECISION" | sed 's/allow/Approved/;s/deny/Denied/;s/continue/Continue in Chat/')"
                    bash "${BUS_DIR}/edit-message.sh" "$CHAT_ID" "$MSG_ID" "${DECISION_LABEL}" 2>/dev/null || true

                    log "Permission callback: ${PERM_DECISION} for ${PERM_ID}"
                    continue
                fi

                # === AskUserQuestion handlers ===
                ASK_STATE="/tmp/crm-ask-state-${AGENT}.json"
                # Single-select: askopt_{questionIdx}_{optionIdx}
                if [[ "$DATA" =~ ^askopt_([0-9]+)_([0-9]+)$ ]]; then
                    Q_IDX="${BASH_REMATCH[1]}"
                    O_IDX="${BASH_REMATCH[2]}"

                    bash "${BUS_DIR}/answer-callback.sh" "$CALLBACK_QID" "Got it" 2>/dev/null || true
                    bash "${BUS_DIR}/edit-message.sh" "$CHAT_ID" "$MSG_ID" "Answered" 2>/dev/null || true

                    # Navigate TUI: Down * O_IDX, then Enter to select + advance
                    for ((k=0; k<O_IDX; k++)); do
                        tmux send-keys -t "${TMUX_SESSION}:0.0" Down
                        sleep 0.1
                    done
                    sleep 0.2
                    tmux send-keys -t "${TMUX_SESSION}:0.0" Enter

                    log "AskUserQuestion: Q${Q_IDX} selected option ${O_IDX}"

                    # Check if there are more questions to send
                    if [[ -f "$ASK_STATE" ]]; then
                        TOTAL_Q=$(jq -r '.total_questions // 1' "$ASK_STATE" 2>/dev/null)
                        NEXT_Q=$((Q_IDX + 1))
                        if [[ $NEXT_Q -lt $TOTAL_Q ]]; then
                            # Update state
                            jq --argjson nq "$NEXT_Q" '.current_question = $nq' "$ASK_STATE" > "${ASK_STATE}.tmp" && mv "${ASK_STATE}.tmp" "$ASK_STATE"
                            # Send next question via Telegram after short delay for TUI to advance
                            sleep 0.5
                            send_next_question "$NEXT_Q"
                        else
                            # Last question answered - hit Enter on the Submit button
                            sleep 0.5
                            tmux send-keys -t "${TMUX_SESSION}:0.0" Enter
                            log "AskUserQuestion: submitted all answers"
                            rm -f "$ASK_STATE"
                        fi
                    fi
                    continue
                fi

                # Multi-select toggle: asktoggle_{questionIdx}_{optionIdx}
                if [[ "$DATA" =~ ^asktoggle_([0-9]+)_([0-9]+)$ ]]; then
                    Q_IDX="${BASH_REMATCH[1]}"
                    O_IDX="${BASH_REMATCH[2]}"

                    bash "${BUS_DIR}/answer-callback.sh" "$CALLBACK_QID" "Toggled" 2>/dev/null || true

                    # Track toggled selections in state file
                    if [[ -f "$ASK_STATE" ]]; then
                        # Toggle: add if not present, remove if present
                        CURRENT=$(jq -r ".multi_select_chosen | index($O_IDX)" "$ASK_STATE" 2>/dev/null)
                        if [[ "$CURRENT" == "null" ]]; then
                            jq --argjson idx "$O_IDX" '.multi_select_chosen += [$idx]' "$ASK_STATE" > "${ASK_STATE}.tmp" && mv "${ASK_STATE}.tmp" "$ASK_STATE"
                        else
                            jq --argjson idx "$O_IDX" '.multi_select_chosen -= [$idx]' "$ASK_STATE" > "${ASK_STATE}.tmp" && mv "${ASK_STATE}.tmp" "$ASK_STATE"
                        fi

                        # Update the Telegram message to show current selections
                        CHOSEN=$(jq -r '.multi_select_chosen | sort | map(. + 1) | map(tostring) | join(", ")' "$ASK_STATE" 2>/dev/null)
                        if [[ -n "$CHOSEN" && "$CHOSEN" != "" ]]; then
                            bash "${BUS_DIR}/edit-message.sh" "$CHAT_ID" "$MSG_ID" "Selected: ${CHOSEN}
Tap more options or Submit" '{"inline_keyboard":'"$(jq -c '.questions['"$Q_IDX"'].options | [to_entries[] | [{text: (.value // "Option \(.key+1)"), callback_data: "asktoggle_'"$Q_IDX"'_\(.key)"}]] + [[{text: "Submit Selections", callback_data: "asksubmit_'"$Q_IDX"'"}]]' "$ASK_STATE" 2>/dev/null)"'}' 2>/dev/null || true
                        fi
                    fi

                    log "AskUserQuestion: Q${Q_IDX} toggled option ${O_IDX}"
                    continue
                fi

                # Multi-select submit: asksubmit_{questionIdx}
                if [[ "$DATA" =~ ^asksubmit_([0-9]+)$ ]]; then
                    Q_IDX="${BASH_REMATCH[1]}"

                    bash "${BUS_DIR}/answer-callback.sh" "$CALLBACK_QID" "Submitted" 2>/dev/null || true
                    bash "${BUS_DIR}/edit-message.sh" "$CHAT_ID" "$MSG_ID" "Submitted" 2>/dev/null || true

                    if [[ -f "$ASK_STATE" ]]; then
                        # Get chosen indices and navigate TUI
                        CHOSEN_INDICES=$(jq -r '.multi_select_chosen | sort | .[]' "$ASK_STATE" 2>/dev/null)

                        # For multi-select TUI: navigate to each chosen option and press Space
                        TOTAL_OPTS=$(jq -r ".questions[${Q_IDX}].options | length" "$ASK_STATE" 2>/dev/null || echo "4")
                        CURRENT_POS=0
                        for idx in $CHOSEN_INDICES; do
                            MOVES=$((idx - CURRENT_POS))
                            for ((k=0; k<MOVES; k++)); do
                                tmux send-keys -t "${TMUX_SESSION}:0.0" Down
                                sleep 0.1
                            done
                            tmux send-keys -t "${TMUX_SESSION}:0.0" Space
                            sleep 0.1
                            CURRENT_POS=$idx
                        done
                        # Navigate past all options (including "Other") to the Submit button
                        # Options count + 1 for "Other" auto-added by Claude Code
                        SUBMIT_POS=$((TOTAL_OPTS + 1))
                        REMAINING=$((SUBMIT_POS - CURRENT_POS))
                        for ((k=0; k<REMAINING; k++)); do
                            tmux send-keys -t "${TMUX_SESSION}:0.0" Down
                            sleep 0.1
                        done
                        sleep 0.2
                        tmux send-keys -t "${TMUX_SESSION}:0.0" Enter

                        log "AskUserQuestion: Q${Q_IDX} submitted multi-select"

                        # Check for more questions
                        TOTAL_Q=$(jq -r '.total_questions // 1' "$ASK_STATE" 2>/dev/null)
                        NEXT_Q=$((Q_IDX + 1))
                        # Reset multi_select_chosen for next question
                        jq '.multi_select_chosen = []' "$ASK_STATE" > "${ASK_STATE}.tmp" && mv "${ASK_STATE}.tmp" "$ASK_STATE"

                        if [[ $NEXT_Q -lt $TOTAL_Q ]]; then
                            jq --argjson nq "$NEXT_Q" '.current_question = $nq' "$ASK_STATE" > "${ASK_STATE}.tmp" && mv "${ASK_STATE}.tmp" "$ASK_STATE"
                            sleep 0.5
                            send_next_question "$NEXT_Q"
                        else
                            # Last question answered - hit Enter on the Submit button
                            sleep 0.5
                            tmux send-keys -t "${TMUX_SESSION}:0.0" Enter
                            log "AskUserQuestion: submitted all answers"
                            rm -f "$ASK_STATE"
                        fi
                    fi
                    continue
                fi

                MESSAGE_BLOCK+="=== ${MSG_PLATFORM^^} CALLBACK from ${FROM} (chat_id:${CHAT_ID}) ===
callback_data: \`${DATA}\`
message_id: ${MSG_ID}
Reply using: ${REPLY_CMD}

"
            elif [[ "$TYPE" == "photo" ]]; then
                IMAGE_PATH=$(echo "$line" | jq -r '.media.local_path // .image_path // ""' 2>/dev/null || echo "")
                MESSAGE_BLOCK+="=== ${MSG_PLATFORM^^} PHOTO from ${FROM} (chat_id:${CHAT_ID}) ===
caption:
\`\`\`
${TEXT}
\`\`\`
local_file: ${IMAGE_PATH}
Reply using: ${REPLY_CMD}

"
            elif [[ "$TYPE" == "document" ]]; then
                DOC_PATH=$(echo "$line" | jq -r '.document_path // ""' 2>/dev/null || echo "")
                DOC_NAME=$(echo "$line" | jq -r '.file_name // ""' 2>/dev/null || echo "")
                MESSAGE_BLOCK+="=== ${MSG_PLATFORM^^} DOCUMENT from ${FROM} (chat_id:${CHAT_ID}) ===
caption:
\`\`\`
${TEXT}
\`\`\`
file_name: ${DOC_NAME}
local_file: ${DOC_PATH}
Reply using: ${REPLY_CMD}

"
            else
                # CRM session management commands (handled directly, not injected into Claude)
                if [[ "$TEXT" == "/help" ]]; then
                    CURRENT_MODEL=$(jq -r '.model // "default"' "${AGENT_DIR}/config.json" 2>/dev/null || echo "unknown")
                    bash "${BUS_DIR}/send-telegram.sh" "${CHAT_ID}" "Gateway Commands:

/help — Show this menu
/model — Show current model
/model <name> — Switch model (haiku, sonnet, opus)
/status — Agent status
/new — Clear conversation (keep session)
/restart — Soft restart (preserve history)
/hardreset — Fresh session (lose context)
/logs — Recent activity logs
/update — Re-sync Telegram commands

Current model: ${CURRENT_MODEL}" > /dev/null 2>&1 || true
                    log "Session command: /help"
                    continue
                elif [[ "$TEXT" =~ ^/model($|[[:space:]]) ]]; then
                    MODEL_ARG=$(echo "$TEXT" | sed 's|^/model[[:space:]]*||')
                    CONFIG_FILE="${AGENT_DIR}/config.json"
                    CURRENT_MODEL=$(jq -r '.model // "default"' "${CONFIG_FILE}" 2>/dev/null || echo "unknown")
                    if [[ -z "$MODEL_ARG" ]]; then
                        bash "${BUS_DIR}/send-telegram.sh" "${CHAT_ID}" "Current model: ${CURRENT_MODEL}

Available models:
  haiku — claude-haiku-4-5 (fast, cheap)
  sonnet — claude-sonnet-4-5 (balanced)
  opus — claude-opus-4-6 (powerful)

Usage: /model haiku" > /dev/null 2>&1 || true
                        log "Session command: /model (show current)"
                    else
                        case "$MODEL_ARG" in
                            haiku)  NEW_MODEL="claude-haiku-4-5" ;;
                            sonnet) NEW_MODEL="claude-sonnet-4-5" ;;
                            opus)   NEW_MODEL="claude-opus-4-6" ;;
                            *)      NEW_MODEL="$MODEL_ARG" ;;
                        esac
                        if jq --arg m "$NEW_MODEL" '.model = $m' "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp" 2>/dev/null; then
                            mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"
                            bash "${BUS_DIR}/send-telegram.sh" "${CHAT_ID}" "Model changed: ${CURRENT_MODEL} → ${NEW_MODEL}
Restarting to apply..." > /dev/null 2>&1 || true
                            log "Session command: /model ${MODEL_ARG} → ${NEW_MODEL}"
                            bash "${BUS_DIR}/self-restart.sh" --reason "model change to ${NEW_MODEL}" > /dev/null 2>&1 &
                        else
                            rm -f "${CONFIG_FILE}.tmp"
                            bash "${BUS_DIR}/send-telegram.sh" "${CHAT_ID}" "Error: Failed to update config.json" > /dev/null 2>&1 || true
                            log "Session command: /model ERROR"
                        fi
                    fi
                    continue
                elif [[ "$TEXT" == "/status" ]]; then
                    CURRENT_MODEL=$(jq -r '.model // "default"' "${AGENT_DIR}/config.json" 2>/dev/null || echo "unknown")
                    UPTIME_SECS=$(( $(date +%s) - $(date -r "${CRM_ROOT}/logs/${AGENT}/activity.log" +%s 2>/dev/null || echo "$(date +%s)") ))
                    SESSION_ID=$(tmux display-message -t "${TMUX_SESSION}" -p '#{session_id}' 2>/dev/null || echo "?")
                    QUEUE_COUNT=$(find "${CRM_ROOT}/queue/${AGENT}/pending" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
                    bash "${BUS_DIR}/send-telegram.sh" "${CHAT_ID}" "Agent Status:
  Model: ${CURRENT_MODEL}
  Session: ${SESSION_ID}
  Queue: ${QUEUE_COUNT} pending
  Adapter: telegram (polling)" > /dev/null 2>&1 || true
                    log "Session command: /status"
                    continue
                elif [[ "$TEXT" == "/new" ]]; then
                    MESSAGE_BLOCK+="/clear
"
                    log "Session command: /new → /clear"
                elif [[ "$TEXT" == "/restart" ]]; then
                    bash "${BUS_DIR}/send-telegram.sh" "${CHAT_ID}" "Restarting with --continue (preserving history)..." > /dev/null 2>&1 || true
                    bash "${BUS_DIR}/self-restart.sh" --reason "user /restart from Telegram" > /dev/null 2>&1 &
                    log "Session command: /restart (soft)"
                    continue
                elif [[ "$TEXT" == "/hardreset" ]]; then
                    bash "${BUS_DIR}/send-telegram.sh" "${CHAT_ID}" "Hard restart (fresh session)..." > /dev/null 2>&1 || true
                    bash "${BUS_DIR}/hard-restart.sh" --reason "user /hardreset from Telegram" > /dev/null 2>&1 &
                    log "Session command: /hardreset"
                    continue
                elif [[ "$TEXT" == "/update" ]]; then
                    bash "${BUS_DIR}/send-telegram.sh" "${CHAT_ID}" "Re-syncing Telegram commands..." > /dev/null 2>&1 || true
                    update_result=$(bash "${TEMPLATE_ROOT}/core/scripts/register-telegram-commands.sh" \
                        "${BOT_TOKEN}" "$(pwd)" "${AGENT_DIR}" 2>&1)
                    bash "${BUS_DIR}/send-telegram.sh" "${CHAT_ID}" "${update_result}" > /dev/null 2>&1 || true
                    log "Session command: /update → ${update_result}"
                    continue
                elif [[ "$TEXT" == "/logs" ]]; then
                    logfile="${CRM_ROOT}/logs/${AGENT}/activity.log"
                    recent=$(tail -20 "${logfile}" 2>/dev/null || echo "No logs available")
                    bash "${BUS_DIR}/send-telegram.sh" "${CHAT_ID}" "Recent logs:
\`\`\`
${recent}
\`\`\`" --topic logs > /dev/null 2>&1 || true
                    log "Session command: /logs"
                    continue
                # Built-in CLI commands: inject raw so they trigger directly
                elif [[ "$TEXT" =~ ${BUILTIN_PATTERN} ]]; then
                    MESSAGE_BLOCK+="${TEXT}
"
                # /terminal: bridge de arquivo (NÃO é skill) — injeta como mensagem normal pra Prisma tratar
                elif [[ "$TEXT" =~ ^/terminal($|[[:space:]]) ]]; then
                    MESSAGE_BLOCK+="=== ${MSG_PLATFORM^^} from ${FROM} (chat_id:${CHAT_ID}) ===
\`\`\`
${TEXT}
\`\`\`
Reply using: ${REPLY_CMD}

"
                    log "Bridge command: /terminal"
                # Skill commands (e.g. /commit, /spy, /deploy): inject as skill invocation
                # These are registered via register-telegram-commands.sh and map to Claude Code skills
                elif [[ "$TEXT" =~ ^/([a-z0-9_]+)(.*)$ ]]; then
                    SKILL_CMD="${BASH_REMATCH[1]}"
                    SKILL_ARGS="${BASH_REMATCH[2]}"
                    # Convert underscore back to hyphen (Telegram sanitizes - to _)
                    SKILL_NAME=$(echo "${SKILL_CMD}" | tr '_' '-')
                    SKILL_ARGS=$(echo "${SKILL_ARGS}" | sed 's/^[[:space:]]*//')
                    MESSAGE_BLOCK+="/${SKILL_NAME} ${SKILL_ARGS}
"
                    log "Skill command: /${SKILL_NAME} ${SKILL_ARGS}"
                else
                    MESSAGE_BLOCK+="=== ${MSG_PLATFORM^^} from ${FROM} (chat_id:${CHAT_ID}) ===
\`\`\`
${TEXT}
\`\`\`
Reply using: ${REPLY_CMD}

"
                fi
            fi
        done <<< "$TG_OUTPUT"
    fi

    # --- Agent Inbox ---
    INBOX_OUTPUT=$(bash "${BUS_DIR}/check-inbox.sh" 2>/dev/null || echo "[]")
    MSG_COUNT=$(echo "$INBOX_OUTPUT" | jq 'length' 2>/dev/null || echo "0")
    INBOX_MSG_IDS=()
    if [[ "$MSG_COUNT" -gt 0 ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            FROM=$(echo "$line" | jq -r '.from // "unknown"' 2>/dev/null || echo "unknown")
            TEXT=$(echo "$line" | jq -r '.text // ""' 2>/dev/null || echo "")
            MSG_ID=$(echo "$line" | jq -r '.id // ""' 2>/dev/null || echo "")
            REPLY_TO=$(echo "$line" | jq -r '.reply_to // ""' 2>/dev/null || echo "")

            # Sanitize FROM to prevent header injection
            if [[ ! "${FROM}" =~ ^[a-z0-9_-]+$ ]]; then
                FROM="unknown"
            fi

            INBOX_MSG_IDS+=("$MSG_ID")

            REPLY_NOTE=""
            [[ -n "$REPLY_TO" ]] && REPLY_NOTE=" [reply_to: ${REPLY_TO}]"

            # Extract constraints if present (Story 114.8)
            CONSTRAINTS_BLOCK=""
            CONSTRAINTS_JSON=$(echo "$line" | jq -r '.constraints // empty' 2>/dev/null || echo "")
            if [[ -n "${CONSTRAINTS_JSON}" ]]; then
                ALLOWED=$(echo "${CONSTRAINTS_JSON}" | jq -r '.allowed // [] | join(", ")' 2>/dev/null || echo "")
                BLOCKED=$(echo "${CONSTRAINTS_JSON}" | jq -r '.blocked // [] | join(", ")' 2>/dev/null || echo "")
                [[ -n "${ALLOWED}" ]] && CONSTRAINTS_BLOCK+="CONSTRAINTS: allowed=[${ALLOWED}]"
                [[ -n "${BLOCKED}" ]] && CONSTRAINTS_BLOCK+=" blocked=[${BLOCKED}]"
                CONSTRAINTS_BLOCK+=$'\n'
            fi

            MESSAGE_BLOCK+="=== AGENT MESSAGE from ${FROM}${REPLY_NOTE} [msg_id: ${MSG_ID}] ===
${CONSTRAINTS_BLOCK}\`\`\`
${TEXT}
\`\`\`
Reply using: bash ../../core/bus/send-message.sh ${FROM} normal '<your reply>' ${MSG_ID}

"
        done < <(echo "$INBOX_OUTPUT" | jq -c '.[]' 2>/dev/null)
    fi

    # --- Batch window: accumulate rapid messages before injecting ---
    # If we got messages, wait briefly for more to arrive (e.g., user sending
    # multiple lines quickly). This coalesces them into a single injection.
    if [[ -n "$MESSAGE_BLOCK" ]]; then
        sleep 0.5
        # Second poll to catch rapid follow-ups
        TG_EXTRA=""
        if [[ "${ADAPTER_MODE}" == "true" ]]; then
            for wh_file in "${CRM_ROOT}/channel-inbox/${AGENT}"/*.json; do
                [[ ! -f "${wh_file}" ]] && continue
                CONTENT=$(cat "${wh_file}" 2>/dev/null || echo "")
                [[ -n "${CONTENT}" ]] && TG_EXTRA+="${CONTENT}"$'\n'
                rm -f "${wh_file}"
            done
        else
            TG_EXTRA=$(bash "${BUS_DIR}/check-telegram.sh" 2>/dev/null || echo "")
        fi
        if [[ -n "$TG_EXTRA" ]]; then
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                TYPE=$(echo "$line" | jq -r '._type // .type // "message"' 2>/dev/null || echo "message")
                # Only batch text messages; callbacks still need immediate handling
                [[ "$TYPE" != "message" ]] && continue
                FROM=$(echo "$line" | jq -r '.from // "unknown"' 2>/dev/null || echo "unknown")
                TEXT=$(echo "$line" | jq -r '.text // ""' 2>/dev/null || echo "")
                B_CHAT_ID=$(echo "$line" | jq -r '.chat_id // ""' 2>/dev/null || echo "")
                B_PLATFORM=$(echo "$line" | jq -r '.platform // ._source // "telegram"' 2>/dev/null || echo "telegram")
                B_REPLY_CMD=$(_reply_cmd "${B_PLATFORM}" "${B_CHAT_ID}")
                FROM=$(printf '%s' "$FROM" | tr -d '\n\r' | tr -cd '[:alnum:]_ -')
                if [[ -z "${FROM}" ]]; then FROM="unknown"; fi
                if [[ "$TEXT" =~ ${BUILTIN_PATTERN} ]]; then
                    MESSAGE_BLOCK+="${TEXT}
"
                else
                    MESSAGE_BLOCK+="=== ${B_PLATFORM^^} from ${FROM} (chat_id:${B_CHAT_ID}) ===
\`\`\`
${TEXT}
\`\`\`
Reply using: ${B_REPLY_CMD}

"
                fi
            done <<< "$TG_EXTRA"
            log "Batched follow-up messages"
        fi

        if inject_messages "$MESSAGE_BLOCK"; then
            for ack_id in "${INBOX_MSG_IDS[@]+"${INBOX_MSG_IDS[@]}"}"; do
                bash "${BUS_DIR}/ack-inbox.sh" "$ack_id" 2>/dev/null || true
            done
            # Cooldown after injection
            sleep 5
        fi
    fi

    sleep 1
done
