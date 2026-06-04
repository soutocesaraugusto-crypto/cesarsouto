#!/usr/bin/env bash
# enable-agent.sh - Enable a Claude Remote Manager agent
# Usage: enable-agent.sh <agent_name> [--restart]

set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "$0")" && pwd)"

# Load instance ID
REPO_ENV="${TEMPLATE_ROOT}/.env"
if [[ -f "${REPO_ENV}" ]]; then
    CRM_INSTANCE_ID=$(grep '^CRM_INSTANCE_ID=' "${REPO_ENV}" | cut -d= -f2)
fi
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${HOME}/.claude-remote/${CRM_INSTANCE_ID}"

AGENT="${1:?Usage: enable-agent.sh <agent_name> [--restart]}"
RESTART=false
[[ "${2:-}" == "--restart" ]] && RESTART=true

# Agent dir resolution (self-contained package first, legacy hub second).
# Self-contained: agents live in <gateway>/agents/<slug>/.
# Legacy hub: <hub>/.aiox/message-gateway/agents/<slug>/.
SINKRA_HUB="${PRISMA_HOME:-$(cd "${TEMPLATE_ROOT}/../.." && pwd)}"
RUNTIME_DIR="${TEMPLATE_ROOT}"
AGENT_DIR="${TEMPLATE_ROOT}/agents/${AGENT}"
if [[ ! -d "${AGENT_DIR}" && -d "${SINKRA_HUB}/.aiox/message-gateway/agents/${AGENT}" ]]; then
    RUNTIME_DIR="${SINKRA_HUB}/.aiox/message-gateway"
    AGENT_DIR="${RUNTIME_DIR}/agents/${AGENT}"
fi
ENABLED_FILE="${CRM_ROOT}/config/enabled-agents.json"

# Ensure enabled-agents.json exists
if [[ ! -f "${ENABLED_FILE}" ]]; then
    mkdir -p "$(dirname "${ENABLED_FILE}")"
    echo '{}' > "${ENABLED_FILE}"
fi

