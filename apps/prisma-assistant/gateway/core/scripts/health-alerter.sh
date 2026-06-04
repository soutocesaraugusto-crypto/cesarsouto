#!/usr/bin/env bash
# health-alerter.sh — Proactive safety alerts
#
# Called from agent-wrapper.sh watchdog loop every 5 minutes.
# Checks 6 conditions and sends alerts to Telegram --topic alerts.
# 1-hour cooldown per alert type (no spam).
#
#
# Usage: health-alerter.sh <agent> <tmux_session> <template_root>
#
# Epic 114 / Story 114.17 Phase 3

set -uo pipefail

AGENT="${1:-}"
TMUX_SESSION="${2:-}"
TEMPLATE_ROOT="${3:-}"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${HOME}/.claude-remote/${CRM_INSTANCE_ID}"
LOG_FILE="${CRM_ROOT}/logs/${AGENT}/activity.log"
COOLDOWN_FILE="${CRM_ROOT}/state/${AGENT}/.alert-cooldowns.json"
ALERT_COOLDOWN=3600  # 1 hour

[[ -z "${AGENT}" ]] && exit 0

mkdir -p "${CRM_ROOT}/state/${AGENT}" 2>/dev/null || true
[[ ! -f "${COOLDOWN_FILE}" ]] && echo '{}' > "${COOLDOWN_FILE}"

_log() {
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [health-alerter/${AGENT}] $1" >> "${LOG_FILE}" 2>/dev/null
}

_in_cooldown() {
    local key="$1"
    local now
    now=$(date +%s)
    local last
    last=$(jq -r --arg k "$key" '.[$k] // 0' "${COOLDOWN_FILE}" 2>/dev/null || echo "0")
    [[ $((now - last)) -lt ${ALERT_COOLDOWN} ]] && return 0
    return 1
}

_set_cooldown() {
    local key="$1"
    local now
    now=$(date +%s)
    jq -c --arg k "$key" --argjson v "$now" '.[$k] = $v' "${COOLDOWN_FILE}" > "${COOLDOWN_FILE}.tmp" 2>/dev/null \
        && mv "${COOLDOWN_FILE}.tmp" "${COOLDOWN_FILE}" || true
}

_send_alert() {
    local key="$1" message="$2"
    if _in_cooldown "$key"; then return; fi

    # Source .env for bot credentials
    local env_file="${TEMPLATE_ROOT}/agents/${AGENT}/.env"
    if [[ -f "${env_file}" ]]; then
        { set +x; } 2>/dev/null
        local bot_token chat_id
        bot_token=$(grep '^BOT_TOKEN=' "${env_file}" | cut -d= -f2)
        chat_id=$(grep '^CHAT_ID=' "${env_file}" | cut -d= -f2)
        if [[ -n "${bot_token}" && -n "${chat_id}" ]]; then
            BOT_TOKEN="${bot_token}" CHAT_ID="${chat_id}" CRM_AGENT_NAME="${AGENT}" \
                bash "${TEMPLATE_ROOT}/core/bus/send-telegram.sh" "${chat_id}" "ALERT: ${message}" --topic alerts 2>/dev/null || true
        fi
    fi

    _set_cooldown "$key"
    _log "Alert sent: ${key} — ${message}"
}

# --- Condition 1: Context size ---
if tmux has-session -t "${TMUX_SESSION}" 2>/dev/null; then
    LINES=$(tmux capture-pane -t "${TMUX_SESSION}:0.0" -p -S - 2>/dev/null | wc -l | tr -d ' ')
    THRESHOLD_70=8960   # 70% of 12800 (80% threshold from context-monitor)
    if [[ ${LINES} -gt ${THRESHOLD_70} ]]; then
        PCT=$((LINES * 100 / 12800))
        _send_alert "context_high" "Context at ~${PCT}%, consider /compact (${LINES} lines)"
    fi
fi

