#!/usr/bin/env python3
"""
socket-listener.py — Slack Socket Mode listener for AIOX Agent Gateway

Persistent WebSocket connection to Slack (no public webhook needed).
Receives messages and app mentions in real-time, normalizes to
adapter-message.schema.json, and writes to channel-inbox/.

Also handles block_actions events (button clicks for permission requests).

Dependencies: pip install slack-bolt

Reference: OpenClaw extensions/slack/ — Socket Mode + Bolt event handlers
Story 114.18 Phase 4
"""

import json
import os
import random
import string
import sys
import time
from pathlib import Path

try:
    from slack_bolt import App
    from slack_bolt.adapter.socket_mode import SocketModeHandler
    from slack_sdk import WebClient
except ImportError:
    print("ERROR: slack-bolt required. Install with: pip install slack-bolt", file=sys.stderr)
    sys.exit(1)

# --- Configuration ---
BOT_TOKEN = os.environ.get("SLACK_BOT_TOKEN", "")
APP_TOKEN = os.environ.get("SLACK_APP_TOKEN", "")
AGENT_NAME = os.environ.get("CRM_AGENT_NAME", "prisma")
INSTANCE_ID = os.environ.get("CRM_INSTANCE_ID", "default")
CRM_ROOT = Path(os.environ.get(
    "CRM_ROOT",
    Path.home() / ".claude-remote" / INSTANCE_ID,
))
ALLOWED_CHANNELS = [
    c.strip() for c in os.environ.get("SLACK_ALLOWED_CHANNELS", "").split(",") if c.strip()
]

INBOX_DIR = CRM_ROOT / "channel-inbox" / AGENT_NAME
LOG_DIR = CRM_ROOT / "logs" / AGENT_NAME
LOG_FILE = LOG_DIR / "slack-listener.log"

# Ensure directories
INBOX_DIR.mkdir(parents=True, exist_ok=True)
LOG_DIR.mkdir(parents=True, exist_ok=True)

if not BOT_TOKEN:
    print("ERROR: SLACK_BOT_TOKEN not set", file=sys.stderr)
    sys.exit(1)
if not APP_TOKEN:
    print("ERROR: SLACK_APP_TOKEN not set (required for Socket Mode)", file=sys.stderr)
    sys.exit(1)


def log(msg: str) -> None:
    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    line = f"{ts} [slack-listener/{AGENT_NAME}] {msg}\n"
    with open(LOG_FILE, "a") as f:
        f.write(line)


def random_id(n: int = 8) -> str:
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=n))


# OpenClaw pattern: markMessageSeen() — deduplication cache (message-handler.ts)
_seen_messages: dict[str, float] = {}
_SEEN_TTL = 60.0  # 60s dedup window


def _mark_seen(channel: str, ts: str) -> bool:
    """Return True if already seen (duplicate). Cleans expired entries."""
    key = f"{channel}:{ts}"
    now = time.time()
    # Purge expired
    expired = [k for k, v in _seen_messages.items() if now - v > _SEEN_TTL]
    for k in expired:
        del _seen_messages[k]
    if key in _seen_messages:
        return True
    _seen_messages[key] = now
    return False


def write_to_inbox(payload: dict) -> None:
    """Atomic write to channel-inbox/."""
    ts_ms = int(time.time() * 1000)
    filename = f"{ts_ms}-slack-{random_id()}.json"
    filepath = INBOX_DIR / filename
    tmppath = INBOX_DIR / f".tmp-{random_id()}"
    try:
        with open(tmppath, "w") as f:
            json.dump(payload, f)
        os.chmod(str(tmppath), 0o600)
        os.rename(str(tmppath), str(filepath))
    except OSError:
        with open(filepath, "w") as f:
            json.dump(payload, f)
    log(f"Wrote inbox: {filename}")


# --- Slack App ---
app = App(token=BOT_TOKEN)
client = WebClient(token=BOT_TOKEN)

# Cache bot user ID to filter self-messages
BOT_USER_ID = ""
try:
    auth = client.auth_test()
    BOT_USER_ID = auth.get("user_id", "")
    log(f"Authenticated as {auth.get('user', 'unknown')} ({BOT_USER_ID})")
except Exception as e:
    log(f"WARNING: auth_test failed: {e}")


