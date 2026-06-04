#!/usr/bin/env bash
# send-whatsapp.sh — Send message via WhatsApp (through local Baileys bridge)
#
# Uses shared pipeline modules: _message-pipeline.sh (sanitize, chunk, rate-limit)
#
# Usage:
#   bash send-whatsapp.sh <phone_number> "<message>" [flags...]
#   bash send-whatsapp.sh <phone_with_country_code> "Hello" --image /path/to/image.jpg
#
# Environment:
#   WHATSAPP_BRIDGE_PORT - Bridge HTTP port (default: 8445)
#
# Story 114.18 Phase 3

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_logger.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/_message-pipeline.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/_typing-indicator.sh" 2>/dev/null || true

# Stop typing indicator
typing_stop "whatsapp" 2>/dev/null || true

RECIPIENT="${1:-}"
MESSAGE="${2:-}"
IMAGE_PATH=""

shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --image)
            IMAGE_PATH="${2:-}"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

WHATSAPP_BRIDGE_PORT="${WHATSAPP_BRIDGE_PORT:-8445}"
BRIDGE_URL="http://127.0.0.1:${WHATSAPP_BRIDGE_PORT}"

if [[ -z "${RECIPIENT}" ]]; then
    crm_log_error "send_whatsapp" "Recipient required" 2>/dev/null || true
    echo "ERROR: Phone number required" >&2
    exit 1
fi

# Dry-run mode
if [[ "${DRY_RUN:-0}" == "1" ]]; then
    crm_log "dry_run" "Would send whatsapp message" "to=${RECIPIENT}" "msg_len=${#MESSAGE}" 2>/dev/null || true
    echo "DRY_RUN: message not sent (${#MESSAGE} chars to ${RECIPIENT})"
    exit 0
fi

# Check bridge is running
HEALTH=$(curl -s --max-time 3 "${BRIDGE_URL}/health" 2>/dev/null || echo "")
if [[ -z "${HEALTH}" ]]; then
    crm_log_error "send_whatsapp" "Bridge not responding" "port=${WHATSAPP_BRIDGE_PORT}" 2>/dev/null || true
    echo "ERROR: WhatsApp bridge not responding at ${BRIDGE_URL}" >&2
    exit 1
fi

WA_CONNECTED=$(echo "${HEALTH}" | jq -r '.connected // false' 2>/dev/null || echo "false")
if [[ "${WA_CONNECTED}" != "true" ]]; then
    crm_log_error "send_whatsapp" "WhatsApp not connected (need QR scan?)" 2>/dev/null || true
    echo "ERROR: WhatsApp not connected" >&2
    exit 1
fi

# --- Send function with retry ---
_send_with_retry() {
    local payload="$1"
    local max_retries=3
    local attempt=0

    while [[ ${attempt} -le ${max_retries} ]]; do
        pipeline_rate_limit "whatsapp" 200
        local response
        response=$(curl -s -w "\n%{http_code}" -X POST "${BRIDGE_URL}/send" \
            -H "Content-Type: application/json" \
            -d "${payload}" 2>/dev/null || echo -e "\n000")

        local http_code body
        http_code=$(echo "${response}" | tail -1)
        body=$(echo "${response}" | head -n -1)

        if [[ "${http_code}" == "200" ]]; then
            echo "${body}"
            return 0
        fi

        if [[ "${http_code}" == "000" || "${http_code}" =~ ^5 ]]; then
            attempt=$((attempt + 1))
            if [[ ${attempt} -le ${max_retries} ]]; then
                local delay=$((2 * (1 << (attempt - 1))))
                crm_log "whatsapp_retry" "Retrying (${attempt}/${max_retries})" "delay=${delay}s" "http=${http_code}" 2>/dev/null || true
                sleep "${delay}" 2>/dev/null || sleep 2
            fi
        else
            echo "${body}"
            return 1
        fi
    done

    echo "${body:-}"
    return 1
}

# --- Sanitize: WhatsApp uses its own markdown (*bold*, _italic_) ---
# Strip Claude's extra escapes, convert **bold** → *bold*
MESSAGE=$(pipeline_strip_markdown "$MESSAGE" 2>/dev/null || echo "$MESSAGE")

# --- WhatsApp-specific send function for pipeline ---
LAST_RESPONSE=""

_wa_send_chunk() {
    local chunk="$1" is_first="$2" is_last="$3"
    local payload
    if [[ -n "${IMAGE_PATH}" && "${is_first}" == "true" ]]; then
        payload=$(jq -n -c --arg to "${RECIPIENT}" --arg text "${chunk}" --arg img "${IMAGE_PATH}" \
            '{to: $to, text: $text, image_url: $img}')
    else
        payload=$(jq -n -c --arg to "${RECIPIENT}" --arg text "${chunk}" \
            '{to: $to, text: $text}')
    fi
    LAST_RESPONSE=$(_send_with_retry "${payload}")
    [[ "${is_last}" != "true" ]] && return 0
    echo "${LAST_RESPONSE}"
}

# --- Send via shared pipeline (auto-chunk at 4096, code-fence-aware) ---
pipeline_chunk_and_send "$MESSAGE" 4096 "_wa_send_chunk"

# Check result
if echo "${LAST_RESPONSE}" | jq -e '.ok == true' > /dev/null 2>&1; then
    crm_log "whatsapp_send" "Message sent" "to=${RECIPIENT}" "msg_len=${#MESSAGE}" 2>/dev/null || true
    echo "sent"
else
    ERR=$(echo "${LAST_RESPONSE}" | jq -r '.error // "Unknown error"' 2>/dev/null || echo "Unknown error")
    crm_log_error "send_whatsapp" "Failed to send" "to=${RECIPIENT}" "error=${ERR}" 2>/dev/null || true
    echo "ERROR: ${ERR}" >&2
    exit 1
fi
