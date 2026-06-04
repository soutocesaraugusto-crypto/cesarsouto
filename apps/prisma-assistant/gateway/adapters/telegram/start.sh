#!/usr/bin/env bash
# start.sh — Telegram polling adapter daemon
#
# Polls Telegram via check-telegram.sh and writes normalized messages
# to channel-inbox/ for the fast-checker to pick up.
#
# Usage: start.sh <agent> <template_root>
# Env: CRM_INSTANCE_ID, CRM_ROOT (set by agent-wrapper.sh)
#
# Lifecycle: started by agent-wrapper.sh when adapter_mode=true.
# Writes PID to adapters/telegram/.pid for stop.sh.
# Handles SIGTERM for graceful shutdown.
#
# Epic 110 / Story 110.27 Phase 3

set -uo pipefail

AGENT="${1:-}"
TEMPLATE_ROOT="${2:-$(cd "$(dirname "$0")/../.." && pwd)}"

if [[ -z "${AGENT}" ]]; then
    echo "Usage: start.sh <agent> <template_root>" >&2
    exit 1
fi

CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
BUS_DIR="${TEMPLATE_ROOT}/core/bus"
ADAPTER_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="${ADAPTER_DIR}/.pid-${AGENT}"
LOG_DIR="${CRM_ROOT}/logs/${AGENT}"

mkdir -p "${LOG_DIR}" 2>/dev/null || true

log() {
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [telegram-adapter/${AGENT}] $1" >> "${LOG_DIR}/activity.log" 2>/dev/null
}

# Write PID for stop.sh
echo $$ > "${PID_FILE}"
RUNNING=true

cleanup() {
    RUNNING=false
    rm -f "${PID_FILE}"
    log "Stopped (SIGTERM)"
}
trap cleanup SIGTERM SIGINT

log "Starting Telegram polling adapter (PID $$)"

# Source agent env for check-telegram.sh
export CRM_AGENT_NAME="${AGENT}"
export CRM_ROOT="${CRM_ROOT}"
export CRM_TEMPLATE_ROOT="${TEMPLATE_ROOT}"
export CRM_INSTANCE_ID="${CRM_INSTANCE_ID}"

# Source Telegram helpers for typing indicator
source "${BUS_DIR}/_telegram-curl.sh" 2>/dev/null || true
ENV_FILE="${TEMPLATE_ROOT}/agents/${AGENT}/.env"
{ set +x; } 2>/dev/null
if [[ -f "${ENV_FILE}" ]]; then
    set -a; source "${ENV_FILE}"; set +a
fi

# Poll loop
while $RUNNING; do
    # Call check-telegram.sh — it handles offset, ALLOWED_USER, reactions
    TG_OUTPUT=$(bash "${BUS_DIR}/check-telegram.sh" 2>/dev/null || echo "")

    if [[ -n "${TG_OUTPUT}" ]]; then
        # Send typing indicator
        if [[ -n "${CHAT_ID:-}" ]]; then
            telegram_api_post "sendChatAction" -d chat_id="${CHAT_ID}" -d action="typing" > /dev/null 2>&1 || true
        fi

        # Normalize each message line to adapter-message schema and write to channel-inbox
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue

            # Extract fields from check-telegram.sh output
            TYPE=$(echo "$line" | jq -r '.type // "message"' 2>/dev/null || echo "message")
            FROM=$(echo "$line" | jq -r '.from // "unknown"' 2>/dev/null || echo "unknown")
            TEXT=$(echo "$line" | jq -r '.text // ""' 2>/dev/null || echo "")
            LINE_CHAT_ID=$(echo "$line" | jq -r '.chat_id // ""' 2>/dev/null || echo "")
            DATE=$(echo "$line" | jq -r '.date // 0' 2>/dev/null || echo "0")
            TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

            # Build normalized message based on type
            case "${TYPE}" in
                message)
                    NORMALIZED=$(jq -n -c \
                        --arg source "telegram" \
                        --arg type "message" \
                        --arg ts "${TIMESTAMP}" \
                        --arg platform "telegram" \
                        --arg chat_id "${LINE_CHAT_ID}" \
                        --arg from "${FROM}" \
                        --arg text "${TEXT}" \
                        '{_source: $source, _type: $type, _timestamp: $ts, platform: $platform, chat_id: ($chat_id | tostring), from: $from, text: $text}')
                    ;;
                photo)
                    IMAGE_PATH=$(echo "$line" | jq -r '.image_path // ""' 2>/dev/null || echo "")
                    NORMALIZED=$(jq -n -c \
                        --arg source "telegram" \
                        --arg type "photo" \
                        --arg ts "${TIMESTAMP}" \
                        --arg platform "telegram" \
                        --arg chat_id "${LINE_CHAT_ID}" \
                        --arg from "${FROM}" \
                        --arg text "${TEXT}" \
                        --arg img_path "${IMAGE_PATH}" \
                        '{_source: $source, _type: $type, _timestamp: $ts, platform: $platform, chat_id: ($chat_id | tostring), from: $from, text: $text, media: {type: "photo", local_path: $img_path, caption: $text}}')
                    ;;
                callback)
                    CB_DATA=$(echo "$line" | jq -r '.callback_data // ""' 2>/dev/null || echo "")
                    CB_QID=$(echo "$line" | jq -r '.callback_query_id // ""' 2>/dev/null || echo "")
                    CB_MSG_ID=$(echo "$line" | jq -r '.message_id // ""' 2>/dev/null || echo "")
                    NORMALIZED=$(jq -n -c \
                        --arg source "telegram" \
                        --arg type "callback" \
                        --arg ts "${TIMESTAMP}" \
                        --arg platform "telegram" \
                        --arg chat_id "${LINE_CHAT_ID}" \
                        --arg from "${FROM}" \
                        --arg text "" \
                        --arg cb_data "${CB_DATA}" \
                        --arg cb_qid "${CB_QID}" \
                        --arg msg_id "${CB_MSG_ID}" \
                        '{_source: $source, _type: $type, _timestamp: $ts, platform: $platform, chat_id: ($chat_id | tostring), from: $from, text: $text, callback_data: $cb_data, callback_query_id: $cb_qid, _message_id: $msg_id}')
                    ;;
                *)
                    log "Unknown message type: ${TYPE}"
                    continue
                    ;;
            esac

            # Write to channel-inbox via atomic helper
            bash "${BUS_DIR}/write-channel-inbox.sh" "${AGENT}" "${NORMALIZED}" > /dev/null 2>&1 || {
                log "Failed to write message to channel-inbox"
            }

        done <<< "${TG_OUTPUT}"
    fi

    # Poll interval: 1 second (check-telegram.sh uses 5s long-poll timeout internally)
    sleep 1
done

log "Adapter loop exited"
rm -f "${PID_FILE}"