def resolve_user_name(user_id: str) -> str:
    """Resolve Slack user ID to display name."""
    try:
        info = client.users_info(user=user_id)
        profile = info.get("user", {}).get("profile", {})
        return profile.get("display_name") or profile.get("real_name") or user_id
    except Exception:
        return user_id


@app.event("message")
def handle_message(event, say):
    """Handle incoming messages."""
    # Skip bot messages and message subtypes (OpenClaw: ignores most subtypes)
    if event.get("bot_id") or event.get("user") == BOT_USER_ID:
        return
    subtype = event.get("subtype", "")
    if subtype and subtype not in ("file_share",):
        return

    channel = event.get("channel", "")
    ts = event.get("ts", "")

    # Deduplication (OpenClaw pattern: markMessageSeen)
    if _mark_seen(channel, ts):
        return

    # Filter by allowed channels
    if ALLOWED_CHANNELS and channel not in ALLOWED_CHANNELS:
        return

    user_id = event.get("user", "")
    text = event.get("text", "")
    thread_ts = event.get("thread_ts", "")

    from_name = resolve_user_name(user_id)

    normalized = {
        "_source": "slack",
        "_type": "message",
        "_timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "_message_id": ts,
        "platform": "slack",
        "chat_id": channel,
        "from": from_name,
        "user_id": user_id,
        "text": text,
    }
    if thread_ts:
        normalized["thread_id"] = thread_ts
        normalized["reply_to_message_id"] = thread_ts

    write_to_inbox(normalized)
    log(f"Message from {from_name} in {channel}: {text[:80]}")


@app.event("app_mention")
def handle_mention(event, say):
    """Handle @bot mentions — treat as direct message."""
    channel = event.get("channel", "")
    ts = event.get("ts", "")

    # Dedup: avoid double-processing if message event already handled this
    if _mark_seen(channel, ts):
        return

    if ALLOWED_CHANNELS and channel not in ALLOWED_CHANNELS:
        return

    user_id = event.get("user", "")
    # Strip the mention from text
    text = event.get("text", "")
    if BOT_USER_ID:
        text = text.replace(f"<@{BOT_USER_ID}>", "").strip()

    from_name = resolve_user_name(user_id)
    thread_ts = event.get("thread_ts", event.get("ts", ""))

    normalized = {
        "_source": "slack",
        "_type": "message",
        "_timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "_message_id": event.get("ts", ""),
        "platform": "slack",
        "chat_id": channel,
        "from": from_name,
        "user_id": user_id,
        "text": text,
    }
    if thread_ts:
        normalized["thread_id"] = thread_ts

    write_to_inbox(normalized)
    log(f"Mention from {from_name} in {channel}: {text[:80]}")


@app.action("perm_allow")
@app.action("perm_deny")
def handle_permission_action(ack, body, action):
    """Handle permission button clicks (Block Kit actions)."""
    ack()

    action_id = action.get("action_id", "")
    user = body.get("user", {})
    username = user.get("username", "unknown")

    decision = "approve" if action_id == "perm_allow" else "deny"

    # Write response file for hook-permission-slack.sh
    response_file = Path(f"/tmp/crm-hook-response-{AGENT_NAME}-slack.json")
    try:
        response_file.write_text(json.dumps({
            "decision": decision,
            "user": username,
            "action_id": action_id,
        }))
    except OSError as e:
        log(f"Failed to write response file: {e}")

    # Also write to inbox as callback
    channel = body.get("channel", {}).get("id", "")
    write_to_inbox({
        "_source": "slack",
        "_type": "callback",
        "_timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "platform": "slack",
        "chat_id": channel,
        "from": username,
        "user_id": user.get("id", ""),
        "text": decision,
        "callback_data": action_id,
    })

    log(f"Permission {decision} by {username} (action: {action_id})")


# --- Start ---
def main():
    log(f"Starting Slack Socket Mode listener")
    log(f"Inbox: {INBOX_DIR}")
    if ALLOWED_CHANNELS:
        log(f"Allowed channels: {', '.join(ALLOWED_CHANNELS)}")

    print(f"Slack listener starting (Socket Mode)")
    print(f"  Bot: {BOT_USER_ID}")
    print(f"  Inbox: {INBOX_DIR}")

    handler = SocketModeHandler(app, APP_TOKEN)
    handler.start()


if __name__ == "__main__":
    main()
