#!/usr/bin/env bash
# send-slack.sh — Send message to Slack via Web API
#
# Features:
#   - Auto-split at 4000 chars (Slack limit) via shared pipeline
#   - Thread support via thread_ts
#   - Rate limiter: 1 msg/s per channel (Slack Tier 3)
#   - Retry with backoff (Retry-After header for 429)
#   - Image support via files.upload API
#
# Usage:
#   bash send-slack.sh <channel_id> "<message>" [flags...]
#   bash send-slack.sh C0123456789 "Hello" --thread 1234567890.123456
#   bash send-slack.sh C0123456789 "Check this" --image /path/to/image.jpg
#
# Environment:
#   SLACK_BOT_TOKEN - Slack bot token (xoxb-xxx)
#
# Story 114.18 Phase 4

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_logger.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/_message-pipeline.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/_typing-indicator.sh" 2>/dev/null || true

# Stop typing indicator
typing_stop "slack" 2>/dev/null || true

CHANNEL_ID="${1:-}"
MESSAGE="${2:-}"
SLACK_BOT_TOKEN="${SLACK_BOT_TOKEN:-}"

# Parse flags
THREAD_TS=""
IMAGE_PATH=""

shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --thread)
            THREAD_TS="${2:-}"
            shift 2
            ;;
        --image)
            IMAGE_PATH="${2:-}"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

if [[ -z "${SLACK_BOT_TOKEN}" ]]; then
    crm_log_error "send_slack" "SLACK_BOT_TOKEN not set" 2>/dev/null || true
    echo "ERROR: SLACK_BOT_TOKEN not set" >&2
    exit 1
fi

if [[ -z "${CHANNEL_ID}" ]]; then
    crm_log_error "send_slack" "Channel ID required" 2>/dev/null || true
    echo "ERROR: Channel ID required" >&2
    exit 1
fi

# Dry-run mode
if [[ "${DRY_RUN:-0}" == "1" ]]; then
    crm_log "dry_run" "Would send slack message" "channel=${CHANNEL_ID}" "msg_len=${#MESSAGE}" 2>/dev/null || true
    echo "DRY_RUN: message not sent (${#MESSAGE} chars to ${CHANNEL_ID})"
    exit 0
fi

SLACK_API="https://slack.com/api"

# --- Retry with backoff ---
_slack_post_retry() {
    local endpoint="$1"; shift
    local max_retries=3
    local attempt=0

    while [[ ${attempt} -le ${max_retries} ]]; do
        pipeline_rate_limit "slack-${CHANNEL_ID}" 1000  # 1 msg/s per channel

        local response
        response=$(curl -s -X POST "${SLACK_API}/${endpoint}" \
            -H "Authorization: Bearer ${SLACK_BOT_TOKEN}" \
            "$@" 2>/dev/null || echo "")

        if echo "${response}" | jq -e '.ok == true' > /dev/null 2>&1; then
            echo "${response}"
            return 0
        fi

        local error
        error=$(echo "${response}" | jq -r '.error // ""' 2>/dev/null || echo "")

        if [[ "${error}" == "ratelimited" ]]; then
            local retry_after
            retry_after=$(echo "${response}" | jq -r '.headers["Retry-After"] // 5' 2>/dev/null || echo "5")
            attempt=$((attempt + 1))
            [[ ${attempt} -le ${max_retries} ]] && sleep "${retry_after}" 2>/dev/null || sleep 5
        elif [[ -z "${response}" || "${error}" == "internal_error" || "${error}" == "service_unavailable" ]]; then
            attempt=$((attempt + 1))
            if [[ ${attempt} -le ${max_retries} ]]; then
                local delay=$((2 * (1 << (attempt - 1))))
                crm_log "slack_retry" "Retrying (${attempt}/${max_retries})" "delay=${delay}s" 2>/dev/null || true
                sleep "${delay}" 2>/dev/null || sleep 2
            fi
        else
            echo "${response}"
            return 1
        fi
    done

    echo "${response:-}"
    return 1
}

# --- Send image ---
if [[ -n "${IMAGE_PATH}" ]]; then
    if [[ ! -f "${IMAGE_PATH}" ]]; then
        crm_log_error "send_slack" "Image file not found" "path=${IMAGE_PATH}" 2>/dev/null || true
        echo "ERROR: Image file not found: ${IMAGE_PATH}" >&2
        exit 1
    fi

    UPLOAD_ARGS=(-F "file=@${IMAGE_PATH}" -F "channels=${CHANNEL_ID}")
    [[ -n "${MESSAGE}" ]] && UPLOAD_ARGS+=(-F "initial_comment=${MESSAGE}")
    [[ -n "${THREAD_TS}" ]] && UPLOAD_ARGS+=(-F "thread_ts=${THREAD_TS}")

    RESPONSE=$(_slack_post_retry "files.upload" "${UPLOAD_ARGS[@]}")
    if echo "${RESPONSE}" | jq -e '.ok == true' > /dev/null 2>&1; then
        FILE_ID=$(echo "${RESPONSE}" | jq -r '.file.id // ""' 2>/dev/null)
        crm_log "slack_send" "Image uploaded" "channel=${CHANNEL_ID}" "file_id=${FILE_ID}" 2>/dev/null || true
        echo "${FILE_ID}"
    else
        ERR=$(echo "${RESPONSE}" | jq -r '.error // "Unknown"' 2>/dev/null)
        crm_log_error "send_slack" "Image upload failed" "error=${ERR}" 2>/dev/null || true
        echo "ERROR: Image upload failed: ${ERR}" >&2
        exit 1
    fi
    exit 0
fi

# --- Sanitize: Slack uses mrkdwn — strip Claude's extra escapes ---
MESSAGE=$(pipeline_strip_markdown "$MESSAGE" 2>/dev/null || echo "$MESSAGE")

# --- Slack-specific send function for pipeline ---
LAST_RESPONSE=""

_slack_send_chunk() {
    local chunk="$1" is_first="$2" is_last="$3"
    local payload
    payload=$(jq -n -c \
        --arg channel "${CHANNEL_ID}" \
        --arg text "${chunk}" \
        '{channel: $channel, text: $text, mrkdwn: true}')

    [[ -n "${THREAD_TS}" ]] && payload=$(echo "${payload}" | jq -c --arg ts "${THREAD_TS}" '. + {thread_ts: $ts}')

    LAST_RESPONSE=$(_slack_post_retry "chat.postMessage" \
        -H "Content-Type: application/json; charset=utf-8" \
        -d "${payload}")

    [[ "${is_last}" != "true" ]] && return 0
    echo "${LAST_RESPONSE}"
}

# --- Send via shared pipeline (auto-chunk at 4000, code-fence-aware) ---
pipeline_chunk_and_send "$MESSAGE" 4000 "_slack_send_chunk"

# Check success
if echo "${LAST_RESPONSE}" | jq -e '.ok == true' > /dev/null 2>&1; then
    MSG_TS=$(echo "${LAST_RESPONSE}" | jq -r '.ts // ""' 2>/dev/null)
    crm_log "slack_send" "Message sent" "channel=${CHANNEL_ID}" "ts=${MSG_TS}" "msg_len=${#MESSAGE}" 2>/dev/null || true
    echo "${MSG_TS}"
else
    ERR=$(echo "${LAST_RESPONSE}" | jq -r '.error // "Unknown"' 2>/dev/null)
    crm_log_error "send_slack" "Failed to send" "channel=${CHANNEL_ID}" "error=${ERR}" 2>/dev/null || true
    echo "ERROR: ${ERR}" >&2
    exit 1
fi
