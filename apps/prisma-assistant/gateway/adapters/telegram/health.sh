#!/usr/bin/env bash
# health.sh — Health check for the Telegram polling adapter
#
# Checks: PID alive, offset file freshness, Telegram API connectivity.
# Exit 0 = HEALTHY, Exit 1 = DEGRADED (errors but recoverable), Exit 2 = DEAD (needs restart).
# Pattern from: OpenClaw channel health monitor (pause/resume)
#
# Usage: health.sh <agent>
#
# Epic 110 / Story 110.27 Phase 3

set -uo pipefail

AGENT="${1:-}"
ADAPTER_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "${ADAPTER_DIR}/../.." && pwd)}"
PID_FILE="${ADAPTER_DIR}/.pid-${AGENT}"

CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"

HEALTHY=true
ISSUES=""

# Check 1: PID file exists and process alive
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

# Check 2: Offset file freshness (last poll < 30s ago)
OFFSET_FILE="${CRM_ROOT}/state/.telegram-offset-${AGENT}"
if [[ -f "${OFFSET_FILE}" ]]; then
    OFFSET_AGE=$(( $(date +%s) - $(stat -f %m "${OFFSET_FILE}" 2>/dev/null || stat -c %Y "${OFFSET_FILE}" 2>/dev/null || echo "0") ))
    if [[ ${OFFSET_AGE} -gt 30 ]]; then
        HEALTHY=false
        ISSUES+="  - Offset file stale (${OFFSET_AGE}s old, max 30s)\n"
    fi
else
    # No offset file yet — might be first start, not necessarily unhealthy
    ISSUES+="  - No offset file (first run or never polled)\n"
fi

# Check 3: Telegram API connectivity (getMe)
ENV_FILE="${TEMPLATE_ROOT}/agents/${AGENT}/.env"
if [[ -f "${ENV_FILE}" ]]; then
    { set +x; } 2>/dev/null
    BOT_TOKEN=$(grep '^BOT_TOKEN=' "${ENV_FILE}" | cut -d= -f2)
    if [[ -n "${BOT_TOKEN}" ]]; then
        API_RESULT=$(curl -s --max-time 5 "https://api.telegram.org/bot${BOT_TOKEN}/getMe" 2>/dev/null || echo '{"ok":false}')
        if ! echo "${API_RESULT}" | jq -e '.ok' > /dev/null 2>&1; then
            HEALTHY=false
            ISSUES+="  - Telegram API unreachable or token invalid\n"
        fi
    else
        HEALTHY=false
        ISSUES+="  - BOT_TOKEN not configured\n"
    fi
else
    HEALTHY=false
    ISSUES+="  - No .env file for agent ${AGENT}\n"
fi

# Classify: HEALTHY (0), DEGRADED (1), or DEAD (2)
# DEAD = PID gone (needs full restart)
# DEGRADED = PID alive but API errors or stale offset (can self-recover, should pause)
# HEALTHY = everything OK
PID_ALIVE=true
if [[ ! -f "${PID_FILE}" ]] || ! kill -0 "$(cat "${PID_FILE}" 2>/dev/null)" 2>/dev/null; then
    PID_ALIVE=false
fi

if ! $PID_ALIVE; then
    echo "DEAD: Telegram adapter for ${AGENT} (PID gone)"
    printf "${ISSUES}"
    exit 2
elif ! $HEALTHY; then
    echo "DEGRADED: Telegram adapter for ${AGENT} (errors but PID alive)"
    printf "${ISSUES}"
    exit 1
else
    echo "HEALTHY: Telegram adapter for ${AGENT}"
    exit 0
fi
