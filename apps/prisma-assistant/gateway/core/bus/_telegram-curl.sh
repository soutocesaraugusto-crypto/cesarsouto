#!/usr/bin/env bash
# _telegram-curl.sh - Shared helper for Telegram API calls
# Keeps BOT_TOKEN out of shell traces (set +x) while preserving stderr for errors.
# Source this file, then call the functions. Requires BOT_TOKEN in environment.
#
# Usage:
#   source "$(dirname "$0")/_telegram-curl.sh"
#   RESPONSE=$(telegram_api_post "sendMessage" -d chat_id=123 --data-urlencode "text=hello")
#   RESPONSE=$(telegram_api_get "getUpdates?offset=0&timeout=5")
#   telegram_file_download "photos/file_123.jpg" /tmp/photo.jpg

# POST to a Telegram Bot API method
# Usage: telegram_api_post <method> [curl_args...]
telegram_api_post() {
    local method="$1"; shift
    (
        set +x  # prevent trace from leaking token in URL
        curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/${method}" "$@"
    )
}

# GET from a Telegram Bot API endpoint
# Usage: telegram_api_get <path_after_bot_token> [curl_args...]
telegram_api_get() {
    local path="$1"; shift
    (
        set +x
        curl -s "https://api.telegram.org/bot${BOT_TOKEN}/${path}" "$@"
    )
}

# --- Retry wrapper with exponential backoff (Story 110.28 Phase 1) ---
# Hermes pattern: _send_with_retry() with transient error detection
# Retries up to MAX_RETRIES times with exponential backoff: 2s, 4s, 8s
# Transient errors: network timeouts, 429 rate limit, 5xx server errors
# Permanent errors: 400 bad request, 401 unauthorized, 403 forbidden → no retry
#
# Usage: telegram_api_post_retry <method> [curl_args...]
# Returns: curl output (JSON). Sets _TG_RETRY_COUNT to number of retries used.
_TG_RETRY_COUNT=0

_is_transient_error() {
    local response="$1"
    local http_desc
    http_desc=$(echo "$response" | jq -r '.description // ""' 2>/dev/null || echo "")
    local error_code
    error_code=$(echo "$response" | jq -r '.error_code // 0' 2>/dev/null || echo "0")

    # Transient: rate limit, server errors, network issues
    [[ "${error_code}" -eq 429 ]] && return 0  # Too Many Requests
    [[ "${error_code}" -ge 500 ]] && return 0  # Server errors
    [[ -z "$response" ]] && return 0           # Empty response = network failure
    [[ "$response" == *"timed out"* ]] && return 0
    [[ "$response" == *"connection"* ]] && return 0
    [[ "$response" == *"ETIMEDOUT"* ]] && return 0

    # Permanent: bad request, auth errors → don't retry
    return 1
}

telegram_api_post_retry() {
    local method="$1"; shift
    local max_retries="${TG_MAX_RETRIES:-3}"
    local base_delay=2
    local attempt=0
    local response=""
    _TG_RETRY_COUNT=0

    while [[ ${attempt} -le ${max_retries} ]]; do
        response=$(telegram_api_post "${method}" "$@" 2>/dev/null || echo "")

        # Success
        if echo "$response" | jq -e '.ok' > /dev/null 2>&1; then
            echo "$response"
            return 0
        fi

        # Check if error is retryable
        if ! _is_transient_error "$response"; then
            # Permanent error — return immediately
            echo "$response"
            return 1
        fi

        attempt=$((attempt + 1))
        _TG_RETRY_COUNT=${attempt}

        if [[ ${attempt} -le ${max_retries} ]]; then
            local delay=$((base_delay * (1 << (attempt - 1))))  # Exponential: 2, 4, 8
            # Extract Retry-After header from 429 responses
            local retry_after
            retry_after=$(echo "$response" | jq -r '.parameters.retry_after // 0' 2>/dev/null || echo "0")
            [[ "${retry_after}" -gt 0 && "${retry_after}" -lt 60 ]] && delay=${retry_after}

            sleep "${delay}" 2>/dev/null || sleep 2
        fi
    done

    # All retries exhausted
    echo "$response"
    return 1
}

# Download a file from Telegram's file storage
# Usage: telegram_file_download <file_path> <output_path>
telegram_file_download() {
    local file_path="$1"
    local output="$2"
    (
        set +x
        curl -s "https://api.telegram.org/file/bot${BOT_TOKEN}/${file_path}" -o "${output}"
    )
}
