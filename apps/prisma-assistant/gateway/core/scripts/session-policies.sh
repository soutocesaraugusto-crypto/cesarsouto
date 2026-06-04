#!/usr/bin/env bash
# session-policies.sh — Session reset policies (idle + daily)
# Hermes pattern: SessionResetPolicy (IDLE_ONLY, DAILY, IDLE_AND_DAILY, NEVER)
#
# Checks if a session should be auto-reset based on idle time or daily schedule.
# Called by fast-checker or agent-wrapper before processing messages.
#
# Usage:
#   session-policies.sh check <agent>    # Returns: "reset_idle", "reset_daily", or "ok"
#   session-policies.sh reset <agent>    # Performs the reset (injects /clear into tmux)
#   session-policies.sh status <agent>   # Shows session age and policy
#
# Config (in agent's config.json):
#   "session_policy": {
#     "mode": "idle_and_daily",     // "never", "idle", "daily", "idle_and_daily"
#     "idle_minutes": 1440,         // 24h default
#     "daily_reset_hour": 4,        // 4 AM local time
#     "notify": true                // Send reset notification to user
#   }
#
# Epic 110 / Story 110.29 Phase 5

set -uo pipefail

ACTION="${1:-check}"
AGENT="${2:-${CRM_AGENT_NAME:-prisma}}"

CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
STATE_DIR="${CRM_ROOT}/state/${AGENT}"
ACTIVITY_FILE="${STATE_DIR}/last-activity"
DAILY_MARKER="${STATE_DIR}/daily-reset-marker"
CONFIG_FILE="${TEMPLATE_ROOT}/agents/${AGENT}/config.json"

mkdir -p "${STATE_DIR}" 2>/dev/null || true

# Load policy from config
POLICY_MODE=$(jq -r '.session_policy.mode // "never"' "${CONFIG_FILE}" 2>/dev/null || echo "never")
IDLE_MINUTES=$(jq -r '.session_policy.idle_minutes // 1440' "${CONFIG_FILE}" 2>/dev/null || echo "1440")
DAILY_HOUR=$(jq -r '.session_policy.daily_reset_hour // 4' "${CONFIG_FILE}" 2>/dev/null || echo "4")
NOTIFY=$(jq -r '.session_policy.notify // true' "${CONFIG_FILE}" 2>/dev/null || echo "true")

NOW=$(date +%s)

case "${ACTION}" in
    check)
        [[ "${POLICY_MODE}" == "never" ]] && { echo "ok"; exit 0; }

        # Check idle timeout
        if [[ "${POLICY_MODE}" == "idle" || "${POLICY_MODE}" == "idle_and_daily" ]]; then
            if [[ -f "${ACTIVITY_FILE}" ]]; then
                LAST_ACTIVITY=$(cat "${ACTIVITY_FILE}" 2>/dev/null || echo "0")
                IDLE_SECONDS=$((NOW - LAST_ACTIVITY))
                IDLE_THRESHOLD=$((IDLE_MINUTES * 60))
                if [[ ${IDLE_SECONDS} -gt ${IDLE_THRESHOLD} ]]; then
                    echo "reset_idle"
                    exit 0
                fi
            fi
        fi

        # Check daily reset
        if [[ "${POLICY_MODE}" == "daily" || "${POLICY_MODE}" == "idle_and_daily" ]]; then
            CURRENT_HOUR=$(date +%H | sed 's/^0//')
            TODAY=$(date +%Y-%m-%d)
            if [[ ${CURRENT_HOUR} -ge ${DAILY_HOUR} ]]; then
                LAST_DAILY=$(cat "${DAILY_MARKER}" 2>/dev/null || echo "")
                if [[ "${LAST_DAILY}" != "${TODAY}" ]]; then
                    echo "reset_daily"
                    exit 0
                fi
            fi
        fi

        echo "ok"
        ;;

    reset)
        REASON="${3:-manual}"
        TMUX_SESSION="${4:-crm-${CRM_INSTANCE_ID}-${AGENT}}"

        # Mark daily reset
        if [[ "${REASON}" == "reset_daily" ]]; then
            date +%Y-%m-%d > "${DAILY_MARKER}" 2>/dev/null || true
        fi

        # Notify user if configured
        if [[ "${NOTIFY}" == "true" ]]; then
            BUS_DIR="${TEMPLATE_ROOT}/core/bus"
            if [[ -n "${CHAT_ID:-}" ]]; then
                local msg="Session auto-reset (${REASON}). Context cleared — starting fresh."
                bash "${BUS_DIR}/send-telegram.sh" "${CHAT_ID}" "${msg}" --topic alerts 2>/dev/null || true
            fi
        fi

        # Inject /clear into tmux to reset session
        if tmux has-session -t "${TMUX_SESSION}" 2>/dev/null; then
            local tmpfile
            tmpfile=$(mktemp)
            printf '/clear\n' > "$tmpfile"
            tmux load-buffer -b "crm-reset" "$tmpfile"
            tmux paste-buffer -t "${TMUX_SESSION}:0.0" -b "crm-reset"
            sleep 0.3
            tmux send-keys -t "${TMUX_SESSION}:0.0" Enter
            rm -f "$tmpfile"
        fi

        # Update activity timestamp
        echo "${NOW}" > "${ACTIVITY_FILE}" 2>/dev/null || true

        echo "reset_done"
        ;;

    touch)
        # Update last activity timestamp (called after each message injection)
        echo "${NOW}" > "${ACTIVITY_FILE}" 2>/dev/null || true
        ;;

    status)
        LAST_ACTIVITY=$(cat "${ACTIVITY_FILE}" 2>/dev/null || echo "0")
        IDLE_SECONDS=$((NOW - LAST_ACTIVITY))
        LAST_DAILY=$(cat "${DAILY_MARKER}" 2>/dev/null || echo "never")

        echo "Policy: ${POLICY_MODE}"
        echo "Idle: ${IDLE_SECONDS}s (threshold: ${IDLE_MINUTES}m)"
        echo "Daily reset hour: ${DAILY_HOUR}"
        echo "Last daily reset: ${LAST_DAILY}"
        ;;

    *)
        echo "Usage: session-policies.sh {check|reset|touch|status} <agent>" >&2
        exit 1
        ;;
esac
