# Adapter Creation Guide — AIOX Message Gateway

## Overview

This guide explains how to add a new channel adapter to the AIOX Message Gateway. An adapter connects the gateway to a messaging platform (Telegram, Discord, WhatsApp, Slack, etc.).

The gateway uses an **adapter pattern**: each channel implements a standard set of scripts, and the core pipeline handles message routing, chunking, formatting, retry, and delivery queuing.

## Architecture

```
Message Flow (Inbound):
  Platform API → adapters/{channel}/start.sh (polling/webhook)
               → core/bus/check-{channel}.sh (normalize to JSON)
               → channel-inbox/{agent}/*.json
               → core/scripts/fast-checker.sh (reads inbox, injects into Claude)

Message Flow (Outbound):
  Claude Code → send-channel.sh {platform} {recipient} "{message}"
             → core/bus/send-{channel}.sh (format, chunk, send)
             → Platform API
```

## Required Files

Every adapter MUST implement these files:

### 1. Adapter Lifecycle Scripts

| File | Purpose | Exit Codes |
|------|---------|------------|
| `adapters/{channel}/start.sh` | Start polling/webhook loop | 0=started |
| `adapters/{channel}/stop.sh` | Graceful shutdown | 0=stopped |
| `adapters/{channel}/health.sh` | Health check | 0=healthy, 1=degraded, 2=dead |

### 2. Bus Scripts

| File | Purpose |
|------|---------|
| `core/bus/check-{channel}.sh` | Poll for new messages, output normalized JSON |
| `core/bus/send-{channel}.sh` | Send message to platform |
| `core/bus/hook-permission-{channel}.sh` | Handle tool approval prompts |

### 3. Optional Bus Scripts

| File | Purpose |
|------|---------|
| `core/bus/hook-ask-{channel}.sh` | Handle agent questions to user |
| `core/bus/hook-planmode-{channel}.sh` | Handle plan mode approval |
| `core/bus/send-{channel}-photo.sh` | Send photos/images (if not in main send script) |

## Message Schema

### Inbound (check-{channel}.sh output)

Every message written to `channel-inbox/` MUST follow this JSON schema:

```json
{
  "_source": "adapter",
  "_type": "message",
  "_timestamp": "2026-04-06T12:00:00Z",
  "_message_id": "123456",
  "platform": "telegram",
  "chat_id": "613473279",
  "from": "Alan",
  "user_id": "613473279",
  "text": "Hello world",
  "date": 1712404800,
  "type": "message"
}
```

**Required fields:**
- `platform` — channel name (telegram, discord, web, whatsapp, slack)
- `chat_id` — platform-specific chat/channel ID (string)
- `from` — display name of sender
- `text` — message text content
- `type` — "message", "photo", "callback"

**Optional fields:**
- `_source` — "adapter" or "webhook"
- `_type` — normalized type
- `_timestamp` — ISO 8601
- `_message_id` — platform message ID (for replies, edits, reactions)
- `user_id` — unique user identifier
- `image_path` — local path for downloaded photos
- `callback_data` — for button callbacks
- `callback_query_id` — for callback acknowledgment

### Outbound (send-{channel}.sh input)

```bash
bash send-{channel}.sh <recipient> "<message>" [flags...]
```

**Standard flags all adapters should support:**
- `--image /path/to/file` — send with image
- `--topic <name>` — route to topic/thread (if platform supports)

**Platform-specific flags (optional):**
- `--progressive` — edit-in-place updates (Telegram, Discord)
- `--edit <msg_id>` — edit existing message
- `--reply-to <msg_id>` — reply to specific message
- `--thread <thread_id>` — post in thread
- `--embed-title` — rich embed (Discord)
- `--keyboard <json>` — inline buttons (Telegram, Discord)

## Shared Pipeline Modules

Source these in your `send-{channel}.sh` to avoid reimplementing common logic:

### `_message-pipeline.sh`

```bash
source "${SCRIPT_DIR}/_message-pipeline.sh"

# Sanitize markdown → HTML (for platforms with HTML support)
MESSAGE=$(pipeline_sanitize_html "$MESSAGE")

# Or strip markdown entirely (for plaintext-only platforms)
MESSAGE=$(pipeline_strip_markdown "$MESSAGE")

# Auto-chunk and send (code-fence-aware splitting)
pipeline_chunk_and_send "$MESSAGE" 4096 "_my_send_fn"
# _my_send_fn receives: chunk, is_first, is_last
```

