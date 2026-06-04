#!/usr/bin/env bash
# send-channel.sh — 8-Stage Outbound Delivery Pipeline
#
# All agent replies go through THIS. The 8 stages are:
#   1. Normalize   — validate required fields, sanitize text
#   2. Select      — verify channel enabled + health state
#   3. Chunk       — split by channel limit (code-fence-aware)
#   4. Format      — per-channel formatting (HTML/mrkdwn/strip)
#   5. Enqueue     — write-ahead persist BEFORE send
#   6. Dispatch    — call adapter send script
#   7. Finalize    — ack on success, nack+classify on failure
#   8. Transcript  — append to activity.log with delivery metadata
#
# Usage:
#   bash send-channel.sh <platform> <chat_id> "<message>" [flags...]
#   CHANNEL_TYPE=telegram bash send-channel.sh <chat_id> "<message>" [flags...]
#
# Story 114.19 Phase 3 — Outbound Pipeline Formalization
# Pattern: OpenClaw deliver.ts (9-stage pipeline)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_logger.sh" 2>/dev/null || true

AGENT="${CRM_AGENT_NAME:-prisma}"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
QUEUE_SCRIPT="${SCRIPT_DIR}/delivery-queue.sh"

# ============================================================
# Stage 1: NORMALIZE — Parse arguments, validate required fields
# ============================================================

PLATFORM=""
RECIPIENT=""
MESSAGE=""

if [[ "${1:-}" =~ ^(telegram|discord|web|webhook|whatsapp|slack)$ ]]; then
    PLATFORM="$1"
    RECIPIENT="${2:-}"
    MESSAGE="${3:-}"
    shift 3 2>/dev/null || true
else
    PLATFORM="${CHANNEL_TYPE:-telegram}"
    RECIPIENT="${1:-}"
    MESSAGE="${2:-}"
    shift 2 2>/dev/null || true
fi

if [[ -z "${PLATFORM}" || -z "${RECIPIENT}" ]]; then
    crm_log_error "pipeline_normalize" "Missing platform or recipient" 2>/dev/null || true
    echo "ERROR: platform and recipient required" >&2
    exit 1
fi

# ============================================================
# Stage 2: SELECT — Verify channel adapter exists
# ============================================================

ADAPTER_SCRIPT="${SCRIPT_DIR}/send-${PLATFORM}.sh"
if [[ ! -f "${ADAPTER_SCRIPT}" ]]; then
    crm_log_error "pipeline_select" "No adapter for platform: ${PLATFORM}" 2>/dev/null || true
    echo "ERROR: Unknown platform '${PLATFORM}'. Supported: telegram, web, discord, whatsapp, slack" >&2
    exit 1
fi

# Optional: check adapter health cache (non-blocking — only warns)
HEALTH_CACHE="${CRM_ROOT}/state/${AGENT}/.channel-health-${PLATFORM}.json"
if [[ -f "${HEALTH_CACHE}" ]]; then
    HEALTH_STATUS=$(jq -r '.status // "unknown"' "${HEALTH_CACHE}" 2>/dev/null || echo "unknown")
    if [[ "${HEALTH_STATUS}" == "dead" ]]; then
        crm_log "pipeline_select" "WARNING: channel ${PLATFORM} health is DEAD — attempting send anyway" 2>/dev/null || true
    fi
fi

# ============================================================
# Stage 3+4: CHUNK + FORMAT — Handled inside adapter scripts
# Each send-{platform}.sh uses _message-pipeline.sh for:
#   - pipeline_sanitize_html (telegram) / pipeline_strip_markdown (others)
#   - pipeline_chunk_and_send at platform char limit
# ============================================================

# ============================================================
# Stage 5: ENQUEUE — Write-ahead persist BEFORE send
# ============================================================

