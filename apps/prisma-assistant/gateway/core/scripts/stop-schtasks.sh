#!/usr/bin/env bash
# stop-schtasks.sh — Stop and delete a Windows Scheduled Task for an agent
# Usage: stop-schtasks.sh <agent_name>
#
# Story 114.24 — Cross-Platform Persistence

set -euo pipefail

AGENT="${1:?Usage: stop-schtasks.sh <agent_name>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load instance ID
ENV_FILE="${TEMPLATE_ROOT}/.env"
if [[ -f "${ENV_FILE}" ]]; then
    CRM_INSTANCE_ID=$(grep '^CRM_INSTANCE_ID=' "${ENV_FILE}" | cut -d= -f2)
fi
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"

TASK_NAME="crm-${CRM_INSTANCE_ID}-${AGENT}"

SCHTASKS_CMD="schtasks.exe"
command -v schtasks.exe &>/dev/null || SCHTASKS_CMD="schtasks"

${SCHTASKS_CMD} /end /tn "${TASK_NAME}" 2>/dev/null || true
${SCHTASKS_CMD} /delete /tn "${TASK_NAME}" /f 2>/dev/null || true

echo "  schtasks: stopped and deleted (${TASK_NAME})"