# --- Condition 2: Crash rate ---
CRASH_LOG="${CRM_ROOT}/logs/${AGENT}/.crash_count_today"
if [[ -f "${CRASH_LOG}" ]]; then
    TODAY=$(date +%Y-%m-%d)
    CRASH_LINE=$(cat "${CRASH_LOG}" 2>/dev/null || echo "")
    if [[ "${CRASH_LINE}" == "${TODAY}:"* ]]; then
        CRASH_COUNT=${CRASH_LINE#*:}
        if [[ ${CRASH_COUNT} -ge 2 ]]; then
            _send_alert "crash_rate" "${CRASH_COUNT}/3 crashes used today — investigate before halt"
        fi
    fi
fi

# --- Condition 3: Delivery failure rate ---
METRICS_FILE="${CRM_ROOT}/logs/${AGENT}/metrics.jsonl"
if [[ -f "${METRICS_FILE}" ]]; then
    DELIVERY_STATS=$(tail -200 "${METRICS_FILE}" | jq -rs '
        [.[] | select(.event == "delivery")] |
        if length > 10 then
            {total: length, fail: ([.[] | select(.delivery_status != "success")] | length)}
        else null end
    ' 2>/dev/null || echo "null")

    if [[ "${DELIVERY_STATS}" != "null" ]]; then
        TOTAL=$(echo "${DELIVERY_STATS}" | jq -r '.total' 2>/dev/null || echo "0")
        FAIL=$(echo "${DELIVERY_STATS}" | jq -r '.fail' 2>/dev/null || echo "0")
        if [[ ${TOTAL} -gt 0 ]]; then
            FAIL_PCT=$((FAIL * 100 / TOTAL))
            if [[ ${FAIL_PCT} -gt 10 ]]; then
                _send_alert "delivery_rate" "Delivery failure rate ${FAIL_PCT}% (${FAIL}/${TOTAL}) — check channel"
            fi
        fi
    fi
fi

# --- Condition 4: Fallback usage ---
if [[ -f "${METRICS_FILE}" ]]; then
    FB_STATS=$(tail -100 "${METRICS_FILE}" | jq -rs '
        {interactions: ([.[] | select(.event == "interaction")] | length),
         fallbacks: ([.[] | select(.event == "fallback_attempt" and .is_fallback == "true")] | length)}
    ' 2>/dev/null || echo '{"interactions":0,"fallbacks":0}')

    INTERACTIONS=$(echo "${FB_STATS}" | jq -r '.interactions' 2>/dev/null || echo "0")
    FALLBACKS=$(echo "${FB_STATS}" | jq -r '.fallbacks' 2>/dev/null || echo "0")
    if [[ ${INTERACTIONS} -gt 5 && ${FALLBACKS} -gt 0 ]]; then
        FB_PCT=$((FALLBACKS * 100 / INTERACTIONS))
        if [[ ${FB_PCT} -gt 30 ]]; then
            _send_alert "fallback_rate" "Primary model degraded — ${FB_PCT}% fallback usage (${FALLBACKS}/${INTERACTIONS})"
        fi
    fi
fi

# --- Condition 5: Queue depth ---
QUEUE_DIR="${CRM_ROOT}/queue/${AGENT}/pending"
if [[ -d "${QUEUE_DIR}" ]]; then
    QUEUE_COUNT=$(find "${QUEUE_DIR}" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ ${QUEUE_COUNT} -gt 10 ]]; then
        _send_alert "queue_depth" "${QUEUE_COUNT} messages stuck in delivery queue"
    fi
fi

# --- Condition 6: Session age ---
if [[ -f "${LOG_FILE}" ]]; then
    # Find last "Starting" log entry to estimate session start
    # Use tail -1 to get LAST session start, not first (QA fix BUG-7)
    LAST_START=$(grep "Starting.*mode=" "${LOG_FILE}" 2>/dev/null | tail -1 | grep -oE '^\S+' || echo "")
    if [[ -n "${LAST_START}" ]]; then
        START_EPOCH=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "${LAST_START}" +%s 2>/dev/null \
            || date -d "${LAST_START}" +%s 2>/dev/null || echo "0")
        NOW=$(date +%s)
        AGE_HOURS=$(( (NOW - START_EPOCH) / 3600 ))
        if [[ ${AGE_HOURS} -ge 60 ]]; then
            _send_alert "session_age" "Session at ${AGE_HOURS}h/71h — restart approaching in $((71 - AGE_HOURS))h"
        fi
    fi
fi