# Validate agent directory exists
if [[ ! -d "${AGENT_DIR}" ]]; then
    echo "ERROR: Unknown agent '${AGENT}' - no directory at ${AGENT_DIR}"
    echo "Available agents:"
    for d in "${RUNTIME_DIR}/agents"/*/; do
        name=$(basename "$d")
        [[ "${name}" == "agent-template" ]] && continue
        echo "  ${name}"
    done
    exit 1
fi

# Check if already enabled (unless restarting)
if [[ "${RESTART}" != "true" ]]; then
    IS_ENABLED=$(jq -r ".\"${AGENT}\".enabled" "${ENABLED_FILE}" 2>/dev/null || echo "false")
    if [[ "${IS_ENABLED}" == "true" ]]; then
        echo "${AGENT} is already enabled."
        echo "Use --restart to restart it, or ./disable-agent.sh ${AGENT} first."
        exit 0
    fi
fi

echo "========================================="
echo "  Enabling: ${AGENT}"
echo "========================================="
echo ""

if [[ "${RESTART}" == "true" ]]; then
    echo "Restarting ${AGENT}..."

    # Reset crash counter
    rm -f "${CRM_ROOT}/logs/${AGENT}/.crash_count_today"

    # Detect platform and restart accordingly
    # shellcheck source=core/scripts/detect-platform.sh
    source "${TEMPLATE_ROOT}/core/scripts/detect-platform.sh"

    case "${CRM_PLATFORM}" in
        darwin)
            PLIST="${HOME}/Library/LaunchAgents/com.claude-remote.${CRM_INSTANCE_ID}.${AGENT}.plist"
            if [[ -f "${PLIST}" ]]; then
                launchctl unload "${PLIST}" 2>/dev/null || true
                launchctl load "${PLIST}"
                echo "${AGENT} restarted."
            else
                echo "No launchd plist found. Running full setup..."
                "${TEMPLATE_ROOT}/core/scripts/generate-persistence.sh" "${AGENT}"
            fi
            ;;
        linux)
            SERVICE_NAME="crm-${CRM_INSTANCE_ID}-${AGENT}"
            if systemctl --user is-active "${SERVICE_NAME}" &>/dev/null; then
                systemctl --user restart "${SERVICE_NAME}"
                echo "${AGENT} restarted."
            else
                echo "No systemd unit found. Running full setup..."
                "${TEMPLATE_ROOT}/core/scripts/generate-persistence.sh" "${AGENT}"
            fi
            ;;
        windows)
            TASK_NAME="crm-${CRM_INSTANCE_ID}-${AGENT}"
            SCHTASKS_CMD="schtasks.exe"
            command -v schtasks.exe &>/dev/null || SCHTASKS_CMD="schtasks"
            ${SCHTASKS_CMD} /end /tn "${TASK_NAME}" 2>/dev/null || true
            ${SCHTASKS_CMD} /run /tn "${TASK_NAME}" 2>/dev/null || {
                echo "No scheduled task found. Running full setup..."
                "${TEMPLATE_ROOT}/core/scripts/generate-persistence.sh" "${AGENT}"
            }
            echo "${AGENT} restarted."
            ;;
        *)
            echo "ERROR: Unsupported platform '${CRM_PLATFORM}'" >&2
            exit 1
            ;;
    esac
    exit 0
fi

# Set environment for the agent
export CRM_AGENT_NAME="${AGENT}"
export CRM_INSTANCE_ID="${CRM_INSTANCE_ID}"
export CRM_ROOT="${CRM_ROOT}"
export CRM_TEMPLATE_ROOT="${TEMPLATE_ROOT}"

# Ensure all scripts are executable
chmod +x "${TEMPLATE_ROOT}/"*.sh 2>/dev/null || true
chmod +x "${TEMPLATE_ROOT}/core/scripts/"*.sh 2>/dev/null || true
chmod +x "${TEMPLATE_ROOT}/core/bus/"*.sh 2>/dev/null || true

# Create per-agent state directories
mkdir -p "${CRM_ROOT}/inbox/${AGENT}"
mkdir -p "${CRM_ROOT}/outbox/${AGENT}"
mkdir -p "${CRM_ROOT}/processed/${AGENT}"
mkdir -p "${CRM_ROOT}/inflight/${AGENT}"
mkdir -p "${CRM_ROOT}/logs/${AGENT}"

# Validate adapter contracts for enabled channels (Story 114.19 Phase 2)
VALIDATOR="${TEMPLATE_ROOT}/core/scripts/validate-adapter-contract.sh"
CONFIG_FILE="${TEMPLATE_ROOT}/agents/${AGENT}/config.json"
if [[ -f "${VALIDATOR}" && -f "${CONFIG_FILE}" ]]; then
    ENABLED_CHANNELS=$(jq -r '.channels[]? | select(.enabled == true) | .type' "${CONFIG_FILE}" 2>/dev/null || echo "")
    for ch in ${ENABLED_CHANNELS}; do
        bash "${VALIDATOR}" "${ch}" > /dev/null 2>&1
        VC_EXIT=$?
        if [[ ${VC_EXIT} -eq 2 ]]; then
            echo "ERROR: Adapter contract validation FAILED for ${ch} — fix errors before enabling"
            bash "${VALIDATOR}" "${ch}" 2>&1 | grep "ERROR"
            exit 1
        elif [[ ${VC_EXIT} -eq 1 ]]; then
            echo "WARNING: Adapter ${ch} has contract warnings (non-blocking)"
        fi
    done
fi

# Generate and load platform-specific persistence
echo ""
echo "Setting up persistence..."
"${TEMPLATE_ROOT}/core/scripts/generate-persistence.sh" "${AGENT}"

# Update enabled status
jq ".\"${AGENT}\".enabled = true | .\"${AGENT}\".status = \"configured\"" "${ENABLED_FILE}" > "${ENABLED_FILE}.tmp"
mv "${ENABLED_FILE}.tmp" "${ENABLED_FILE}"

echo ""
echo "========================================="
echo "  ${AGENT} is now LIVE"
echo "========================================="
echo ""
echo "  persistence: active (auto-restarts on crash)"
echo "  tmux: attach with: tmux attach -t crm-${CRM_INSTANCE_ID}-${AGENT}"
echo ""
echo "  Test it: Send a message to the agent's Telegram bot"
echo ""
