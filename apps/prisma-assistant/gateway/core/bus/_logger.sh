#!/usr/bin/env bash
# _logger.sh - Structured JSON logging for the message gateway
# Writes JSON Lines to the agent's activity.log for observability.
#
# Usage: source this file, then call:
#   crm_log "event_type" "message" ["key=value" ...]
#
# Example:
#   crm_log "telegram_send" "Message sent" "chat_id=123" "msg_id=456" "latency_ms=120"
#   crm_log "permission_decision" "Approved" "tool=Bash" "decision=allow" "elapsed_s=5"
#   crm_log "error" "Telegram API rejected message" "status=400" "description=can't parse"
#
# Output (JSON Lines in activity.log):
#   {"ts":"2026-04-05T14:30:45Z","agent":"prisma","event":"telegram_send","msg":"Message sent","chat_id":"123","msg_id":"456","latency_ms":"120"}
#
# DRY_RUN mode: When DRY_RUN=1, telegram sends are logged but not executed.
#
# Epic 110 / Story 110.26 Phase 1

# Resolve log file path
_CRM_LOG_AGENT="${CRM_AGENT_NAME:-$(basename "$(pwd)")}"
_CRM_LOG_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID:-default}}"
_CRM_LOG_FILE="${_CRM_LOG_ROOT}/logs/${_CRM_LOG_AGENT}/activity.log"

# Ensure log directory exists (idempotent)
mkdir -p "$(dirname "${_CRM_LOG_FILE}")" 2>/dev/null || true

# Write a structured log entry as JSON Lines
# Args: event_type message [key=value ...]
crm_log() {
    local event="${1:-unknown}"
    local msg="${2:-}"
    shift 2 2>/dev/null || true

    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Build JSON object using jq for proper escaping
    local json
    json=$(jq -n -c \
        --arg ts "$ts" \
        --arg agent "$_CRM_LOG_AGENT" \
        --arg event "$event" \
        --arg msg "$msg" \
        '{ts: $ts, agent: $agent, event: $event, msg: $msg}')

    # Append extra key=value pairs
    while [[ $# -gt 0 ]]; do
        local kv="$1"
        shift
        local key="${kv%%=*}"
        local val="${kv#*=}"
        json=$(echo "$json" | jq -c --arg k "$key" --arg v "$val" '. + {($k): $v}')
    done

    echo "$json" >> "${_CRM_LOG_FILE}" 2>/dev/null || true
}

# Log an error with standard fields
crm_log_error() {
    local context="${1:-unknown}"
    local msg="${2:-}"
    shift 2 2>/dev/null || true
    crm_log "error" "$msg" "context=$context" "$@"
}

# Check if dry-run mode is active
is_dry_run() {
    [[ "${DRY_RUN:-0}" == "1" ]]
}
