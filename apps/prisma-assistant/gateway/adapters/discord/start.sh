#!/usr/bin/env bash
# start.sh — Discord polling adapter daemon
#
# Polls Discord via check-discord.sh and writes normalized messages
# to channel-inbox/ for the fast-checker to pick up.
#
# Usage: start.sh <agent> <template_root>
# Env: CRM_INSTANCE_ID, CRM_ROOT (set by agent-wrapper.sh)
#
# Lifecycle: started by agent-wrapper.sh when adapter_mode=true.
# Writes PID to adapters/discord/.pid-{agent} for stop.sh.
# Handles SIGTERM for graceful shutdown.
#
# Story 114.18 Phase 1

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
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [discord-adapter/${AGENT}] $1" >> "${LOG_DIR}/activity.log" 2>/dev/null
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

log "Starting Discord polling adapter (PID $$)"

# Source agent env
export CRM_AGENT_NAME="${AGENT}"
export CRM_ROOT="${CRM_ROOT}"
export CRM_TEMPLATE_ROOT="${TEMPLATE_ROOT}"
export CRM_INSTANCE_ID="${CRM_INSTANCE_ID}"

ENV_FILE="${TEMPLATE_ROOT}/agents/${AGENT}/.env"
{ set +x; } 2>/dev/null
if [[ -f "${ENV_FILE}" ]]; then
    set -a; source "${ENV_FILE}"; set +a
fi

DISCORD_TOKEN="${DISCORD_TOKEN:-}"
DISCORD_CHANNEL_ID="${DISCORD_CHANNEL_ID:-}"
DISCORD_API="https://discord.com/api/v10"

if [[ -z "${DISCORD_TOKEN}" || -z "${DISCORD_CHANNEL_ID}" ]]; then
    log "ERROR: DISCORD_TOKEN or DISCORD_CHANNEL_ID not configured"
    rm -f "${PID_FILE}"
    exit 1
fi

# Track last message ID for polling
LAST_MSG_ID_FILE="${CRM_ROOT}/state/${AGENT}/.discord-last-msg-id"
mkdir -p "$(dirname "${LAST_MSG_ID_FILE}")" 2>/dev/null || true
LAST_MSG_ID=$(cat "${LAST_MSG_ID_FILE}" 2>/dev/null || echo "")

# Poll loop
while $RUNNING; do
    # Fetch new messages from Discord
    URL="${DISCORD_API}/channels/${DISCORD_CHANNEL_ID}/messages?limit=10"
    [[ -n "${LAST_MSG_ID}" ]] && URL="${URL}&after=${LAST_MSG_ID}"

    MSGS=$(curl -s "${URL}" \
        -H "Authorization: Bot ${DISCORD_TOKEN}" 2>/dev/null || echo "[]")

    # Discord returns newest first; reverse for chronological processing
    MSG_COUNT=$(echo "${MSGS}" | jq 'length' 2>/dev/null || echo "0")

    if [[ "${MSG_COUNT}" -gt 0 && "${MSG_COUNT}" != "null" ]]; then
        # Process messages in chronological order (reversed)
        echo "${MSGS}" | jq -c 'reverse | .[]' 2>/dev/null | while IFS= read -r msg; do
            [[ -z "$msg" ]] && continue

            # Skip bot messages
            IS_BOT=$(echo "$msg" | jq -r '.author.bot // false' 2>/dev/null)
            [[ "${IS_BOT}" == "true" ]] && continue

            MSG_ID=$(echo "$msg" | jq -r '.id // ""' 2>/dev/null)
            FROM=$(echo "$msg" | jq -r '.author.username // "unknown"' 2>/dev/null)
            USER_ID=$(echo "$msg" | jq -r '.author.id // ""' 2>/dev/null)
            TEXT=$(echo "$msg" | jq -r '.content // ""' 2>/dev/null)
            THREAD_REF=$(echo "$msg" | jq -r '.message_reference.message_id // ""' 2>/dev/null)
            TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

            # Check for attachments (images)
            HAS_ATTACHMENT=$(echo "$msg" | jq -r '.attachments | length > 0' 2>/dev/null || echo "false")
            MSG_TYPE="message"
            MEDIA_OBJ="null"

            if [[ "${HAS_ATTACHMENT}" == "true" ]]; then
                IMG_URL=$(echo "$msg" | jq -r '.attachments[0].url // ""' 2>/dev/null)
                IMG_TYPE=$(echo "$msg" | jq -r '.attachments[0].content_type // ""' 2>/dev/null)
                if [[ "${IMG_TYPE}" == image/* ]]; then
                    MSG_TYPE="photo"
                    MEDIA_OBJ=$(jq -n -c \
                        --arg type "photo" \
                        --arg url "${IMG_URL}" \
                        --arg caption "${TEXT}" \
                        --arg mime "${IMG_TYPE}" \
                        '{type: $type, local_path: $url, caption: $caption, mime_type: $mime}')
                fi
            fi

            # Build normalized message
            NORMALIZED=$(jq -n -c \
                --arg source "discord" \
                --arg type "${MSG_TYPE}" \
                --arg ts "${TIMESTAMP}" \
                --arg msg_id "${MSG_ID}" \
                --arg platform "discord" \
                --arg chat_id "${DISCORD_CHANNEL_ID}" \
                --arg thread_id "${THREAD_REF}" \
                --arg from "${FROM}" \
                --arg user_id "${USER_ID}" \
                --arg text "${TEXT}" \
                '{_source: $source, _type: $type, _timestamp: $ts, _message_id: $msg_id, platform: $platform, chat_id: $chat_id, from: $from, user_id: $user_id, text: $text}')

            # Add optional fields
            [[ -n "${THREAD_REF}" ]] && NORMALIZED=$(echo "${NORMALIZED}" | jq -c --arg tid "${THREAD_REF}" '. + {thread_id: $tid, reply_to_message_id: $tid}')
            [[ "${MEDIA_OBJ}" != "null" ]] && NORMALIZED=$(echo "${NORMALIZED}" | jq -c --argjson media "${MEDIA_OBJ}" '. + {media: $media}')

            # Write to channel-inbox
            bash "${BUS_DIR}/write-channel-inbox.sh" "${AGENT}" "${NORMALIZED}" > /dev/null 2>&1 || {
                log "Failed to write message to channel-inbox (msg_id=${MSG_ID})"
            }

            # Track latest message ID
            echo "${MSG_ID}" > "${LAST_MSG_ID_FILE}" 2>/dev/null || true

        done

        log "Processed ${MSG_COUNT} messages"
    fi

    # Poll interval: 3 seconds
    sleep 3
done

log "Adapter loop exited"
rm -f "${PID_FILE}"
