#!/usr/bin/env bash
# health.sh — Health check for WhatsApp bridge adapter
#
# Checks: PID alive, bridge /health responding, WhatsApp connected.
# Exit 0 = HEALTHY, Exit 1 = DEGRADED, Exit 2 = DEAD.
#
# Usage: health.sh <agent>
#
# Story 114.18 Phase 3

set -uo pipefail

AGENT="${1:-}"
ADAPTER_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="${ADAPTER_DIR}/.pid-${AGENT}"

WHATSAPP_BRIDGE_PORT="${WHATSAPP_BRIDGE_PORT:-8445}"

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

# Check 2: Bridge HTTP health
HEALTH_RESPONSE=$(curl -s --max-time 3 "http://127.0.0.1:${WHATSAPP_BRIDGE_PORT}/health" 2>/dev/null || echo "")
if [[ -z "${HEALTH_RESPONSE}" ]]; then
    HEALTHY=false
    ISSUES+="  - Bridge HTTP not responding on port ${WHATSAPP_BRIDGE_PORT}\n"
else
    WA_CONNECTED=$(echo "${HEALTH_RESPONSE}" | jq -r '.connected // false' 2>/dev/null || echo "false")
    if [[ "${WA_CONNECTED}" != "true" ]]; then
        HEALTHY=false
        ISSUES+="  - WhatsApp not connected (may need QR scan)\n"
    fi
fi

# Classify
PID_ALIVE=true
if [[ ! -f "${PID_FILE}" ]] || ! kill -0 "$(cat "${PID_FILE}" 2>/dev/null)" 2>/dev/null; then
    PID_ALIVE=false
fi

if ! $PID_ALIVE; then
    echo "DEAD: WhatsApp adapter for ${AGENT} (PID gone)"
    printf "${ISSUES}"
    exit 2
elif ! $HEALTHY; then
    echo "DEGRADED: WhatsApp adapter for ${AGENT}"
    printf "${ISSUES}"
    exit 1
else
    echo "HEALTHY: WhatsApp adapter for ${AGENT}"
    exit 0
fi
