#!/usr/bin/env bash
# context-monitor.sh — Auto-compact when context exceeds threshold
#
# Called from agent-wrapper.sh watchdog loop every 60s.
# Detects context growth via tmux pane line count and triggers
# runtime-specific compression.
#
#
# Actions by runtime:
#   claude-code: inject /compact via tmux send-keys
#   codex:       no native compact — generate handoff + restart
#   api:         trim JSONL conversation history
#
# Usage: context-monitor.sh <agent> <tmux_session> <template_root>
#
# Epic 114 / Story 114.16 Phase 2

set -uo pipefail

AGENT="${1:-}"
TMUX_SESSION="${2:-}"
TEMPLATE_ROOT="${3:-}"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${HOME}/.claude-remote/${CRM_INSTANCE_ID}"
LOG_FILE="${CRM_ROOT}/logs/${AGENT}/activity.log"
STATE_FILE="${CRM_ROOT}/state/${AGENT}/.context-monitor.json"

# Threshold: 80% of estimated context window
# Opus 4.6: ~200K tokens ≈ ~800K chars ≈ ~16000 lines (at ~50 chars/line)
THRESHOLD_LINES="${CONTEXT_THRESHOLD_LINES:-12800}"
COOLDOWN_SECONDS=600  # Don't compact again within 10 minutes

_log() {
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [context-monitor/${AGENT}] $1" >> "${LOG_FILE}" 2>/dev/null
}

# Check if we compacted recently
_in_cooldown() {
    if [[ -f "${STATE_FILE}" ]]; then
        local last_compact
        last_compact=$(jq -r '.last_compact_ts // 0' "${STATE_FILE}" 2>/dev/null || echo "0")
        local now
        now=$(date +%s)
        local elapsed=$((now - last_compact))
        [[ ${elapsed} -lt ${COOLDOWN_SECONDS} ]] && return 0
    fi
    return 1
}

_record_compact() {
    local now
    now=$(date +%s)
    local count
    count=$(jq -r '.compact_count // 0' "${STATE_FILE}" 2>/dev/null || echo "0")
    count=$((count + 1))
    jq -n -c --argjson ts "$now" --argjson count "$count" \
        '{last_compact_ts: $ts, compact_count: $count}' > "${STATE_FILE}" 2>/dev/null || true
}

# Main check
[[ -z "${AGENT}" || -z "${TMUX_SESSION}" ]] && exit 0

# Skip if tmux session doesn't exist
tmux has-session -t "${TMUX_SESSION}" 2>/dev/null || exit 0

# Skip if in cooldown
_in_cooldown && exit 0

# Estimate context size via tmux scrollback line count
# capture-pane -S - captures entire scrollback buffer
LINE_COUNT=$(tmux capture-pane -t "${TMUX_SESSION}:0.0" -p -S - 2>/dev/null | wc -l | tr -d ' ')

if [[ ${LINE_COUNT} -lt ${THRESHOLD_LINES} ]]; then
    exit 0  # Below threshold, nothing to do
fi

_log "Context threshold reached: ${LINE_COUNT} lines (threshold: ${THRESHOLD_LINES}). Triggering compression."

# Load runtime driver to determine compression strategy
export CRM_AGENT_NAME="${AGENT}"
AGENT_DIR="${TEMPLATE_ROOT}/agents/${AGENT}"
_RUNTIME_AGENT_DIR="${AGENT_DIR}"

# Read runtime type from config
RUNTIME_TYPE=$(jq -r '.runtime // "claude-code"' "${AGENT_DIR}/config.json" 2>/dev/null || echo "claude-code")

case "${RUNTIME_TYPE}" in
    claude-code)
        # Claude Code: inject /compact command
        # Wait for idle first (don't interrupt active processing)
        source "${TEMPLATE_ROOT}/core/runtimes/runtime.sh"
        if runtime_detect_idle "${TMUX_SESSION}"; then
            tmux send-keys -t "${TMUX_SESSION}:0.0" "/compact" Enter
            _log "Injected /compact (CC). Lines before: ${LINE_COUNT}"
            _record_compact
        else
            _log "Agent busy, deferring /compact to next cycle"
        fi
        ;;
    codex)
        # Codex: no native compact. Generate handoff + soft restart.
        _log "Codex has no /compact. Consider restart with handoff if context degrades."
        # Don't auto-restart — too disruptive. Just log warning.
        # User can trigger /restart manually.
        _record_compact  # Prevent repeated warnings
        ;;
    api-openrouter)
        # API: Hermes-inspired compression (protect head/tail + LLM summary)
        API_CLIENT="${TEMPLATE_ROOT}/core/runtimes/api-client.py"
        if [[ -f "${API_CLIENT}" ]]; then
            # Source .env for API key
            ENV_FILE="${TEMPLATE_ROOT}/agents/${AGENT}/.env"
            if [[ -f "${ENV_FILE}" ]]; then
                set -a; source "${ENV_FILE}" 2>/dev/null; set +a
            fi
            export CRM_AGENT_NAME="${AGENT}" CRM_INSTANCE_ID="${CRM_INSTANCE_ID}"
            COMPRESS_RESULT=$(python3 "${API_CLIENT}" --compress 2>&1)
            _log "API compression: ${COMPRESS_RESULT}"
            _record_compact
        else
            _log "api-client.py not found, skipping API compression"
        fi
        ;;
    *)
        _log "Unknown runtime '${RUNTIME_TYPE}', skipping context compression"
        ;;
esac
