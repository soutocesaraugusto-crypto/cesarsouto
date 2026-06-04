#!/usr/bin/env bash
# start.sh — Web chat adapter lifecycle daemon
#
# Starts web-chat-server.py in background and tracks PID.
#
# Usage: start.sh <agent> <template_root>
# Env: CRM_INSTANCE_ID, CRM_ROOT (set by agent-wrapper.sh)
#
# Story 114.18 Phase 2

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
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [web-adapter/${AGENT}] $1" >> "${LOG_DIR}/activity.log" 2>/dev/null
}

# Read port from config.json
AGENT_DIR="${TEMPLATE_ROOT}/agents/${AGENT}"
WEB_PORT=8080
if [[ -f "${AGENT_DIR}/config.json" ]]; then
    CONFIG_PORT=$(jq -r '.channels[] | select(.type=="web") | .port // 8080' "${AGENT_DIR}/config.json" 2>/dev/null || echo "8080")
    [[ -n "${CONFIG_PORT}" && "${CONFIG_PORT}" != "null" ]] && WEB_PORT="${CONFIG_PORT}"
fi

# Source agent env
ENV_FILE="${AGENT_DIR}/.env"
{ set +x; } 2>/dev/null
if [[ -f "${ENV_FILE}" ]]; then
    set -a; source "${ENV_FILE}"; set +a
fi

# TMUX_SESSION for the web chat server to capture output
TMUX_SESSION="${TMUX_SESSION:-crm-${CRM_INSTANCE_ID}-${AGENT}}"
export TMUX_SESSION
export CRM_AGENT_NAME="${AGENT}"
export CRM_INSTANCE_ID
export CRM_ROOT

SERVER_SCRIPT="${TEMPLATE_ROOT}/web-chat-server.py"
if [[ ! -f "${SERVER_SCRIPT}" ]]; then
    log "ERROR: web-chat-server.py not found at ${SERVER_SCRIPT}"
    exit 1
fi

# Start web chat server in background
python3 "${SERVER_SCRIPT}" --port "${WEB_PORT}" >> "${LOG_DIR}/web-chat.log" 2>&1 &
SERVER_PID=$!

echo "${SERVER_PID}" > "${PID_FILE}"
log "Started web chat server (PID ${SERVER_PID}, port ${WEB_PORT})"

# Wait for server to become ready (max 10s)
ELAPSED=0
while [[ ${ELAPSED} -lt 10 ]]; do
    if curl -s --max-time 2 "http://localhost:${WEB_PORT}/api/health" > /dev/null 2>&1; then
        log "Web chat server ready on port ${WEB_PORT}"
        exit 0
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

log "WARNING: Web chat server may not be ready (waited 10s)"
exit 0
