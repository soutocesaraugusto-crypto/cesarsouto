#!/usr/bin/env bash
# cron-executor.sh — Execute an isolated cron job via runtime_print()
#
# Runs a cron prompt in a subprocess (NOT in the main tmux session).
# Output is sent via send-channel.sh to --topic crons.
# Does NOT pollute the main conversation context.
#
# Usage:
#   cron-executor.sh <agent> <cron_name> "<prompt>" [model_override]
#
# Called by: agent-wrapper.sh for crons with "isolated": true
#
# Epic 114 / Story 114.6

set -uo pipefail

AGENT="${1:-${CRM_AGENT_NAME:-prisma}}"
CRON_NAME="${2:-unnamed}"
PROMPT="${3:-}"
MODEL_OVERRIDE="${4:-}"

if [[ -z "${PROMPT}" ]]; then
    echo "Usage: cron-executor.sh <agent> <cron_name> \"<prompt>\" [model]" >&2
    exit 1
fi

TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
LOG_DIR="${CRM_ROOT}/logs/${AGENT}"
BUS_DIR="${TEMPLATE_ROOT}/core/bus"

mkdir -p "${LOG_DIR}" 2>/dev/null || true

# Source runtime and logger
export CRM_AGENT_NAME="${AGENT}"
export CRM_TEMPLATE_ROOT="${TEMPLATE_ROOT}"
_RUNTIME_AGENT_DIR="${TEMPLATE_ROOT}/agents/${AGENT}"
source "${TEMPLATE_ROOT}/core/runtimes/runtime.sh"
source "${BUS_DIR}/_logger.sh" 2>/dev/null || true

# Source .env for CHAT_ID
ENV_FILE="${TEMPLATE_ROOT}/agents/${AGENT}/.env"
{ set +x; } 2>/dev/null
if [[ -f "${ENV_FILE}" ]]; then
    set -a; source "${ENV_FILE}"; set +a
fi

crm_log "cron_start" "Executing isolated cron: ${CRON_NAME}" "model=${MODEL_OVERRIDE:-default}"

START_S=$(date +%s)

# Execute via runtime_print with signal-based timeout (macOS-compatible)
# NOTE: We call runtime_print directly (not via bash -c subshell) to preserve
# runtime state and avoid shell injection via PROMPT content. (QA fix 114.6-A)
TIMEOUT=60
RESPONSE=""
RESPONSE_FILE=$(mktemp "${LOG_DIR}/.cron-response-XXXXXX" 2>/dev/null || mktemp)

# Run in background with kill-based timeout
(
    if [[ -n "${MODEL_OVERRIDE}" ]]; then
        runtime_print "${PROMPT}" --model "${MODEL_OVERRIDE}"
    else
        runtime_print "${PROMPT}"
    fi
) > "${RESPONSE_FILE}" 2>/dev/null &
CRON_PID=$!

# Wait with timeout
ELAPSED=0
while kill -0 "${CRON_PID}" 2>/dev/null && [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

# Kill if still running (timeout)
if kill -0 "${CRON_PID}" 2>/dev/null; then
    kill "${CRON_PID}" 2>/dev/null || true
    wait "${CRON_PID}" 2>/dev/null || true
    crm_log "cron_timeout" "Cron '${CRON_NAME}' timed out after ${TIMEOUT}s" "cron=${CRON_NAME}"
else
    wait "${CRON_PID}" 2>/dev/null || true
fi

RESPONSE=$(cat "${RESPONSE_FILE}" 2>/dev/null || echo "")
rm -f "${RESPONSE_FILE}"

END_S=$(date +%s)
DURATION=$((END_S - START_S))

if [[ -z "${RESPONSE}" ]]; then
    ERROR_MSG="Cron '${CRON_NAME}' failed: empty response after ${DURATION}s"
    crm_log "cron_error" "${ERROR_MSG}" "cron=${CRON_NAME}" "duration_s=${DURATION}"

    # Send error to alerts topic
    if [[ -n "${CHAT_ID:-}" ]]; then
        bash "${BUS_DIR}/send-channel.sh" telegram "${CHAT_ID}" "${ERROR_MSG}" --topic alerts 2>/dev/null || true
    fi
    exit 1
fi

# Send result to crons topic
HEADER="Cron: ${CRON_NAME} (${DURATION}s)"
FULL_MSG="${HEADER}

${RESPONSE}"

if [[ -n "${CHAT_ID:-}" ]]; then
    bash "${BUS_DIR}/send-channel.sh" telegram "${CHAT_ID}" "${FULL_MSG}" --topic crons 2>/dev/null || {
        crm_log_error "cron_delivery" "Failed to send cron result" "cron=${CRON_NAME}"
    }
fi

crm_log "cron_complete" "Cron '${CRON_NAME}' completed in ${DURATION}s" "cron=${CRON_NAME}" "duration_s=${DURATION}" "response_len=${#RESPONSE}"
