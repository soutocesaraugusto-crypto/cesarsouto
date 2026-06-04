#!/usr/bin/env bash
# send-discord.sh — Send message to Discord channel via REST API
#
# Features:
#   - Embed support (title, description, color, footer)
#   - Thread reply support via message_reference
#   - Auto-split at 2000 chars (Discord limit) via shared pipeline
#   - Typing indicator before sending
#   - Image upload via multipart form-data
#   - Rate limiter respecting X-RateLimit-Remaining + Retry-After
#   - Retry with exponential backoff for transient errors
#   - Markdown → HTML sanitization via shared pipeline
#
# Usage:
#   bash send-discord.sh <channel_id> "<message>" [flags...]
#   bash send-discord.sh <channel_id> "<message>" --embed-title "Title" --embed-color 0x00FF00
#   bash send-discord.sh <channel_id> "<message>" --reply-to <message_id>
#   bash send-discord.sh <channel_id> "<message>" --image /path/to/image.jpg
#   bash send-discord.sh <channel_id> "<message>" --thread <thread_id>
#
# Environment:
#   DISCORD_TOKEN - Discord bot token
#
# Story 114.18 Phase 1 — Discord Production

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_logger.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/_message-pipeline.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/_typing-indicator.sh" 2>/dev/null || true

# Stop typing indicator (started by fast-checker on message receive)
typing_stop "discord" 2>/dev/null || true

CHANNEL_ID="${1:-}"
MESSAGE="${2:-}"
DISCORD_TOKEN="${DISCORD_TOKEN:-}"

# Parse optional flags
EMBED_TITLE=""
EMBED_COLOR=""
EMBED_FOOTER=""
REPLY_TO=""
IMAGE_PATH=""
THREAD_ID=""

shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --embed-title)
            EMBED_TITLE="${2:-}"
            shift 2
            ;;
        --embed-color)
            EMBED_COLOR="${2:-}"
            shift 2
            ;;
        --embed-footer)
            EMBED_FOOTER="${2:-}"
            shift 2
            ;;
        --reply-to)
            REPLY_TO="${2:-}"
            shift 2
            ;;
        --image)
            IMAGE_PATH="${2:-}"
            shift 2
            ;;
        --thread)
            THREAD_ID="${2:-}"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [[ -z "${DISCORD_TOKEN}" ]]; then
    crm_log_error "send_discord" "DISCORD_TOKEN not set" 2>/dev/null || true
    echo "ERROR: DISCORD_TOKEN not set" >&2
    exit 1
fi

if [[ -z "${CHANNEL_ID}" ]]; then
    crm_log_error "send_discord" "Channel ID required" 2>/dev/null || true
    echo "ERROR: Channel ID required" >&2
    exit 1
fi

# Dry-run mode
if [[ "${DRY_RUN:-0}" == "1" ]]; then
    crm_log "dry_run" "Would send discord message" "channel_id=${CHANNEL_ID}" "msg_len=${#MESSAGE}" 2>/dev/null || true
    echo "DRY_RUN: message not sent (${#MESSAGE} chars to ${CHANNEL_ID})"
    exit 0
fi

DISCORD_API="https://discord.com/api/v10"

# --- Discord-specific rate limiter (reads X-RateLimit headers) ---
RATE_FILE="/tmp/crm-discord-rate-${CHANNEL_ID}.txt"

_update_rate_info() {
    local headers="$1"
    local remaining reset_after
    remaining=$(echo "${headers}" | grep -i 'x-ratelimit-remaining' | awk '{print $2}' | tr -d '\r\n' || echo "")
    reset_after=$(echo "${headers}" | grep -i 'x-ratelimit-reset-after' | awk '{print $2}' | tr -d '\r\n' || echo "")
    if [[ -n "${remaining}" ]]; then
        printf '%s\n%s\n' "${remaining}" "${reset_after:-1}" > "${RATE_FILE}" 2>/dev/null || true
    fi
}