### `_typing-indicator.sh`

```bash
source "${SCRIPT_DIR}/_typing-indicator.sh"

# Start typing (call when message received)
typing_start "telegram" "${BOT_TOKEN}" "${CHAT_ID}"

# Stop typing (call when response sent)
typing_stop "telegram"
```

### `_logger.sh`

```bash
source "${SCRIPT_DIR}/_logger.sh"

crm_log "event_name" "description" "key=value" "key2=value2"
crm_log_error "event_name" "error description" "key=value"
```

## Channel Char Limits

| Channel | Limit | Notes |
|---------|-------|-------|
| Telegram | 4096 | Text messages. Captions: 1024 |
| Discord | 2000 | Regular messages. Embeds: 4096 description |
| Slack | 4000 | chat.postMessage. Block Kit: 3000 per block |
| WhatsApp | 4096 | Via Baileys bridge |
| Web | No limit | HTTP response, chunking optional |

## Step-by-Step: Adding a New Channel

### Step 1: Create Adapter Directory

```bash
mkdir -p gateway/adapters/{channel}
```

### Step 2: Implement `start.sh`

This script runs as a long-lived background process. It polls the platform API and writes messages to `channel-inbox/`.

```bash
#!/usr/bin/env bash
# start.sh — {Channel} polling adapter
# Lifecycle: started by agent-wrapper.sh when adapter_mode=true.
# Writes normalized messages to channel-inbox/{agent}/*.json

set -uo pipefail

AGENT="${1:-prisma}"
TEMPLATE_ROOT="${2:-$(cd "$(dirname "$0")/../.." && pwd)}"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${HOME}/.claude-remote/${CRM_INSTANCE_ID}"
INBOX_DIR="${CRM_ROOT}/channel-inbox/${AGENT}"
mkdir -p "${INBOX_DIR}"

# Source your check script
BUS_DIR="${TEMPLATE_ROOT}/core/bus"

while true; do
    OUTPUT=$(bash "${BUS_DIR}/check-{channel}.sh" 2>/dev/null || echo "")
    if [[ -n "$OUTPUT" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            # Write each message as a separate JSON file
            FILENAME="${INBOX_DIR}/$(date +%s%N)-{channel}.json"
            printf '%s\n' "$line" > "${FILENAME}"
        done <<< "$OUTPUT"
    fi
    sleep 1  # Poll interval
done
```

### Step 3: Implement `check-{channel}.sh`

Polls the platform API once and outputs normalized JSON lines.

```bash
#!/usr/bin/env bash
# check-{channel}.sh — Poll {Channel} for new messages
# Output: one JSON object per line (adapter-message schema)

set -uo pipefail

# Your API call here
RESPONSE=$(curl -s "https://api.{channel}.com/getMessages" ...)

# Normalize to standard schema
echo "${RESPONSE}" | jq -c '.messages[] | {
    platform: "{channel}",
    chat_id: (.chat.id | tostring),
    from: .sender.name,
    user_id: (.sender.id | tostring),
    text: .text,
    _message_id: (.id | tostring),
    _timestamp: (now | todate),
    type: "message"
}'
```

### Step 4: Implement `send-{channel}.sh`

Uses shared pipeline modules for chunking, rate limiting, and retry.

```bash
#!/usr/bin/env bash
# send-{channel}.sh — Send message to {Channel}
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_logger.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/_message-pipeline.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/_typing-indicator.sh" 2>/dev/null || true

RECIPIENT="${1:-}"
MESSAGE="${2:-}"
# Parse your flags here...

# Stop typing indicator (started by fast-checker on message receive)
typing_stop "{channel}"

# Sanitize
MESSAGE=$(pipeline_sanitize_html "$MESSAGE")
# Or: MESSAGE=$(pipeline_strip_markdown "$MESSAGE")

# Platform-specific send function
_send_fn() {
    local chunk="$1" is_first="$2" is_last="$3"
    pipeline_rate_limit "{channel}" 100  # 100ms between sends

    local response
    response=$(curl -s -X POST "https://api.{channel}.com/sendMessage" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$(jq -n -c --arg to "${RECIPIENT}" --arg text "${chunk}" \
            '{recipient: $to, message: $text}')")

    if echo "${response}" | jq -e '.ok' > /dev/null 2>&1; then
        return 0
    fi
    return 2  # Retryable error
}

# Chunk and send with retry
pipeline_chunk_and_send "$MESSAGE" 4096 "_send_fn"
```

