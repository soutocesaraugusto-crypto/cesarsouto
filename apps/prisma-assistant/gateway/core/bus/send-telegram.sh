#!/usr/bin/env bash
# send-telegram.sh - Send a Telegram message or photo, optionally with inline keyboard
# Usage: send-telegram.sh <chat_id> "<message>" [inline_keyboard_json]
#        send-telegram.sh <chat_id> "<caption>" --image /path/to/image.jpg
#        send-telegram.sh <chat_id> "<message>" --topic permissions
#        send-telegram.sh <chat_id> "<message>" --progressive
#        send-telegram.sh <chat_id> "<message>" --edit <message_id>
#
# Uses shared pipeline modules: _message-pipeline.sh (sanitize, chunk, rate-limit)
# Uses shared typing module: _typing-indicator.sh (stop on send)

set -euo pipefail

TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
CRM_AGENT_NAME="${CRM_AGENT_NAME:-$(basename "$(pwd)")}"
ME="${CRM_AGENT_NAME}"

# Parse arguments
CHAT_ID="${1:-}"
MESSAGE="${2:-}"
KEYBOARD=""
IMAGE_PATH=""
TOPIC_NAME=""
TOPIC_ID=""
PROGRESSIVE=false
EDIT_MSG_ID=""

shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --image)
            IMAGE_PATH="${2:-}"
            shift 2
            ;;
        --topic)
            TOPIC_NAME="${2:-}"
            shift 2
            ;;
        --progressive)
            PROGRESSIVE=true
            shift
            ;;
        --edit)
            EDIT_MSG_ID="${2:-}"
            shift 2
            ;;
        *)
            KEYBOARD="$1"
            shift
            ;;
    esac
done

# Always source .env to get BOT_TOKEN
ENV_FILE="${TEMPLATE_ROOT}/agents/${ME}/.env"
{ set +x; } 2>/dev/null
if [[ -f "${ENV_FILE}" ]]; then
    set -a; source "${ENV_FILE}"; set +a
elif [[ -f ".env" ]]; then
    set -a; source ".env"; set +a
fi

if [[ -z "${BOT_TOKEN:-}" ]]; then
    echo "ERROR: No bot token configured for ${ME}" >&2
    exit 1
fi

# Source shared modules
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_telegram-curl.sh"
source "${SCRIPT_DIR}/_logger.sh"
source "${SCRIPT_DIR}/_message-pipeline.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/_typing-indicator.sh" 2>/dev/null || true

# --- Stop typing indicator (started by fast-checker on message receive) ---
typing_stop "telegram" 2>/dev/null || true

# --- Dry-run mode ---
if is_dry_run; then
    crm_log "dry_run" "Would send telegram message" "chat_id=${CHAT_ID}" "msg_len=${#MESSAGE}" "topic=${TOPIC_NAME:-none}"
    echo "DRY_RUN: message not sent (${#MESSAGE} chars to ${CHAT_ID})"
    exit 0
fi

# --- Resolve Forum Topic ID from name ---
if [[ -n "${TOPIC_NAME}" ]]; then
    TOPIC_VAR="TOPIC_$(echo "${TOPIC_NAME}" | tr '[:lower:]' '[:upper:]')"
    TOPIC_ID="${!TOPIC_VAR:-}"
fi

# --- Edit-in-place mode ---
if [[ -n "${EDIT_MSG_ID}" ]]; then
    pipeline_rate_limit "telegram" 100
    MESSAGE=$(pipeline_sanitize_html "$MESSAGE")
    EDIT_ARGS=(-d chat_id="${CHAT_ID}" --data-urlencode "text=${MESSAGE}" -d parse_mode="HTML")
    [[ -n "${TOPIC_ID}" ]] && EDIT_ARGS+=(-d message_thread_id="${TOPIC_ID}")
    RESPONSE=$(telegram_api_post_retry "editMessageText" \
        -d message_id="${EDIT_MSG_ID}" \
        "${EDIT_ARGS[@]}")
    if echo "${RESPONSE}" | jq -e '.ok' > /dev/null 2>&1; then
        echo "${EDIT_MSG_ID}"
        exit 0
    fi
    # Edit failed — fall through to normal send below
    EDIT_MSG_ID=""
fi

# --- Progressive mode: track last message_id for edit-in-place ---
PROGRESSIVE_FILE="/tmp/crm-progressive-${ME}.txt"

# --- Send photo if --image provided ---
if [[ -n "${IMAGE_PATH}" ]]; then
    if [[ ! -f "${IMAGE_PATH}" ]]; then
        echo "ERROR: Image file not found: ${IMAGE_PATH}" >&2
        exit 1
    fi
    RESPONSE=$(telegram_api_post_retry "sendPhoto" \
        -F "chat_id=${CHAT_ID}" \
        -F "photo=@${IMAGE_PATH}" \
        -F "caption=${MESSAGE}" \
        -F "parse_mode=HTML")
    if echo "${RESPONSE}" | jq -e '.ok' > /dev/null 2>&1; then
        echo "${RESPONSE}" | jq -r '.result.message_id'
    else
        ERR_DESC=$(echo "${RESPONSE}" | jq -r '.description // "Unknown error"' 2>/dev/null)
        crm_log_error "send_photo" "Failed to send photo" "chat_id=${CHAT_ID}" "error=${ERR_DESC}"
        QUEUE_SCRIPT="${SCRIPT_DIR}/delivery-queue.sh"
        if [[ -f "${QUEUE_SCRIPT}" && -n "${MESSAGE}" ]]; then
            bash "${QUEUE_SCRIPT}" enqueue "${ME}" telegram "${CHAT_ID}" "[Photo failed] ${MESSAGE}" 2>/dev/null || true
        fi
        echo "ERROR: Failed to send photo (caption queued for retry)" >&2
        exit 1
    fi
    exit 0
