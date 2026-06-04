#!/usr/bin/env bash
# stop-systemd.sh — Stop and disable a systemd user unit for an agent (Linux)
# Usage: stop-systemd.sh <agent_name>
#
# Story 114.24 — Cross-Platform Persistence

set -euo pipefail

AGENT="${1:?Usage: stop-systemd.sh <agent_name>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load instance ID
ENV_FILE="${TEMPLATE_ROOT}/.env"
if [[ -f "${ENV_FILE}" ]]; then
    CRM_INSTANCE_ID=$(grep '^CRM_INSTANCE_ID=' "${ENV_FILE}" | cut -d= -f2)
fi
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"

SERVICE_NAME="crm-${CRM_INSTANCE_ID}-${AGENT}"

systemctl --user stop "${SERVICE_NAME}" 2>/dev/null || true
systemctl --user disable "${SERVICE_NAME}" 2>/dev/null || true

echo "  systemd: stopped and disabled (${SERVICE_NAME})"
