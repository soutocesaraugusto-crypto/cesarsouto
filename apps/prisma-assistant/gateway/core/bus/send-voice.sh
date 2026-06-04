#!/usr/bin/env bash
# send-voice.sh — Send voice message via Telegram (or convert text to speech)
# Hermes pattern: auto-TTS for voice inputs, text_to_speech_tool()
#
# Usage:
#   send-voice.sh <chat_id> <audio_path>                  # Send existing audio file
#   send-voice.sh <chat_id> --tts "<text>"                 # Text-to-speech then send
#   send-voice.sh <chat_id> --tts "<text>" --voice "nova"  # TTS with specific voice
#
# Requires: say (macOS built-in) or edge-tts (pip install edge-tts) for TTS
#
# Epic 110 / Story 110.29 Phase 8

set -uo pipefail

TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
CRM_AGENT_NAME="${CRM_AGENT_NAME:-$(basename "$(pwd)")}"
ME="${CRM_AGENT_NAME}"

CHAT_ID="${1:-}"
shift 1 2>/dev/null || true

AUDIO_PATH=""
TTS_TEXT=""
TTS_VOICE="en-US-GuyNeural"  # Default edge-tts voice

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tts) TTS_TEXT="${2:-}"; shift 2 ;;
        --voice) TTS_VOICE="${2:-}"; shift 2 ;;
        *) AUDIO_PATH="$1"; shift ;;
    esac
done

# Source env for BOT_TOKEN
ENV_FILE="${TEMPLATE_ROOT}/agents/${ME}/.env"
{ set +x; } 2>/dev/null
if [[ -f "${ENV_FILE}" ]]; then
    set -a; source "${ENV_FILE}"; set +a
elif [[ -f ".env" ]]; then
    set -a; source ".env"; set +a
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_telegram-curl.sh"

# TTS: convert text to audio first
if [[ -n "${TTS_TEXT}" ]]; then
    AUDIO_PATH=$(mktemp /tmp/crm-tts-XXXXXX.ogg)

    # Strip markdown formatting for cleaner speech
    CLEAN_TEXT=$(printf '%s' "$TTS_TEXT" | sed -E 's/[*_`#\[\]()]//g' | head -c 4000)

    if command -v edge-tts &>/dev/null; then
        # Preferred: edge-tts (free, high quality, multiple voices)
        edge-tts --voice "${TTS_VOICE}" --text "${CLEAN_TEXT}" --write-media "${AUDIO_PATH}" 2>/dev/null
    elif command -v say &>/dev/null; then
        # Fallback: macOS say command (lower quality, single voice)
        AIFF_TMP=$(mktemp /tmp/crm-tts-XXXXXX.aiff)
        say -o "${AIFF_TMP}" "${CLEAN_TEXT}" 2>/dev/null
        # Convert to OGG if ffmpeg available
        if command -v ffmpeg &>/dev/null; then
            ffmpeg -i "${AIFF_TMP}" -c:a libopus "${AUDIO_PATH}" -y 2>/dev/null
        else
            AUDIO_PATH="${AIFF_TMP}"
        fi
    else
        echo "ERROR: No TTS engine available (install edge-tts: pip install edge-tts)" >&2
        rm -f "${AUDIO_PATH}"
        exit 1
    fi

    if [[ ! -f "${AUDIO_PATH}" || ! -s "${AUDIO_PATH}" ]]; then
        echo "ERROR: TTS conversion failed" >&2
        rm -f "${AUDIO_PATH}"
        exit 1
    fi
fi

if [[ -z "${AUDIO_PATH}" || ! -f "${AUDIO_PATH}" ]]; then
    echo "ERROR: No audio file to send" >&2
    exit 1
fi

# Send voice message via Telegram API
RESPONSE=$(telegram_api_post_retry "sendVoice" \
    -F "chat_id=${CHAT_ID}" \
    -F "voice=@${AUDIO_PATH}")

# Cleanup TTS temp files
[[ -n "${TTS_TEXT}" ]] && rm -f "${AUDIO_PATH}" 2>/dev/null || true

if echo "${RESPONSE}" | jq -e '.ok' > /dev/null 2>&1; then
    echo "${RESPONSE}" | jq -r '.result.message_id'
else
    echo "ERROR: Failed to send voice message" >&2
    echo "${RESPONSE}" | jq -r '.description // "Unknown error"' >&2
    exit 1
fi
