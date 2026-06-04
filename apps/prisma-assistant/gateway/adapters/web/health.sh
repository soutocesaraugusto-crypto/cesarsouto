#!/usr/bin/env bash
# health.sh — Health check for the web chat adapter
#
# Checks: PID alive, HTTP /api/health responding.
# Exit 0 = HEALTHY, Exit 1 = DEGRADED, Exit 2 = DEAD.
#
# Usage: health.sh <agent>
#
# Story 114.18 Phase 2

set -uo pipefail

AGENT="${1:-}"
ADAPTER_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "${ADAPTER_DIR}/../.." && pwd)}"
PID_FILE="${ADAPTER_DIR}/.pid-${AGENT}"

HEALTHY=true
ISSUES=""

# Read port from config
AGENT_DIR="${TEMPLATE_ROOT}/agents/${AGENT}"
WEB_PORT=8080
if [[ -f "${AGENT_DIR}/config.json" ]]; then
    CONFIG_PORT=$(jq -r '.channels[] | select(.type=="web") | .port // 8080' "${AGENT_DIR}/config.json" 2>/dev/null || echo "8080")
    [[ -n "${CONFIG_PORT}" && "${CONFIG_PORT}" != "null" ]] && WEB_PORT="${CONFIG_PORT}"
fi

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

# Check 2: HTTP health endpoint
HEALTH_RESPONSE=$(curl -s --max-time 3 "http://localhost:${WEB_PORT}/api/health" 2>/dev/null || echo "")
if [[ -z "${HEALTH_RESPONSE}" ]] || ! echo "${HEALTH_RESPONSE}" | jq -e '.status == "ok"' > /dev/null 2>&1; then
    HEALTHY=false
    ISSUES+="  - HTTP /api/health not responding on port ${WEB_PORT}\n"
fi

# Classify
PID_ALIVE=true
if [[ ! -f "${PID_FILE}" ]] || ! kill -0 "$(cat "${PID_FILE}" 2>/dev/null)" 2>/dev/null; then
    PID_ALIVE=false
fi

if ! $PID_ALIVE; then
    echo "DEAD: Web adapter for ${AGENT} (PID gone)"
    printf "${ISSUES}"
    exit 2
elif ! $HEALTHY; then
    echo "DEGRADED: Web adapter for ${AGENT} (errors but PID alive)"
    printf "${ISSUES}"
    exit 1
else
    echo "HEALTHY: Web adapter for ${AGENT} (port ${WEB_PORT})"
    exit 0
fi