QUEUE_ID=""
if [[ -z "${_QUEUE_BYPASS_WRITE_AHEAD:-}" && -f "${QUEUE_SCRIPT}" && -n "${MESSAGE}" ]]; then
    QUEUE_ID=$(bash "${QUEUE_SCRIPT}" pre-send "${AGENT}" "${PLATFORM}" "${RECIPIENT}" "${MESSAGE}" "$@" 2>/dev/null || echo "")
fi

# ============================================================
# Stage 6: DISPATCH — Call adapter send script
# ============================================================

# Pre-send hook (configurable extension point)
PIPELINE_CONFIG="${TEMPLATE_ROOT}/agents/${AGENT}/config.json"
PRE_SEND_HOOK=""
if [[ -f "${PIPELINE_CONFIG}" ]]; then
    PRE_SEND_HOOK=$(jq -r '.outbound_pipeline.pre_send_hook // empty' "${PIPELINE_CONFIG}" 2>/dev/null || echo "")
fi
if [[ -n "${PRE_SEND_HOOK}" && -f "${TEMPLATE_ROOT}/${PRE_SEND_HOOK}" ]]; then
    bash "${TEMPLATE_ROOT}/${PRE_SEND_HOOK}" "${PLATFORM}" "${RECIPIENT}" "${MESSAGE}" 2>/dev/null || true
fi

SEND_EXIT=0
bash "${ADAPTER_SCRIPT}" "${RECIPIENT}" "${MESSAGE}" "$@"
SEND_EXIT=$?

# Post-send hook (transcript mirror)
TRANSCRIPT_MIRROR=""
if [[ -f "${PIPELINE_CONFIG}" ]]; then
    TRANSCRIPT_MIRROR=$(jq -r '.outbound_pipeline.transcript_mirror_channel // empty' "${PIPELINE_CONFIG}" 2>/dev/null || echo "")
fi
if [[ -n "${TRANSCRIPT_MIRROR}" && ${SEND_EXIT} -eq 0 ]]; then
    # Mirror a copy of the sent message to the configured channel (fire-and-forget)
    _QUEUE_BYPASS_WRITE_AHEAD=1 bash "${SCRIPT_DIR}/send-channel.sh" ${TRANSCRIPT_MIRROR} "[mirror] ${MESSAGE}" 2>/dev/null &
fi

# ============================================================
# Stage 7: FINALIZE — Ack or nack based on send result
# ============================================================

if [[ -n "${QUEUE_ID}" && -f "${QUEUE_SCRIPT}" ]]; then
    if [[ ${SEND_EXIT} -eq 0 ]]; then
        bash "${QUEUE_SCRIPT}" ack "${AGENT}" "${QUEUE_ID}" 2>/dev/null || true
    else
        bash "${QUEUE_SCRIPT}" nack "${AGENT}" "${QUEUE_ID}" "send failed with exit ${SEND_EXIT}" 2>/dev/null || true
    fi
fi

# ============================================================
# Stage 8: TRANSCRIPT — Log delivery metadata
# ============================================================

LOG_DIR="${CRM_ROOT}/logs/${AGENT}"
TRANSCRIPT_ENABLED="true"
if [[ -f "${PIPELINE_CONFIG}" ]]; then
    TRANSCRIPT_ENABLED=$(jq -r '.outbound_pipeline.transcript_log // true' "${PIPELINE_CONFIG}" 2>/dev/null || echo "true")
fi

if [[ "${TRANSCRIPT_ENABLED}" == "true" ]]; then
    OUTCOME="success"
    [[ ${SEND_EXIT} -ne 0 ]] && OUTCOME="failed"
    crm_log "pipeline_transcript" "Delivery ${OUTCOME}" \
        "platform=${PLATFORM}" \
        "recipient=${RECIPIENT}" \
        "msg_len=${#MESSAGE}" \
        "queue_id=${QUEUE_ID:-none}" \
        "outcome=${OUTCOME}" \
        "exit=${SEND_EXIT}" 2>/dev/null || true
fi

exit ${SEND_EXIT}
