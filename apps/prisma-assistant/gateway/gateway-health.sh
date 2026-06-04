#!/usr/bin/env bash
# gateway-health.sh — Unified health check for the entire message gateway
# Returns JSON with agent status, adapter status, and session info.
# OpenClaw pattern: /api/health endpoint with comprehensive summaries.
#
# Usage: gateway-health.sh [agent]
# Default: checks all agents in enabled-agents.json
#
# Epic 110 / Story 110.28 Phase 5

set -uo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "$0")" && pwd)"
SPECIFIC_AGENT="${1:-}"

CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"

NOW_S=$(date +%s)
RESULT='{"ok":true,"timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","agents":[],"adapters":[],"issues":[]}'

# Discover agents
AGENTS=()
if [[ -n "${SPECIFIC_AGENT}" ]]; then
    AGENTS+=("${SPECIFIC_AGENT}")
else
    ENABLED_FILE="${CRM_ROOT}/config/enabled-agents.json"
    if [[ -f "${ENABLED_FILE}" ]]; then
        while IFS= read -r agent; do
            [[ -n "$agent" ]] && AGENTS+=("$agent")
        done < <(jq -r 'to_entries[] | select(.value == true) | .key' "${ENABLED_FILE}" 2>/dev/null)
    fi
    # Fallback: check tmux sessions
    if [[ ${#AGENTS[@]} -eq 0 ]]; then
        while IFS= read -r session; do
            [[ "$session" == crm-* ]] && AGENTS+=("$(echo "$session" | sed 's/crm-[^-]*-//')")
        done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)
    fi
fi

# Detect platform once (Story 114.24)
HEALTH_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=core/scripts/detect-platform.sh
source "${HEALTH_SCRIPT_DIR}/core/scripts/detect-platform.sh"

for AGENT in "${AGENTS[@]}"; do
    TMUX_SESSION="crm-${CRM_INSTANCE_ID}-${AGENT}"
    LOG_DIR="${CRM_ROOT}/logs/${AGENT}"

    # Agent status — check platform-specific persistence + tmux
    AGENT_STATUS="stopped"
    AGENT_UPTIME=0

    case "${CRM_PLATFORM}" in
        darwin)
            PLIST="${HOME}/Library/LaunchAgents/com.claude-remote.${CRM_INSTANCE_ID}.${AGENT}.plist"
            if [[ -f "${PLIST}" ]] && launchctl list "${PLIST##*/%.plist}" &>/dev/null; then
                AGENT_STATUS="running"
            fi
            ;;
        linux)
            SERVICE_NAME="crm-${CRM_INSTANCE_ID}-${AGENT}"
            if systemctl --user is-active "${SERVICE_NAME}" &>/dev/null; then
                AGENT_STATUS="running"
            fi
            ;;
        windows)
            TASK_NAME="crm-${CRM_INSTANCE_ID}-${AGENT}"
            SCHTASKS_CMD="schtasks.exe"
            command -v schtasks.exe &>/dev/null || SCHTASKS_CMD="schtasks"
            if ${SCHTASKS_CMD} /query /tn "${TASK_NAME}" 2>/dev/null | grep -qi "running"; then
                AGENT_STATUS="running"
            fi
            ;;
    esac

    # Fallback: check tmux session
    if [[ "${AGENT_STATUS}" == "stopped" ]] && tmux has-session -t "${TMUX_SESSION}" 2>/dev/null; then
        AGENT_STATUS="running"
    fi

    if [[ "${AGENT_STATUS}" == "running" ]]; then
        # Estimate uptime from activity.log
        LAST_START=$(grep "Starting ${AGENT}" "${LOG_DIR}/activity.log" 2>/dev/null | tail -1 | cut -dT -f1-2 | tr -d ':-' || echo "")
    fi

    # Last activity
    LAST_ACTIVITY=""
    if [[ -f "${LOG_DIR}/activity.log" ]]; then
        LAST_ACTIVITY=$(tail -1 "${LOG_DIR}/activity.log" 2>/dev/null | jq -r '.ts // empty' 2>/dev/null || head -c 20 < <(tail -1 "${LOG_DIR}/activity.log" 2>/dev/null) || echo "unknown")
    fi

    # Crash count today
    CRASH_FILE="${LOG_DIR}/.crash_count_today"
    CRASHES=0
    if [[ -f "${CRASH_FILE}" ]]; then
        TODAY=$(date +%Y-%m-%d)
        STORED_DATE=$(cut -d: -f1 "${CRASH_FILE}" 2>/dev/null || echo "")
        [[ "${STORED_DATE}" == "${TODAY}" ]] && CRASHES=$(cut -d: -f2 "${CRASH_FILE}" 2>/dev/null || echo "0")
    fi

    RESULT=$(echo "$RESULT" | jq -c --arg name "$AGENT" --arg status "$AGENT_STATUS" \
        --arg last "$LAST_ACTIVITY" --argjson crashes "${CRASHES}" \
        '.agents += [{"name": $name, "status": $status, "last_activity": $last, "crashes_today": $crashes}]')

    # Check adapters for this agent
    for adapter_dir in "${TEMPLATE_ROOT}/adapters"/*/; do
        [[ ! -d "$adapter_dir" ]] && continue
        CH_TYPE=$(basename "$adapter_dir")
        HEALTH_SCRIPT="${adapter_dir}health.sh"
        ADAPTER_STATUS="not_installed"

        if [[ -f "${HEALTH_SCRIPT}" ]]; then
            if bash "${HEALTH_SCRIPT}" "${AGENT}" > /dev/null 2>&1; then
                ADAPTER_STATUS="healthy"
            else
                ADAPTER_STATUS="unhealthy"
                RESULT=$(echo "$RESULT" | jq -c '.ok = false')
                RESULT=$(echo "$RESULT" | jq -c --arg issue "${CH_TYPE} adapter unhealthy for ${AGENT}" '.issues += [$issue]')
            fi
        fi

        RESULT=$(echo "$RESULT" | jq -c --arg agent "$AGENT" --arg ch "$CH_TYPE" --arg status "$ADAPTER_STATUS" \
            '.adapters += [{"agent": $agent, "channel": $ch, "status": $status}]')
    done
done

# Channel inbox stats
for AGENT in "${AGENTS[@]}"; do
    INBOX_DIR="${CRM_ROOT}/channel-inbox/${AGENT}"
    PENDING=0
    [[ -d "${INBOX_DIR}" ]] && PENDING=$(find "${INBOX_DIR}" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
    if [[ ${PENDING} -gt 0 ]]; then
        RESULT=$(echo "$RESULT" | jq -c --arg agent "$AGENT" --argjson count "${PENDING}" \
            '.issues += ["channel-inbox has \($count) pending messages for \($agent)"]')
    fi
done

echo "$RESULT" | jq .
