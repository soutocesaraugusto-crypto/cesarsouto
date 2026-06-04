#!/usr/bin/env bash
# quick-reply.sh — Fast response for simple messages using cheap model
#
# Uses runtime_print() to send a one-shot prompt with a cheap model,
# then delivers the response via send-channel.sh. Does NOT inject into tmux
# (preserves main session context).
#
# Usage:
#   quick-reply.sh <agent> <platform> <chat_id> "<user_message>" [model_override]
#
# Env: CRM_AGENT_NAME, CRM_TEMPLATE_ROOT, RUNTIME_MODEL
#
# Epic 114 / Story 114.5

set -uo pipefail

AGENT="${1:-${CRM_AGENT_NAME:-prisma}}"
PLATFORM="${2:-telegram}"
CHAT_ID="${3:-}"
USER_MSG="${4:-}"
MODEL_OVERRIDE="${5:-}"

if [[ -z "${CHAT_ID}" || -z "${USER_MSG}" ]]; then
    echo "Usage: quick-reply.sh <agent> <platform> <chat_id> \"<message>\" [model]" >&2
    exit 1
fi

TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
LOG_DIR="${CRM_ROOT}/logs/${AGENT}"
BUS_DIR="${TEMPLATE_ROOT}/core/bus"

# Source runtime for runtime_print
export CRM_AGENT_NAME="${AGENT}"
export CRM_TEMPLATE_ROOT="${TEMPLATE_ROOT}"
_RUNTIME_AGENT_DIR="${TEMPLATE_ROOT}/agents/${AGENT}"
source "${TEMPLATE_ROOT}/core/runtimes/runtime.sh"

# Determine model: explicit override > config smart_routing.model_quick > RUNTIME_MODEL
if [[ -z "${MODEL_OVERRIDE}" ]]; then
    CONFIG_FILE="${TEMPLATE_ROOT}/agents/${AGENT}/config.json"
    MODEL_OVERRIDE=$(jq -r '.smart_routing.model_quick // empty' "${CONFIG_FILE}" 2>/dev/null || echo "")
fi

# Build a concise prompt (don't inject full SOUL, save tokens)
SYSTEM_CONTEXT="You are The Oracle, a helpful AI assistant. Reply concisely in the same language as the user. Keep responses under 200 words for simple questions."

PROMPT="${SYSTEM_CONTEXT}

User: ${USER_MSG}

Reply:"

# Execute via runtime_print with 30s timeout (QA fix 114.5-B)
QUICK_TIMEOUT=30
START_MS=$(perl -e 'use Time::HiRes qw(time); printf "%d\n", time()*1000' 2>/dev/null || date +%s)
RESPONSE_FILE=$(mktemp /tmp/crm-quick-XXXXXX)

(
    if [[ -n "${MODEL_OVERRIDE}" ]]; then
        runtime_print "${PROMPT}" --model "${MODEL_OVERRIDE}"
    else
        runtime_print "${PROMPT}"
    fi
) > "${RESPONSE_FILE}" 2>/dev/null &
QR_PID=$!

ELAPSED=0
while kill -0 "${QR_PID}" 2>/dev/null && [[ ${ELAPSED} -lt ${QUICK_TIMEOUT} ]]; do
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done
if kill -0 "${QR_PID}" 2>/dev/null; then
    kill "${QR_PID}" 2>/dev/null || true
fi
wait "${QR_PID}" 2>/dev/null || true

RESPONSE=$(cat "${RESPONSE_FILE}" 2>/dev/null || echo "")
rm -f "${RESPONSE_FILE}"

END_MS=$(perl -e 'use Time::HiRes qw(time); printf "%d\n", time()*1000' 2>/dev/null || date +%s)
LATENCY=$((END_MS - START_MS))

# Source logger
source "${BUS_DIR}/_logger.sh" 2>/dev/null || true

if [[ -z "${RESPONSE}" ]]; then
    crm_log "quick_reply_failed" "Empty response from runtime_print" "agent=${AGENT}" "model=${MODEL_OVERRIDE}" "latency_ms=${LATENCY}"
    # Fallback: don't respond (let the message be processed normally by tmux session)
    exit 1
fi

# Send response via send-channel.sh
bash "${BUS_DIR}/send-channel.sh" "${PLATFORM}" "${CHAT_ID}" "${RESPONSE}" 2>/dev/null || {
    crm_log_error "quick_reply" "Failed to send response" "platform=${PLATFORM}" "chat_id=${CHAT_ID}"
    exit 1
}

crm_log "quick_reply" "Responded in ${LATENCY}ms" "agent=${AGENT}" "model=${MODEL_OVERRIDE:-default}" "latency_ms=${LATENCY}" "msg_len=${#USER_MSG}" "response_len=${#RESPONSE}"
