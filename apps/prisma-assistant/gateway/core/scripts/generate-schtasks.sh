#!/usr/bin/env bash
# generate-schtasks.sh — Generate a Windows Scheduled Task for an agent
# Usage: generate-schtasks.sh <agent_name>
#
# Requires: Git Bash, WSL, or MSYS2 environment on Windows.
# Creates a scheduled task that starts on logon and restarts on failure.
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

TASK_NAME="crm-${CRM_INSTANCE_ID}-${AGENT}"
CRM_ROOT="${HOME}/.claude-remote/${CRM_INSTANCE_ID}"
LOG_DIR="${CRM_ROOT}/logs/${AGENT}"
WRAPPER="${TEMPLATE_ROOT}/core/scripts/agent-wrapper.sh"

mkdir -p "${LOG_DIR}"

# Convert paths for Windows if running in Git Bash/MSYS
to_win_path() {
    if command -v cygpath &>/dev/null; then
        cygpath -w "$1"
    else
        echo "$1"
    fi
}

WRAPPER_WIN=$(to_win_path "${WRAPPER}")
AGENT_DIR_WIN=$(to_win_path "${AGENT_DIR}")

# Check for schtasks
if ! command -v schtasks.exe &>/dev/null && ! command -v schtasks &>/dev/null; then
    echo "ERROR: 'schtasks' not found. Are you running in Git Bash or WSL on Windows?" >&2
    echo "  Hint: In WSL, use schtasks.exe (with .exe suffix)" >&2
    exit 1
fi

SCHTASKS_CMD="schtasks.exe"
command -v schtasks.exe &>/dev/null || SCHTASKS_CMD="schtasks"

# Find bash.exe for the task to invoke our wrapper
BASH_EXE=""
if command -v cygpath &>/dev/null; then
    # Git Bash / MSYS
    BASH_EXE=$(to_win_path "$(which bash)")
else
    # WSL — use wsl.exe to invoke
    BASH_EXE="wsl.exe"
    WRAPPER_WIN="${WRAPPER}"
fi

# Delete existing task if present
${SCHTASKS_CMD} /delete /tn "${TASK_NAME}" /f 2>/dev/null || true

# Create the scheduled task
# Runs on logon, restarts every 10 seconds on failure (up to 999 times)
${SCHTASKS_CMD} /create \
    /tn "${TASK_NAME}" \
    /tr "\"${BASH_EXE}\" \"${WRAPPER_WIN}\" ${AGENT} $(to_win_path "${TEMPLATE_ROOT}")" \
    /sc ONLOGON \
    /rl HIGHEST \
    /f

echo "Generated: Scheduled Task '${TASK_NAME}'"

# Start the task immediately
${SCHTASKS_CMD} /run /tn "${TASK_NAME}" 2>/dev/null || true

echo "Loaded: ${TASK_NAME} (Windows Scheduled Task)"
echo "  Status: schtasks /query /tn ${TASK_NAME}"
echo "  Delete: schtasks /delete /tn ${TASK_NAME} /f"
echo ""
echo "NOTE: For auto-restart on failure, consider using NSSM (nssm.cc):"
echo "  nssm install ${TASK_NAME} bash ${WRAPPER_WIN} ${AGENT} $(to_win_path "${TEMPLATE_ROOT}")"
