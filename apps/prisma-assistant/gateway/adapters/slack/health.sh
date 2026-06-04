#!/usr/bin/env bash
# health.sh — Health check for Slack Socket Mode adapter
#
# Checks: PID alive, Slack API connectivity.
# Exit 0 = HEALTHY, Exit 1 = DEGRADED, Exit 2 = DEAD.
#
# Usage: health.sh <agent>
#
# Story 114.18 Phase 4

set -uo pipefail

AGENT="${1:-}"
ADAPTER_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "${ADAPTER_DIR}/../.." && pwd)}"
PID_FILE="${ADAPTER_DIR}/.pid-${AGENT}"

HEALTHY=true
ISSUES=""

# Check 1: PID alive
if [[ ! -f "${PID_FILE}" ]]; then
    HEALTHY=false
    ISSUES+="  - No PID file (adapter not started)\n"
else
    PID=$(cat "${PID_FILE}" 2>/dev/null)
    if ! kill -0 "${PID}" 2>/dev/null; then
        HEALTHY=false
        ISSUES+="  - Process ${PID} not running (stale PID)\n"
    fi
fi

# Check 2: Slack API connectivity (auth.test)
ENV_FILE="${TEMPLATE_ROOT}/agents/${AGENT}/.env"
if [[ -f "${ENV_FILE}" ]]; then
    { set +x; } 2>/dev/null
    SLACK_BOT_TOKEN=$(grep '^SLACK_BOT_TOKEN=' "${ENV_FILE}" | cut -d= -f2)
    if [[ -n "${SLACK_BOT_TOKEN}" ]]; then
        API_RESULT=$(curl -s --max-time 5 "https://slack.com/api/auth.test" \
            -H "Authorization: Bearer ${SLACK_BOT_TOKEN}" 2>/dev/null || echo '{"ok":false}')
        if ! echo "${API_RESULT}" | jq -e '.ok == true' > /dev/null 2>&1; then
            HEALTHY=false
            ISSUES+="  - Slack API unreachable or token invalid\n"
        fi
    else
        HEALTHY=false
        ISSUES+="  - SLACK_BOT_TOKEN not configured\n"
    fi
else
    HEALTHY=false
    ISSUES+="  - No .env file for agent ${AGENT}\n"
fi

# Classify
PID_ALIVE=true
if [[ ! -f "${PID_FILE}" ]] || ! kill -0 "$(cat "${PID_FILE}" 2>/dev/null)" 2>/dev/null; then
    PID_ALIVE=false
fi

if ! $PID_ALIVE; then
    echo "DEAD: Slack adapter for ${AGENT} (PID gone)"
    printf "${ISSUES}"
    exit 2
elif ! $HEALTHY; then
    echo "DEGRADED: Slack adapter for ${AGENT} (errors but PID alive)"
    printf "${ISSUES}"
    exit 1
else
    echo "HEALTHY: Slack adapter for ${AGENT}"
    exit 0
fi