_discord_rate_check() {
    if [[ -f "${RATE_FILE}" ]]; then
        local remaining reset_after
        remaining=$(head -1 "${RATE_FILE}" 2>/dev/null || echo "5")
        reset_after=$(tail -1 "${RATE_FILE}" 2>/dev/null || echo "0")
        if [[ "${remaining}" == "0" && -n "${reset_after}" ]]; then
            sleep "${reset_after}" 2>/dev/null || sleep 1
        fi
    fi
}

# --- Retry with exponential backoff ---
_discord_post_retry() {
    local url="$1"; shift
    local max_retries=3
    local attempt=0
    local response="" headers=""

    while [[ ${attempt} -le ${max_retries} ]]; do
        _discord_rate_check
        pipeline_rate_limit "discord" 200

        local header_file
        header_file=$(mktemp /tmp/discord-headers-XXXXXX 2>/dev/null || echo "/tmp/discord-headers-$$")
        response=$(curl -s -D "${header_file}" -X POST "${url}" \
            -H "Authorization: Bot ${DISCORD_TOKEN}" \
            "$@" 2>/dev/null || echo "")
        headers=$(cat "${header_file}" 2>/dev/null || echo "")
        rm -f "${header_file}" 2>/dev/null

        _update_rate_info "${headers}"

        if echo "${response}" | jq -e '.id' > /dev/null 2>&1; then
            echo "${response}"
            return 0
        fi

        local code
        code=$(echo "${response}" | jq -r '.code // 0' 2>/dev/null || echo "0")
        local retry_after
        retry_after=$(echo "${response}" | jq -r '.retry_after // 0' 2>/dev/null || echo "0")

        if [[ "${code}" == "0" && -z "${response}" ]] || \
           echo "${headers}" | grep -q "429" 2>/dev/null || \
           echo "${headers}" | grep -q "^HTTP.*5[0-9][0-9]" 2>/dev/null; then
            attempt=$((attempt + 1))
            if [[ ${attempt} -le ${max_retries} ]]; then
                local delay=$((2 * (1 << (attempt - 1))))
                [[ "${retry_after}" != "0" && "${retry_after}" != "null" ]] && \
                    delay=$(printf "%.0f" "${retry_after}" 2>/dev/null || echo "${delay}")
                crm_log "discord_retry" "Retrying (attempt ${attempt}/${max_retries})" "delay=${delay}s" "code=${code}" 2>/dev/null || true
                sleep "${delay}" 2>/dev/null || sleep 2
            fi
        else
            echo "${response}"
            return 1
        fi
    done

    echo "${response}"
    return 1
}

# --- Typing indicator ---
_send_typing() {
    curl -s -X POST "${DISCORD_API}/channels/${CHANNEL_ID}/typing" \
        -H "Authorization: Bot ${DISCORD_TOKEN}" \
        -H "Content-Length: 0" \
        > /dev/null 2>&1 || true
}

# --- Send image ---
if [[ -n "${IMAGE_PATH}" ]]; then
    if [[ ! -f "${IMAGE_PATH}" ]]; then
        crm_log_error "send_discord" "Image file not found" "path=${IMAGE_PATH}" 2>/dev/null || true
        echo "ERROR: Image file not found: ${IMAGE_PATH}" >&2
        exit 1
    fi
    _send_typing
    PAYLOAD_JSON=$(jq -n -c --arg content "${MESSAGE}" '{content: $content}')
    if [[ -n "${THREAD_ID}" ]]; then
        PAYLOAD_JSON=$(echo "${PAYLOAD_JSON}" | jq -c --arg tid "${THREAD_ID}" '. + {message_reference: {message_id: $tid, fail_if_not_exists: false}}')
    fi
    RESPONSE=$(_discord_post_retry "${DISCORD_API}/channels/${CHANNEL_ID}/messages" \
        -F "payload_json=${PAYLOAD_JSON}" \
        -F "files[0]=@${IMAGE_PATH}")
    if echo "${RESPONSE}" | jq -e '.id' > /dev/null 2>&1; then
        MSG_ID=$(echo "${RESPONSE}" | jq -r '.id')
        crm_log "discord_send" "Image sent" "channel_id=${CHANNEL_ID}" "msg_id=${MSG_ID}" 2>/dev/null || true
        echo "${MSG_ID}"
    else
        crm_log_error "send_discord" "Failed to send image" "channel_id=${CHANNEL_ID}" 2>/dev/null || true
        echo "ERROR: Failed to send image" >&2
        exit 1
    fi
    exit 0
