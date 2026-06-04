#!/usr/bin/env bash
# check-telegram.sh - Check for new Telegram messages for this agent's bot
# Usage: check-telegram.sh
# Requires: CRM_AGENT_NAME, BOT_TOKEN from environment (.env)

set -euo pipefail

CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote}"
TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
# Always detect from cwd
CRM_AGENT_NAME="${CRM_AGENT_NAME:-$(basename "$(pwd)")}"
ME="${CRM_AGENT_NAME}"

# Always source .env to get BOT_TOKEN
ENV_FILE="${TEMPLATE_ROOT}/agents/${ME}/.env"
{ set +x; } 2>/dev/null
if [[ -f "${ENV_FILE}" ]]; then
    set -a; source "${ENV_FILE}"; set +a
elif [[ -f ".env" ]]; then
    set -a; source ".env"; set +a
fi

if [[ -z "${BOT_TOKEN:-}" ]]; then
    exit 0  # No bot token configured, skip silently
fi

# Source shared Telegram helper (keeps token out of traces)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_telegram-curl.sh"

# ALLOWED_USER is required - reject all messages if not configured
ALLOWED_USER="${ALLOWED_USER:-}"
if [[ -z "${ALLOWED_USER}" ]]; then
    exit 0
fi
OFFSET_FILE="${CRM_ROOT}/state/.telegram-offset-${ME}"

# Read last offset
OFFSET=$(cat "${OFFSET_FILE}" 2>/dev/null || echo "0")

# Poll Telegram
RESPONSE=$(telegram_api_get "getUpdates?offset=${OFFSET}&timeout=1" 2>/dev/null || echo '{"ok":false}')

# Check if response is valid
if ! echo "${RESPONSE}" | jq -e '.ok' > /dev/null 2>&1; then
    exit 0
fi

_FC_LOG="${CRM_ROOT}/logs/${ME}/fast-checker.log"
_TOTAL_DEBUG=$(echo "${RESPONSE}" | jq '.result | length' 2>/dev/null || echo "?")
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [check-telegram/${ME}] DEBUG check-telegram: offset=${OFFSET} total=${_TOTAL_DEBUG}" >> "${_FC_LOG}" 2>/dev/null || true

# Source logger for rejected message tracking (Story 110.26)
source "${SCRIPT_DIR}/_logger.sh"

# Filter messages — ALLOWED_USER and ALLOWED_USER_2 pass
ALLOWED_USER_2="${ALLOWED_USER_2:-}"
MESSAGES=$(echo "${RESPONSE}" | jq --arg uid "${ALLOWED_USER}" --arg uid2 "${ALLOWED_USER_2}" \
    '[.result[] | select(
        (.message.from.id == ($uid | tonumber) or .callback_query.from.id == ($uid | tonumber)) or
        ($uid2 != "" and (.message.from.id == ($uid2 | tonumber) or .callback_query.from.id == ($uid2 | tonumber)))
    )]')

# Log rejected messages (from unauthorized users) for security audit
TOTAL_COUNT=$(echo "${RESPONSE}" | jq '.result | length')
MSG_COUNT=$(echo "${MESSAGES}" | jq 'length')
REJECTED=$((TOTAL_COUNT - MSG_COUNT))
if [[ ${REJECTED} -gt 0 ]]; then
    crm_log "auth_rejected" "Rejected ${REJECTED} message(s) from non-ALLOWED_USER" "allowed_user=${ALLOWED_USER}" "rejected_count=${REJECTED}"
fi

IMAGE_DIR="${TELEGRAM_IMAGE_DIR:-${TEMPLATE_ROOT}/agents/${ME}/telegram-images}"
mkdir -p "${IMAGE_DIR}"

