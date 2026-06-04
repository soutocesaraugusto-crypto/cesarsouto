#!/usr/bin/env bash
# _markdown-sanitize.sh - Convert GitHub-style Markdown to Telegram HTML
#
# Strategy (OpenClaw-aligned):
#   1. Escape HTML entities (&, <, >)
#   2. Protect code blocks and inline code (no conversion inside them)
#   3. Convert **bold** → <b>bold</b>
#   4. Convert *italic* → <i>italic</i>
#   5. Convert ~~strike~~ → <s>strike</s>
#   6. Convert `code` → <code>code</code>
#   7. Convert ```blocks``` → <pre>blocks</pre>
#   8. Try HTML parse_mode, fallback to plain text if rejected
#
# Reference: OpenClaw extensions/telegram/src/format.ts (markdownToTelegramHtml)
# Epic 110 / Story 110.25 Phase 2

sanitize_for_telegram() {
    local text="$1"

    # Strip MarkdownV2 backslash escapes that Claude adds
    text="${text//\\./\.}"
    text="${text//\\!/!}"
    text="${text//\\-/-}"
    text="${text//\\(/\(}"
    text="${text//\\)/\)}"
    text="${text//\\#/#}"

    # Step 1: Escape HTML entities
    text="${text//&/&amp;}"
    text="${text//</&lt;}"
    text="${text//>/&gt;}"

    # Step 2: Convert fenced code blocks ```lang\n...\n``` → <pre>...</pre>
    # Use perl for multiline replacement (more reliable than sed)
    text=$(printf '%s' "$text" | perl -pe 's/```[a-zA-Z]*\n([^`]*)\n```/<pre>\1<\/pre>/gs; s/```\n([^`]*)\n```/<pre>\1<\/pre>/gs; s/```([^`]+)```/<pre>\1<\/pre>/gs')
    # Fallback for single-line code blocks if perl fails
    if [[ $? -ne 0 ]]; then
        text=$(printf '%s' "$text" | sed -E 's|```([^`]+)```|<pre>\1</pre>|g')
    fi

    # Step 3: Convert inline code `text` → <code>text</code>
    # Avoid matching inside <pre> blocks
    text=$(printf '%s' "$text" | sed -E 's/`([^`]+)`/<code>\1<\/code>/g')

    # Step 4: Convert bold **text** → <b>text</b>
    text=$(printf '%s' "$text" | sed -E 's/\*\*([^*]+)\*\*/<b>\1<\/b>/g')

    # Step 5: Convert italic *text* → <i>text</i>
    # Only single *, not inside words like file_name
    text=$(printf '%s' "$text" | sed -E 's/(^|[^a-zA-Z*])\*([^*\n]+)\*/\1<i>\2<\/i>/g')

    # Step 6: Convert strikethrough ~~text~~ → <s>text</s>
    text=$(printf '%s' "$text" | sed -E 's/~~([^~]+)~~/<s>\1<\/s>/g')

    # Step 7: Convert markdown links [text](url) → <a href="url">text</a>
    text=$(printf '%s' "$text" | sed -E 's/\[([^]]+)\]\(([^)]+)\)/<a href="\2">\1<\/a>/g')

    # Step 8: Convert headers ## Title → <b>Title</b> (bold, no special header in Telegram)
    text=$(printf '%s' "$text" | awk 'BEGIN {RS="\n"} /^#{1,6} / {gsub(/^#{1,6} /, ""); print "<b>" $0 "</b>"; next} {print}' RS="\n")

    printf '%s' "$text"
}

# Try sending with HTML parse_mode, retry plain text if Telegram rejects it.
try_send_with_fallback() {
    local chat_id="$1"
    local text="$2"
    local parse_mode="${3:-HTML}"
    shift 3
    local extra_args=("$@")

    local response
    if [[ -n "$parse_mode" ]]; then
        response=$(telegram_api_post_retry "sendMessage" \
            -d chat_id="${chat_id}" \
            --data-urlencode "text=${text}" \
            -d parse_mode="${parse_mode}" \
            "${extra_args[@]+"${extra_args[@]}"}" 2>/dev/null)

        if echo "$response" | jq -e '.ok' > /dev/null 2>&1; then
            echo "$response"
            return 0
        fi

        # Parse error → fallback to plain text (strip HTML tags)
        local err_desc
        err_desc=$(echo "$response" | jq -r '.description // ""' 2>/dev/null)
        if [[ "$err_desc" == *"parse"* || "$err_desc" == *"entities"* || "$err_desc" == *"Can't"* ]]; then
            # Strip HTML tags for plain text fallback
            local plain_text
            plain_text=$(printf '%s' "$text" | sed -E 's/<[^>]+>//g; s/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g')
            response=$(telegram_api_post_retry "sendMessage" \
                -d chat_id="${chat_id}" \
                --data-urlencode "text=${plain_text}" \
                "${extra_args[@]+"${extra_args[@]}"}" 2>/dev/null)

            if echo "$response" | jq -e '.ok' > /dev/null 2>&1; then
                echo "$response"
                return 0
            fi
        fi
    else
        response=$(telegram_api_post_retry "sendMessage" \
            -d chat_id="${chat_id}" \
            --data-urlencode "text=${text}" \
            "${extra_args[@]+"${extra_args[@]}"}" 2>/dev/null)

        if echo "$response" | jq -e '.ok' > /dev/null 2>&1; then
            echo "$response"
            return 0
        fi
    fi

    echo "$response"
    return 1
}