fi

# --- Sanitize markdown (strip for Discord — it has its own markdown parser) ---
# Discord natively supports markdown, so we strip Claude's extra escapes only
MESSAGE=$(pipeline_strip_markdown "$MESSAGE" 2>/dev/null || echo "$MESSAGE")

# --- Build message payload ---
_build_payload() {
    local chunk="$1"
    local with_embed="${2:-false}"
    local payload

    if [[ "${with_embed}" == "true" && -n "${EMBED_TITLE}" ]]; then
        local embed
        embed=$(jq -n -c \
            --arg title "${EMBED_TITLE}" \
            --arg desc "${chunk}" \
            '{title: $title, description: $desc}')
        [[ -n "${EMBED_COLOR}" ]] && embed=$(echo "${embed}" | jq -c --argjson color "${EMBED_COLOR}" '. + {color: $color}')
        [[ -n "${EMBED_FOOTER}" ]] && embed=$(echo "${embed}" | jq -c --arg footer "${EMBED_FOOTER}" '. + {footer: {text: $footer}}')
        payload=$(jq -n -c --argjson embeds "[${embed}]" '{embeds: $embeds}')
    else
        payload=$(jq -n -c --arg content "${chunk}" '{content: $content}')
    fi

    [[ -n "${REPLY_TO}" ]] && payload=$(echo "${payload}" | jq -c --arg mid "${REPLY_TO}" '. + {message_reference: {message_id: $mid, fail_if_not_exists: false}}')
    [[ -n "${THREAD_ID}" ]] && payload=$(echo "${payload}" | jq -c --arg tid "${THREAD_ID}" '. + {message_reference: {message_id: $tid, fail_if_not_exists: false}}')

    echo "${payload}"
}

# --- Send typing ---
_send_typing

# --- Discord-specific send function for pipeline ---
LAST_RESPONSE=""
FIRST_CHUNK=true

_discord_send_chunk() {
    local chunk="$1" is_first="$2" is_last="$3"
    local with_embed="false"
    [[ "${is_first}" == "true" && -n "${EMBED_TITLE}" ]] && with_embed="true"

    local payload
    payload=$(_build_payload "${chunk}" "${with_embed}")

    LAST_RESPONSE=$(_discord_post_retry "${DISCORD_API}/channels/${CHANNEL_ID}/messages" \
        -H "Content-Type: application/json" \
        -d "${payload}")

    [[ "${is_last}" != "true" ]] && return 0
    echo "${LAST_RESPONSE}"
}

# --- Send via shared pipeline (auto-chunk at 2000, code-fence-aware) ---
DISCORD_MAX=2000
pipeline_chunk_and_send "$MESSAGE" ${DISCORD_MAX} "_discord_send_chunk"

# --- Check success ---
if echo "${LAST_RESPONSE}" | jq -e '.id' > /dev/null 2>&1; then
    MSG_ID=$(echo "${LAST_RESPONSE}" | jq -r '.id')
    crm_log "discord_send" "Message sent" "channel_id=${CHANNEL_ID}" "msg_id=${MSG_ID}" "msg_len=${#MESSAGE}" 2>/dev/null || true
    echo "${MSG_ID}"
else
    ERR_MSG=$(echo "${LAST_RESPONSE}" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
    crm_log_error "send_discord" "Failed to send message" "channel_id=${CHANNEL_ID}" "error=${ERR_MSG}" "msg_len=${#MESSAGE}" 2>/dev/null || true
    echo "ERROR: Failed to send message: ${ERR_MSG}" >&2
    exit 1
fi