fi

# --- Sanitize message (markdown → HTML) via shared pipeline ---
MESSAGE=$(pipeline_sanitize_html "$MESSAGE")

# --- Telegram-specific send function (used by pipeline_chunk_and_send) ---
# Receives: chunk, is_first, is_last
_tg_send_chunk() {
    local chunk="$1" is_first="$2" is_last="$3"
    local kb=""
    # Keyboard only on last chunk
    [[ "${is_last}" == "true" ]] && kb="${KEYBOARD}"

    pipeline_rate_limit "telegram" 100

    local topic_args=""
    [[ -n "${TOPIC_ID}" ]] && topic_args="-d message_thread_id=${TOPIC_ID}"

    if [[ -n "${kb}" ]]; then
        local kb_valid
        kb_valid=$(echo "${kb}" | jq -c '.' 2>/dev/null || echo '{"inline_keyboard":[]}')
        local payload
        payload=$(jq -n -c \
            --argjson chat_id "${CHAT_ID}" \
            --arg text "${chunk}" \
            --argjson markup "${kb_valid}" \
            '{chat_id: $chat_id, text: $text, parse_mode: "HTML", reply_markup: $markup}')
        [[ -n "${TOPIC_ID}" ]] && payload=$(echo "${payload}" | jq -c --argjson tid "${TOPIC_ID}" '. + {message_thread_id: $tid}')
        LAST_RESPONSE=$(telegram_api_post_retry "sendMessage" \
            -H "Content-Type: application/json" \
            -d "${payload}")
    else
        LAST_RESPONSE=$(telegram_api_post_retry "sendMessage" \
            -d chat_id="${CHAT_ID}" \
            --data-urlencode "text=${chunk}" \
            -d parse_mode="HTML" \
            ${topic_args})

        # HTML parse failed → retry as plain text
        if ! echo "$LAST_RESPONSE" | jq -e '.ok' > /dev/null 2>&1; then
            local err_desc
            err_desc=$(echo "$LAST_RESPONSE" | jq -r '.description // ""' 2>/dev/null)
            if [[ "$err_desc" == *"parse"* || "$err_desc" == *"entities"* || "$err_desc" == *"Can't"* ]]; then
                local plain_text
                plain_text=$(printf '%s' "$chunk" | sed -E 's/<[^>]+>//g; s/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g')
                LAST_RESPONSE=$(telegram_api_post_retry "sendMessage" \
                    -d chat_id="${CHAT_ID}" \
                    --data-urlencode "text=${plain_text}" \
                    ${topic_args})
            fi
        fi
    fi

    # Suppress output for non-last chunks
    [[ "${is_last}" != "true" ]] && return 0
    echo "${LAST_RESPONSE}"
}

# --- Progressive mode: try edit-in-place for short messages ---
MSG_LEN=${#MESSAGE}
TG_MAX=4096

if [[ "${PROGRESSIVE}" == "true" && ${MSG_LEN} -le ${TG_MAX} ]]; then
    PREV_MSG_ID=$(cat "${PROGRESSIVE_FILE}" 2>/dev/null || echo "")
    if [[ -n "${PREV_MSG_ID}" ]]; then
        pipeline_rate_limit "telegram" 100
        EDIT_ARGS=(-d chat_id="${CHAT_ID}" --data-urlencode "text=${MESSAGE}" -d message_id="${PREV_MSG_ID}")
        [[ -n "${TOPIC_ID}" ]] && EDIT_ARGS+=(-d message_thread_id="${TOPIC_ID}")
        EDIT_RESPONSE=$(telegram_api_post_retry "editMessageText" "${EDIT_ARGS[@]}" 2>/dev/null)
        if echo "${EDIT_RESPONSE}" | jq -e '.ok' > /dev/null 2>&1; then
            echo "${PREV_MSG_ID}"
            exit 0
        fi
    fi
fi

# --- Send via shared pipeline (auto-chunk at 4096, code-fence-aware) ---
LAST_RESPONSE=""
pipeline_chunk_and_send "$MESSAGE" ${TG_MAX} "_tg_send_chunk"

# --- Check success of last chunk ---
if echo "${LAST_RESPONSE}" | jq -e '.ok' > /dev/null 2>&1; then
    SENT_MSG_ID=$(echo "${LAST_RESPONSE}" | jq -r '.result.message_id')
    [[ "${PROGRESSIVE}" == "true" ]] && echo "${SENT_MSG_ID}" > "${PROGRESSIVE_FILE}" 2>/dev/null || true
    echo "${SENT_MSG_ID}"
else
    ERR_DESC=$(echo "${LAST_RESPONSE}" | jq -r '.description // "Unknown error"' 2>/dev/null)
    crm_log_error "send_telegram" "Failed to send message" "chat_id=${CHAT_ID}" "error=${ERR_DESC}" "msg_len=${#MESSAGE}"
    # Write-ahead queue handles retry via send-channel.sh (nack on exit 1)
    echo "ERROR: Failed to send message" >&2
    exit 1
fi
