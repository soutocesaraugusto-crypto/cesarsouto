#!/usr/bin/env bash
# _message-pipeline.sh — Shared outbound message pipeline for all channels
#
# Provides reusable functions that every send-*.sh adapter uses:
#   - Markdown → HTML sanitization (for channels that support it)
#   - Auto-chunking at configurable char limits (code-fence-aware)
#   - Rate limiting with configurable interval
#   - Delivery queue integration (write-ahead enqueue + ack/nack)
#   - Typing indicator loop (start/stop)
#   - Retry with exponential backoff
#
# Usage:
#   source "${SCRIPT_DIR}/_message-pipeline.sh"
#   pipeline_chunk_and_send "$MESSAGE" "$CHAR_LIMIT" "_my_send_fn"
#
# Each adapter only needs to implement:
#   _my_send_fn "$chunk" "$is_first" "$is_last"  → platform-specific HTTP call
#
# Reference: Story 114.19 Phase 3 (Outbound Pipeline Formalization)
# Pattern: OpenClaw deliver.ts (8-stage pipeline)

# Depends on: _logger.sh (optional, graceful if missing)

# ============================================================
# Stage 1: Text sanitization (Markdown → target format)
# ============================================================

# Convert GitHub-style Markdown to Telegram HTML.
# Other channels can call pipeline_strip_markdown for plain text.
pipeline_sanitize_html() {
    local text="$1"

    # Strip MarkdownV2 backslash escapes Claude adds
    text="${text//\\./\.}"
    text="${text//\\!/!}"
    text="${text//\\-/-}"
    text="${text//\\(/\(}"
    text="${text//\\)/\)}"
    text="${text//\\#/#}"

    # Escape HTML entities
    text="${text//&/&amp;}"
    text="${text//</&lt;}"
    text="${text//>/&gt;}"

    # Code blocks ```lang...``` → <pre>...</pre>
    if command -v perl > /dev/null 2>&1; then
        text=$(printf '%s' "$text" | perl -0pe 's/```[a-zA-Z]*\n(.*?)\n```/<pre>\1<\/pre>/gs' 2>/dev/null) || true
    fi
    # Inline triple backtick fallback
    text=$(printf '%s' "$text" | sed -E 's/```([^`]+)```/<pre>\1<\/pre>/g')

    # Inline code `text` → <code>text</code>
    text=$(printf '%s' "$text" | sed -E 's/`([^`]+)`/<code>\1<\/code>/g')

    # Bold **text** → <b>text</b>
    text=$(printf '%s' "$text" | sed -E 's/\*\*([^*]+)\*\*/<b>\1<\/b>/g')

    # Italic *text* → <i>text</i> (not inside words)
    text=$(printf '%s' "$text" | sed -E 's/(^|[^a-zA-Z*])\*([^*\n]+)\*/\1<i>\2<\/i>/g')

    # Strikethrough ~~text~~ → <s>text</s>
    text=$(printf '%s' "$text" | sed -E 's/~~([^~]+)~~/<s>\1<\/s>/g')

    # Links [text](url) → <a href="url">text</a>
    text=$(printf '%s' "$text" | sed -E 's/\[([^]]+)\]\(([^)]+)\)/<a href="\2">\1<\/a>/g')

    # Headers ## Title → <b>Title</b>
    if command -v awk > /dev/null 2>&1; then
        text=$(printf '%s' "$text" | awk 'BEGIN {RS="\n"} /^#{1,6} / {gsub(/^#{1,6} /, ""); print "<b>" $0 "</b>"; next} {print}' RS="\n")
    fi

    printf '%s' "$text"
}

# Strip all Markdown formatting to plain text.
# Use for channels that don't support any formatting.
pipeline_strip_markdown() {
    local text="$1"
    # Remove backslash escapes
    text=$(printf '%s' "$text" | sed -E 's/\\([^\\])/\1/g')
    # Remove **bold**, *italic*, ~~strike~~, `code`
    text=$(printf '%s' "$text" | sed -E 's/\*\*([^*]+)\*\*/\1/g; s/\*([^*]+)\*/\1/g; s/~~([^~]+)~~/\1/g; s/`([^`]+)`/\1/g')
    # Remove ```code blocks```
    text=$(printf '%s' "$text" | sed -E 's/```[a-zA-Z]*//g; s/```//g')
    # Remove [text](url) → text (url)
    text=$(printf '%s' "$text" | sed -E 's/\[([^]]+)\]\(([^)]+)\)/\1 (\2)/g')
    # Remove ## headers
    text=$(printf '%s' "$text" | sed -E 's/^#{1,6} //g')
    printf '%s' "$text"
}

# ============================================================
# Stage 2: Auto-chunking (code-fence-aware)
# ============================================================

