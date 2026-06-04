#!/usr/bin/env bash
# health.sh — Health check for the Discord polling adapter
#
# Checks: PID alive, Discord API connectivity (GET /users/@me).
# Exit 0 = HEALTHY, Exit 1 = DEGRADED, Exit 2 = DEAD.
#
# Usage: health.sh <agent>
#
# Story 114.18 Phase 1

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

# Check 2: Discord API connectivity (GET /users/@me validates token)
ENV_FILE="${TEMPLATE_ROOT}/agents/${AGENT}/.env"
if [[ -f "${ENV_FILE}" ]]; then
    { set +x; } 2>/dev/null
    DISCORD_TOKEN=$(grep '^DISCORD_TOKEN=' "${ENV_FILE}" | cut -d= -f2)
    if [[ -n "${DISCORD_TOKEN}" ]]; then
        API_RESULT=$(curl -s --max-time 5 "https://discord.com/api/v10/users/@me" \
            -H "Authorization: Bot ${DISCORD_TOKEN}" 2>/dev/null || echo '{}')
        if ! echo "${API_RESULT}" | jq -e '.id' > /dev/null 2>&1; then
            HEALTHY=false
            ISSUES+="  - Discord API unreachable or token invalid\n"
        fi
    else
        HEALTHY=false
        ISSUES+="  - DISCORD_TOKEN not configured\n"
    fi
else
    HEALTHY=false
    ISSUES+="  - No .env file for agent ${AGENT}\n"
fi

# Classify: HEALTHY (0), DEGRADED (1), DEAD (2)
PID_ALIVE=true
if [[ ! -f "${PID_FILE}" ]] || ! kill -0 "$(cat "${PID_FILE}" 2>/dev/null)" 2>/dev/null; then
    PID_ALIVE=false
fi

if ! $PID_ALIVE; then
    echo "DEAD: Discord adapter for ${AGENT} (PID gone)"
    printf "${ISSUES}"
    exit 2
elif ! $HEALTHY; then
    echo "DEGRADED: Discord adapter for ${AGENT} (errors but PID alive)"
    printf "${ISSUES}"
    exit 1
else
    echo "HEALTHY: Discord adapter for ${AGENT}"
    exit 0
fi