### Step 5: Implement `health.sh`

```bash
#!/usr/bin/env bash
# health.sh — {Channel} adapter health check
# Exit codes: 0=healthy, 1=degraded, 2=dead

HEALTH=$(curl -s --max-time 5 "https://api.{channel}.com/health" 2>/dev/null)
if [[ -z "$HEALTH" ]]; then
    exit 2  # dead — can't reach API
fi
# Your health logic here
exit 0  # healthy
```

### Step 6: Implement `stop.sh`

```bash
#!/usr/bin/env bash
# stop.sh — Graceful shutdown of {Channel} adapter
source "$(cd "$(dirname "$0")/../../core/bus" && pwd)/_typing-indicator.sh" 2>/dev/null || true
typing_stop "{channel}"
# Kill any adapter-specific processes
exit 0
```

### Step 7: Implement `hook-permission-{channel}.sh`

This script sends tool approval prompts to the user and waits for their response.

```bash
#!/usr/bin/env bash
# hook-permission-{channel}.sh — Send permission request to {Channel}
# Called by PreToolUse hook when agent needs user approval

TOOL="$1"
INPUT="$2"
CHAT_ID="${3:-${CHAT_ID:-}}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

bash "${SCRIPT_DIR}/send-{channel}.sh" "${CHAT_ID}" "Permission request: ${TOOL}
${INPUT}

Reply: allow / deny"
```

### Step 8: Enable in config.json

```json
{
  "channels": [
    {"type": "{channel}", "enabled": true, "your_config": "value"}
  ]
}
```

### Step 9: Test

```bash
# Syntax check all scripts
bash -n adapters/{channel}/start.sh
bash -n adapters/{channel}/health.sh
bash -n adapters/{channel}/stop.sh
bash -n core/bus/check-{channel}.sh
bash -n core/bus/send-{channel}.sh
bash -n core/bus/hook-permission-{channel}.sh

# Test send manually
bash core/bus/send-{channel}.sh <recipient> "Test message"

# Test health
bash adapters/{channel}/health.sh; echo "Exit: $?"

# Enable and start
# Edit agents/prisma/config.json → add channel
# Restart: bash disable-agent.sh prisma && bash enable-agent.sh prisma
```

## Feature Parity Matrix (Current State)

| Feature | Telegram | Discord | Web | WhatsApp | Slack |
|---------|:--------:|:-------:|:---:|:--------:|:-----:|
| send text | YES | YES | YES | YES | YES |
| check/poll | YES | YES | YES | YES | YES |
| hook-permission | YES | YES | YES | YES | YES |
| hook-ask | YES | NO | NO | NO | NO |
| hook-planmode | YES | NO | NO | NO | NO |
| auto-chunking | YES | YES | YES | YES | YES |
| rate limiting | YES | YES | NO | YES | YES |
| retry+backoff | YES | YES | NO | YES | YES |
| typing indicator | YES | YES | NO | NO | NO |
| photo/image | YES | YES | NO | YES | YES |
| progressive send | YES | YES | NO | NO | NO |
| edit message | YES | YES | NO | NO | NO |
| threads/topics | YES | YES | NO | NO | YES |
| inline buttons | YES | YES | NO | NO | NO |
| markdown sanitize | YES (HTML) | NO | NO | NO | NO |
| delivery queue | YES | NO | NO | NO | NO |
| **Quality Level** | **PRODUCTION** | **BETA** | **STUB** | **STUB** | **STUB** |

## Roadmap to Production Quality

To bring a STUB channel to PRODUCTION, implement in this order:

1. **Shared modules** — Source `_message-pipeline.sh` and `_typing-indicator.sh`
2. **Markdown sanitize** — Use `pipeline_sanitize_html` or `pipeline_strip_markdown`
3. **Delivery queue** — Integrate write-ahead queue (Story 114.19)
4. **hook-ask** — Agent question flow
5. **hook-planmode** — Plan mode approval
6. **Progressive send** — Edit-in-place for streaming responses
7. **Inline buttons** — For permission prompts and callbacks

---

*Adapter Creation Guide | AIOX Message Gateway | 2026-04-06*
*Reference: Story 114.19 (Pipeline Formalization), Story 114.18 (Channel Hardening)*
