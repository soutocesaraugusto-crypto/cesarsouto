#!/usr/bin/env bash
# _fatal-error.sh — Centralized fatal error handler
# Hermes pattern: _set_fatal_error(code, message, retryable)
#
# Writes error state to a status file so health checks and watchdogs can detect it.
# Optionally sends alert via Telegram.
#
# Usage: source this file, then call:
#   set_fatal_error "AUTH_FAILED" "Bot token revoked" false
#   is_fatal_error && echo "adapter is broken"
#   get_fatal_error  → JSON {code, message, retryable, timestamp}
#   clear_fatal_error
#
# Epic 110 / Story 110.29 Phase 3

_FATAL_AGENT="${CRM_AGENT_NAME:-$(basename "$(pwd)")}"
_FATAL_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID:-default}}"
_FATAL_FILE="${_FATAL_ROOT}/state/${_FATAL_AGENT}/fatal-error.json"

mkdir -p "$(dirname "${_FATAL_FILE}")" 2>/dev/null || true

set_fatal_error() {
    local code="$1"
    local message="$2"
    local retryable="${3:-true}"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq -n -c \
        --arg code "$code" \
        --arg msg "$message" \
        --argjson retryable "$retryable" \
        --arg ts "$timestamp" \
        '{code: $code, message: $msg, retryable: $retryable, timestamp: $ts}' \
        > "${_FATAL_FILE}" 2>/dev/null || true

    # Log via structured logger if available
    if type crm_log &>/dev/null; then
        crm_log "fatal_error" "$message" "code=$code" "retryable=$retryable"
    fi

    # Send alert if Telegram is available
    local bus_dir
    bus_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -n "${CHAT_ID:-}" && -f "${bus_dir}/send-telegram.sh" ]]; then
        bash "${bus_dir}/send-telegram.sh" "${CHAT_ID}" "FATAL: ${code} — ${message} (retryable: ${retryable})" --topic alerts 2>/dev/null || true
    fi
}

is_fatal_error() {
    [[ -f "${_FATAL_FILE}" ]]
}

get_fatal_error() {
    if [[ -f "${_FATAL_FILE}" ]]; then
        cat "${_FATAL_FILE}"
    else
        echo '{"code":null,"message":null,"retryable":true,"timestamp":null}'
    fi
}

clear_fatal_error() {
    rm -f "${_FATAL_FILE}" 2>/dev/null || true
}

# Check if error is retryable (for watchdog decisions)
is_fatal_retryable() {
    if [[ -f "${_FATAL_FILE}" ]]; then
        jq -r '.retryable' "${_FATAL_FILE}" 2>/dev/null || echo "true"
    else
        echo "true"
    fi
}
