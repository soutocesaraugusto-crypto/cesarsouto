#!/usr/bin/env bash
# start.sh — WhatsApp adapter lifecycle (starts whatsapp-bridge.js)
#
# Usage: start.sh <agent> <template_root>
# Env: CRM_INSTANCE_ID, CRM_ROOT
#
# First boot: displays QR code in terminal for WhatsApp login.
# Subsequent boots: reconnects automatically using stored auth.
#
# Story 114.18 Phase 3

set -uo pipefail

AGENT="${1:-}"
TEMPLATE_ROOT="${2:-$(cd "$(dirname "$0")/../.." && pwd)}"

if [[ -z "${AGENT}" ]]; then
    echo "Usage: start.sh <agent> <template_root>" >&2
    exit 1
fi

CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
ADAPTER_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="${ADAPTER_DIR}/.pid-${AGENT}"
LOG_DIR="${CRM_ROOT}/logs/${AGENT}"

mkdir -p "${LOG_DIR}" 2>/dev/null || true

log() {
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [whatsapp-adapter/${AGENT}] $1" >> "${LOG_DIR}/activity.log" 2>/dev/null
}

# Check Node.js available
if ! command -v node &> /dev/null; then
    log "ERROR: Node.js not found (required for WhatsApp bridge)"
    echo "ERROR: Node.js not found" >&2
    exit 1
fi

# Check Baileys installed
if ! node -e "require('@whiskeysockets/baileys')" 2>/dev/null; then
    log "WARNING: @whiskeysockets/baileys not installed, attempting install..."
    (cd "${ADAPTER_DIR}" && npm install @whiskeysockets/baileys 2>&1) >> "${LOG_DIR}/activity.log" || {
        log "ERROR: Failed to install @whiskeysockets/baileys"
        echo "ERROR: npm install @whiskeysockets/baileys failed" >&2
        exit 1
    }
fi

# Source agent env
ENV_FILE="${TEMPLATE_ROOT}/agents/${AGENT}/.env"
{ set +x; } 2>/dev/null
if [[ -f "${ENV_FILE}" ]]; then
    set -a; source "${ENV_FILE}"; set +a
fi

export CRM_AGENT_NAME="${AGENT}"
export CRM_INSTANCE_ID
export CRM_ROOT
export WHATSAPP_BRIDGE_PORT="${WHATSAPP_BRIDGE_PORT:-8445}"

BRIDGE_SCRIPT="${ADAPTER_DIR}/whatsapp-bridge.js"

# Start bridge in background
node "${BRIDGE_SCRIPT}" >> "${LOG_DIR}/whatsapp-bridge.log" 2>&1 &
BRIDGE_PID=$!

echo "${BRIDGE_PID}" > "${PID_FILE}"
log "Started WhatsApp bridge (PID ${BRIDGE_PID}, port ${WHATSAPP_BRIDGE_PORT})"

# Wait for bridge to become ready (max 15s — QR code may appear)
ELAPSED=0
while [[ ${ELAPSED} -lt 15 ]]; do
    if curl -s --max-time 2 "http://127.0.0.1:${WHATSAPP_BRIDGE_PORT}/health" | jq -e '.connected or .auth_exists' > /dev/null 2>&1; then
        log "WhatsApp bridge ready"
        exit 0
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

# Bridge started but may need QR scan
if kill -0 "${BRIDGE_PID}" 2>/dev/null; then
    log "WhatsApp bridge running (may need QR scan at http://127.0.0.1:${WHATSAPP_BRIDGE_PORT}/qr)"
    exit 0
else
    log "ERROR: WhatsApp bridge process died"
    rm -f "${PID_FILE}"
    exit 1
fi
