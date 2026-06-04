#!/usr/bin/env bash
# generate-systemd.sh — Generate and enable a systemd user unit for an agent (Linux)
# Usage: generate-systemd.sh <agent_name>
#
# Creates: ~/.config/systemd/user/crm-{instance}-{agent}.service
# Equivalent to generate-launchd.sh but for Linux.
#
# Story 114.24 — Cross-Platform Persistence

set -euo pipefail

AGENT="$1"
TEMPLATE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SINKRA_HUB="${PRISMA_HOME:-$(cd "${TEMPLATE_ROOT}/../.." && pwd)}"
AGENT_DIR="${TEMPLATE_ROOT}/agents/${AGENT}"
if [[ ! -d "${AGENT_DIR}" && -d "${SINKRA_HUB}/.aiox/message-gateway/agents/${AGENT}" ]]; then
    AGENT_DIR="${SINKRA_HUB}/.aiox/message-gateway/agents/${AGENT}"
fi

# Load instance ID
ENV_FILE="${TEMPLATE_ROOT}/.env"
if [[ -f "${ENV_FILE}" ]]; then
    CRM_INSTANCE_ID=$(grep '^CRM_INSTANCE_ID=' "${ENV_FILE}" | cut -d= -f2)
fi
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"

SERVICE_NAME="crm-${CRM_INSTANCE_ID}-${AGENT}"
UNIT_DIR="${HOME}/.config/systemd/user"
UNIT_FILE="${UNIT_DIR}/${SERVICE_NAME}.service"
CRM_ROOT="${HOME}/.claude-remote/${CRM_INSTANCE_ID}"
LOG_DIR="${CRM_ROOT}/logs/${AGENT}"
WRAPPER="${TEMPLATE_ROOT}/core/scripts/agent-wrapper.sh"

mkdir -p "${UNIT_DIR}" "${LOG_DIR}"

# Auto-detect PATH
CLAUDE_BIN=$(which claude 2>/dev/null || echo "")
if [[ -z "${CLAUDE_BIN}" ]]; then
    echo "ERROR: 'claude' not found in PATH. Install Claude Code CLI first." >&2
    exit 1
fi
CLAUDE_DIR=$(dirname "${CLAUDE_BIN}")

NODE_BIN=$(which node 2>/dev/null || echo "")
if [[ -z "${NODE_BIN}" ]]; then
    echo "ERROR: 'node' not found in PATH. Install Node.js first." >&2
    exit 1
fi
NODE_DIR=$(dirname "${NODE_BIN}")

SERVICE_PATH="${NODE_DIR}:${CLAUDE_DIR}:/usr/local/bin:/usr/bin:/bin"
[[ -d "${HOME}/.pyenv/shims" ]] && SERVICE_PATH="${HOME}/.pyenv/shims:${SERVICE_PATH}"

# Generate systemd unit
cat > "${UNIT_FILE}" <<ENDUNIT
[Unit]
Description=Claude Remote Manager - ${AGENT} (${CRM_INSTANCE_ID})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${WRAPPER} ${AGENT} ${TEMPLATE_ROOT}
WorkingDirectory=${AGENT_DIR}
Restart=always
RestartSec=10

Environment=PATH=${SERVICE_PATH}
Environment=HOME=${HOME}
Environment=CRM_AGENT_NAME=${AGENT}
Environment=CRM_INSTANCE_ID=${CRM_INSTANCE_ID}
Environment=CRM_ROOT=${CRM_ROOT}
Environment=CRM_TEMPLATE_ROOT=${TEMPLATE_ROOT}
Environment=PRISMA_HOME=${SINKRA_HUB}

StandardOutput=append:${LOG_DIR}/stdout.log
StandardError=append:${LOG_DIR}/stderr.log

[Install]
WantedBy=default.target
ENDUNIT

echo "Generated: ${UNIT_FILE}"

# Check for lingering (required for user services to run without active login)
if command -v loginctl &>/dev/null; then
    LINGER_STATUS=$(loginctl show-user "$(whoami)" -p Linger 2>/dev/null | cut -d= -f2 || echo "unknown")
    if [[ "${LINGER_STATUS}" != "yes" ]]; then
        echo ""
        echo "WARNING: User lingering is not enabled. Services may stop when you log out."
        echo "  Fix: sudo loginctl enable-linger $(whoami)"
        echo ""
    fi
fi

# Reload and start
systemctl --user daemon-reload
systemctl --user enable "${SERVICE_NAME}"
systemctl --user restart "${SERVICE_NAME}"

echo "Loaded: ${SERVICE_NAME} (systemd user unit)"
echo "  Status: systemctl --user status ${SERVICE_NAME}"
echo "  Logs:   journalctl --user -u ${SERVICE_NAME} -f"
