#!/usr/bin/env bash
# start.sh — Slack Socket Mode adapter lifecycle
#
# Starts socket-listener.py (Slack Bolt + Socket Mode) in background.
#
# Usage: start.sh <agent> <template_root>
#
# Story 114.18 Phase 4

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
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [slack-adapter/${AGENT}] $1" >> "${LOG_DIR}/activity.log" 2>/dev/null
}

# Check Python slack-bolt available
if ! python3 -c "import slack_bolt" 2>/dev/null; then
    log "WARNING: slack-bolt not installed, attempting install..."
    pip3 install slack-bolt 2>&1 >> "${LOG_DIR}/activity.log" || {
        log "ERROR: Failed to install slack-bolt"
        echo "ERROR: pip install slack-bolt failed" >&2
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

LISTENER_SCRIPT="${ADAPTER_DIR}/socket-listener.py"
if [[ ! -f "${LISTENER_SCRIPT}" ]]; then
    log "ERROR: socket-listener.py not found"
    exit 1
fi

# Start listener in background
python3 "${LISTENER_SCRIPT}" >> "${LOG_DIR}/slack-listener.log" 2>&1 &
LISTENER_PID=$!

echo "${LISTENER_PID}" > "${PID_FILE}"
log "Started Slack socket listener (PID ${LISTENER_PID})"

# Brief wait to check it didn't crash immediately
sleep 2
if kill -0 "${LISTENER_PID}" 2>/dev/null; then
    log "Slack listener running"
    exit 0
else
    log "ERROR: Slack listener died immediately"
    rm -f "${PID_FILE}"
    exit 1
fi