if [[ "${MSG_COUNT}" -gt 0 ]]; then
    # Output regular text messages
    echo "${MESSAGES}" | jq -c '.[] | select(.message and .message.text) | {
        chat_id: .message.chat.id,
        from: .message.from.first_name,
        text: .message.text,
        date: .message.date,
        type: "message"
    }'

    # Handle photo messages: download largest size and output with local path
    while IFS= read -r photo_msg; do
        CHAT_ID_VAL=$(echo "${photo_msg}" | jq -r '.chat_id')
        FROM_VAL=$(echo "${photo_msg}" | jq -r '.from')
        DATE_VAL=$(echo "${photo_msg}" | jq -r '.date')
        CAPTION_VAL=$(echo "${photo_msg}" | jq -r '.caption // ""')
        FILE_ID=$(echo "${photo_msg}" | jq -r '.file_id')

        FILE_RESPONSE=$(telegram_api_get "getFile?file_id=${FILE_ID}" 2>/dev/null || echo '{"ok":false}')
        FILE_PATH=$(echo "${FILE_RESPONSE}" | jq -r '.result.file_path // empty')

        if [[ -n "${FILE_PATH}" ]]; then
            LOCAL_FILE="${IMAGE_DIR}/${DATE_VAL}.jpg"
            telegram_file_download "${FILE_PATH}" "${LOCAL_FILE}" 2>/dev/null || true

            jq -nc \
                --arg chat_id "${CHAT_ID_VAL}" \
                --arg from "${FROM_VAL}" \
                --arg caption "${CAPTION_VAL}" \
                --argjson date "${DATE_VAL}" \
                --arg image_path "${LOCAL_FILE}" \
                '{chat_id: ($chat_id | tonumber), from: $from, text: $caption, image_path: $image_path, date: $date, type: "photo"}'
        fi
    done < <(echo "${MESSAGES}" | jq -c '.[] | select(.message.photo) | {
        chat_id: .message.chat.id,
        from: .message.from.first_name,
        caption: (.message.caption // ""),
        date: .message.date,
        file_id: (.message.photo | last | .file_id)
    }')

    # Handle voice messages: download, transcribe via Groq Whisper, output as text
    GROQ_KEY=$(grep -E '^GROQ_KEY=' "${HOME}/omni-whatsbot/.env" 2>/dev/null | cut -d= -f2-)
    while IFS= read -r voice_msg; do
        CHAT_ID_VAL=$(echo "${voice_msg}" | jq -r '.chat_id')
        FROM_VAL=$(echo "${voice_msg}" | jq -r '.from')
        DATE_VAL=$(echo "${voice_msg}" | jq -r '.date')
        FILE_ID=$(echo "${voice_msg}" | jq -r '.file_id')

        FILE_RESPONSE=$(telegram_api_get "getFile?file_id=${FILE_ID}" 2>/dev/null || echo '{"ok":false}')
        FILE_PATH=$(echo "${FILE_RESPONSE}" | jq -r '.result.file_path // empty')

        if [[ -n "${FILE_PATH}" && -n "${GROQ_KEY}" ]]; then
            OGG_FILE="${IMAGE_DIR}/voice-${DATE_VAL}.ogg"
            telegram_file_download "${FILE_PATH}" "${OGG_FILE}" 2>/dev/null || true
            TRANSCRIPT=""
            if [[ -s "${OGG_FILE}" ]]; then
                TRANSCRIPT=$(curl -s -X POST "https://api.groq.com/openai/v1/audio/transcriptions" \
                    -H "Authorization: Bearer ${GROQ_KEY}" \
                    -F "file=@${OGG_FILE};type=audio/ogg" \
                    -F "model=whisper-large-v3" \
                    -F "language=pt" 2>/dev/null | jq -r '.text // empty')
            fi
            rm -f "${OGG_FILE}" 2>/dev/null || true
            if [[ -n "${TRANSCRIPT}" ]]; then
                jq -nc \
                    --arg chat_id "${CHAT_ID_VAL}" \
                    --arg from "${FROM_VAL}" \
                    --arg text "[áudio recebido] ${TRANSCRIPT}" \
                    --argjson date "${DATE_VAL}" \
                    '{chat_id: ($chat_id | tonumber), from: $from, text: $text, date: $date, type: "message"}'
            fi
        fi
    done < <(echo "${MESSAGES}" | jq -c '.[] | select(.message.voice) | {
        chat_id: .message.chat.id,
        from: .message.from.first_name,
        date: .message.date,
        file_id: .message.voice.file_id
    }')

    # Handle document messages: download to bridge files dir, output type "document"
    FILES_DIR="${TELEGRAM_FILES_DIR:-${TEMPLATE_ROOT}/agents/${ME}/telegram-files}"
    mkdir -p "${FILES_DIR}"
    while IFS= read -r doc_msg; do
        CHAT_ID_VAL=$(echo "${doc_msg}" | jq -r '.chat_id')
        FROM_VAL=$(echo "${doc_msg}" | jq -r '.from')
        DATE_VAL=$(echo "${doc_msg}" | jq -r '.date')
        CAPTION_VAL=$(echo "${doc_msg}" | jq -r '.caption // ""')
        FILE_ID=$(echo "${doc_msg}" | jq -r '.file_id')
        FILE_NAME=$(echo "${doc_msg}" | jq -r '.file_name // "arquivo"')

        FILE_RESPONSE=$(telegram_api_get "getFile?file_id=${FILE_ID}" 2>/dev/null || echo '{"ok":false}')
        FILE_PATH=$(echo "${FILE_RESPONSE}" | jq -r '.result.file_path // empty')
        if [[ -n "${FILE_PATH}" ]]; then
            SAFE_NAME=$(echo "${FILE_NAME}" | tr -cd '[:alnum:]._-')
            [[ -z "${SAFE_NAME}" ]] && SAFE_NAME="arquivo"
            LOCAL_FILE="${FILES_DIR}/${DATE_VAL}_${SAFE_NAME}"
            telegram_file_download "${FILE_PATH}" "${LOCAL_FILE}" 2>/dev/null || true
            if [[ -s "${LOCAL_FILE}" ]]; then
                jq -nc \
                    --arg chat_id "${CHAT_ID_VAL}" \
                    --arg from "${FROM_VAL}" \
                    --arg caption "${CAPTION_VAL}" \
                    --arg doc "${LOCAL_FILE}" \
                    --arg fname "${FILE_NAME}" \
                    --argjson date "${DATE_VAL}" \
                    '{chat_id: ($chat_id | tonumber), from: $from, text: $caption, document_path: $doc, file_name: $fname, date: $date, type: "document"}'
            fi
        fi
    done < <(echo "${MESSAGES}" | jq -c '.[] | select(.message.document) | {
        chat_id: .message.chat.id,
        from: .message.from.first_name,
        caption: (.message.caption // ""),
        date: .message.date,
        file_id: .message.document.file_id,
        file_name: (.message.document.file_name // "arquivo")
    }')

    # Output callback queries (inline button presses)
    echo "${MESSAGES}" | jq -c '.[] | select(.callback_query) | {
        chat_id: .callback_query.message.chat.id,
        from: .callback_query.from.first_name,
        callback_data: .callback_query.data,
        callback_query_id: .callback_query.id,
        message_id: .callback_query.message.message_id,
        date: .callback_query.message.date,
        type: "callback"
    }'
fi

# Update offset only when there are actual results — jq returns 1 on empty
# arrays (.result[-1] = null, null+1 = 1) which would silently regress offset
if [[ "${TOTAL_COUNT}" -gt 0 ]]; then
    NEW_OFFSET=$(echo "${RESPONSE}" | jq '.result[-1].update_id + 1')
    if [[ -n "${NEW_OFFSET}" && "${NEW_OFFSET}" != "null" ]]; then
        echo "${NEW_OFFSET}" > "${OFFSET_FILE}"
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [check-telegram/${ME}] DEBUG offset updated: ${OFFSET} -> ${NEW_OFFSET} (msg_count=${MSG_COUNT})" >> "${_FC_LOG}" 2>/dev/null || true
    fi
fi