# Split text into chunks respecting char limit and code fences.
# Calls the provided send function for each chunk.
#
# Usage: pipeline_chunk_and_send "$MESSAGE" 4096 "_send_fn"
#   _send_fn receives: chunk, is_first (true/false), is_last (true/false)
pipeline_chunk_and_send() {
    local message="$1"
    local max_chars="${2:-4096}"
    local send_fn="$3"
    local msg_len=${#message}

    if [[ ${msg_len} -le ${max_chars} ]]; then
        ${send_fn} "${message}" "true" "true"
        return $?
    fi

    local remaining="${message}"
    local in_fence=false
    local fence_lang=""
    local is_first=true
    local last_response=""

    while [[ ${#remaining} -gt ${max_chars} ]]; do
        local chunk="${remaining:0:${max_chars}}"
        # Find best split point: last newline within limit
        local split_at
        split_at=$(printf '%s' "${chunk}" | grep -aob $'\n' | tail -1 | cut -d: -f1 2>/dev/null || echo "")
        if [[ -n "${split_at}" && "${split_at}" -gt 100 ]]; then
            chunk="${remaining:0:${split_at}}"
            remaining="${remaining:$((split_at + 1))}"
        else
            chunk="${remaining:0:${max_chars}}"
            remaining="${remaining:${max_chars}}"
        fi

        # Track code fence state
        local fence_count
        fence_count=$(printf '%s' "${chunk}" | grep -c '^\`\`\`' 2>/dev/null || echo "0")
        if [[ $((fence_count % 2)) -ne 0 ]]; then
            if $in_fence; then
                in_fence=false
            else
                fence_lang=$(printf '%s' "${chunk}" | grep -oE '^\`\`\`[a-zA-Z]*' | tail -1 | sed 's/^```//' 2>/dev/null || echo "")
                in_fence=true
            fi
        fi

        # Close/reopen code fence across chunks
        if $in_fence; then
            chunk="${chunk}"$'\n```'
            remaining="\`\`\`${fence_lang}"$'\n'"${remaining}"
        fi

        ${send_fn} "${chunk}" "${is_first}" "false"
        is_first=false
    done

    # Last chunk
    ${send_fn} "${remaining}" "${is_first}" "true"
}

# ============================================================
# Stage 3: Rate limiting (configurable interval)
# ============================================================

# Generic rate limiter. Call before each send.
# Usage: pipeline_rate_limit "channel_name" 100  (100ms minimum between sends)
pipeline_rate_limit() {
    local channel="${1:-default}"
    local min_interval_ms="${2:-100}"
    local rate_file="/tmp/crm-rate-${channel}.txt"

    if [[ -f "${rate_file}" ]]; then
        local last_send now_ms delta
        last_send=$(cat "${rate_file}" 2>/dev/null || echo "0")
        now_ms=$(_pipeline_now_ms)
        delta=$((now_ms - last_send))
        if [[ ${delta} -lt ${min_interval_ms} ]]; then
            local wait_ms=$((min_interval_ms - delta))
            local wait_s
            wait_s=$(printf "0.%03d" "${wait_ms}")
            sleep "${wait_s}" 2>/dev/null || sleep 0.1
        fi
    fi
    _pipeline_now_ms > "${rate_file}" 2>/dev/null || true
}

_pipeline_now_ms() {
    perl -e 'use Time::HiRes qw(time); printf "%d\n", time()*1000' 2>/dev/null \
        || python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null \
        || echo "$(($(date +%s) * 1000))"
}

# ============================================================
# Stage 4: Retry with exponential backoff
# ============================================================

# Generic retry wrapper.
# Usage: pipeline_retry 3 "_attempt_fn" arg1 arg2
#   _attempt_fn must return 0 on success, 1 on permanent error, 2 on retryable error
pipeline_retry() {
    local max_retries="${1:-3}"
    local attempt_fn="$2"
    shift 2
    local attempt=0

    while [[ ${attempt} -le ${max_retries} ]]; do
        ${attempt_fn} "$@"
        local rc=$?
        if [[ ${rc} -eq 0 ]]; then
            return 0
        elif [[ ${rc} -eq 1 ]]; then
            return 1  # Permanent error
        fi
        # rc=2 → retryable
        attempt=$((attempt + 1))
        if [[ ${attempt} -le ${max_retries} ]]; then
            local delay=$((2 * (1 << (attempt - 1))))
            crm_log "pipeline_retry" "Retrying (${attempt}/${max_retries})" "delay=${delay}s" 2>/dev/null || true
            sleep "${delay}" 2>/dev/null || sleep 2
        fi
    done
    return 1
}

# ============================================================
# Stage 5: Typing indicator (start/stop)
# ============================================================

# Start a background typing loop. Returns PID file path.
# Usage: pipeline_start_typing "telegram" "BOT_TOKEN_VALUE" "CHAT_ID_VALUE"
# The typing_fn is channel-specific (curl to the right API).
pipeline_start_typing() {
    local channel="$1"
    local agent="${CRM_AGENT_NAME:-prisma}"
    local crm_root="${CRM_ROOT:-${HOME}/.claude-remote/default}"
    local pid_file="${crm_root}/state/${agent}/.typing-loop-${channel}.pid"

    mkdir -p "${crm_root}/state/${agent}" 2>/dev/null || true

    # Kill existing
    if [[ -f "${pid_file}" ]]; then
        kill "$(cat "${pid_file}")" 2>/dev/null || true
        rm -f "${pid_file}"
    fi

    # Caller must set TYPING_CMD before calling
    if [[ -n "${TYPING_CMD:-}" ]]; then
        bash -c "while true; do ${TYPING_CMD} > /dev/null 2>&1; sleep 2; done" &
        echo $! > "${pid_file}"
        disown $! 2>/dev/null || true
    fi
}

# Stop the typing loop for a channel.
pipeline_stop_typing() {
    local channel="$1"
    local agent="${CRM_AGENT_NAME:-prisma}"
    local crm_root="${CRM_ROOT:-${HOME}/.claude-remote/default}"
    local pid_file="${crm_root}/state/${agent}/.typing-loop-${channel}.pid"

    if [[ -f "${pid_file}" ]]; then
        kill "$(cat "${pid_file}")" 2>/dev/null || true
        rm -f "${pid_file}"
    fi
}
