#!/usr/bin/env python3
"""
webhook-receiver.py - Multi-Channel Webhook Receiver for claude-remote-manager

HTTP server that receives webhook POSTs from multiple platforms and writes
normalized messages to the agent inbox directory.

Supported endpoints:
    POST /webhook/{agent}           - Telegram webhook
    POST /discord/interactions      - Discord interaction handler (buttons)
    POST /whatsapp                  - WhatsApp Cloud API webhook (verification + messages)
    GET  /whatsapp                  - WhatsApp webhook verification
    GET  /health                    - Health check

Architecture:
    Platform APIs --webhook POST--> this server --> channel-inbox/{agent}/*.json
    fast-checker.sh reads inbox/ --> tmux paste-buffer --> Claude Code

Usage:
    python3 webhook-receiver.py

Environment:
    BOT_TOKEN                   - Telegram bot token (required for Telegram)
    ALLOWED_USER                - Telegram user ID to accept (required for Telegram)
    CRM_AGENT_NAME              - Agent name (default: prisma)
    CRM_INSTANCE_ID             - Instance ID (default: default)
    WEBHOOK_PORT                - Listen port (default: 8443)
    WEBHOOK_SECRET              - Secret token for X-Telegram-Bot-Api-Secret-Token
    TELEGRAM_IMAGE_DIR          - Where to save downloaded photos
    DISCORD_PUBLIC_KEY          - Discord app public key for signature verification
    WHATSAPP_VERIFY_TOKEN       - WhatsApp webhook verification token
    WHATSAPP_ALLOWED_NUMBERS    - Comma-separated allowed phone numbers

Story 110.27 Phase 1 + Story 114.18 Phase 1 (Discord) + Phase 3 (WhatsApp)
"""

import asyncio
import hashlib
import hmac
import json
import os
import random
import string
import sys
import time
from pathlib import Path

try:
    from aiohttp import web
    import aiohttp
except ImportError:
    print("ERROR: aiohttp required. Install with: pip3 install aiohttp", file=sys.stderr)
    sys.exit(1)

# Optional: nacl for Discord Ed25519 signature verification
try:
    from nacl.signing import VerifyKey
    from nacl.exceptions import BadSignatureError
    HAS_NACL = True
except ImportError:
    HAS_NACL = False

# --- Configuration ---
BOT_TOKEN = os.environ.get("BOT_TOKEN", "")
ALLOWED_USER = os.environ.get("ALLOWED_USER", "")
AGENT_NAME = os.environ.get("CRM_AGENT_NAME", "prisma")
INSTANCE_ID = os.environ.get("CRM_INSTANCE_ID", "default")
WEBHOOK_PORT = int(os.environ.get("WEBHOOK_PORT", "8443"))
WEBHOOK_SECRET = os.environ.get("WEBHOOK_SECRET", "")
DISCORD_PUBLIC_KEY = os.environ.get("DISCORD_PUBLIC_KEY", "")
WHATSAPP_VERIFY_TOKEN = os.environ.get("WHATSAPP_VERIFY_TOKEN", "")
WHATSAPP_ALLOWED_NUMBERS = [
    n.strip() for n in os.environ.get("WHATSAPP_ALLOWED_NUMBERS", "").split(",") if n.strip()
]
CRM_ROOT = Path.home() / ".claude-remote" / INSTANCE_ID

# Resolve paths
INBOX_DIR = CRM_ROOT / "channel-inbox" / AGENT_NAME
LOG_FILE = CRM_ROOT / "logs" / AGENT_NAME / "webhook.log"
TEMPLATE_ROOT = os.environ.get(
    "CRM_TEMPLATE_ROOT",
    str(Path(__file__).resolve().parent.parent.parent),
)
IMAGE_DIR = Path(
    os.environ.get(
        "TELEGRAM_IMAGE_DIR",
        f"{TEMPLATE_ROOT}/agents/{AGENT_NAME}/telegram-images",
    )
)


def log(msg: str) -> None:
    """Append a timestamped log line."""
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with open(LOG_FILE, "a") as f:
        f.write(f"{ts} [webhook/{AGENT_NAME}] {msg}\n")


def random_id(n: int = 8) -> str:
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=n))


def write_to_inbox(payload: dict) -> None:
    """Write a normalized adapter message to channel-inbox/ for fast-checker.

    Uses atomic write (tmpfile + rename) to prevent partial reads.
    Format conforms to core/schemas/adapter-message.schema.json.
    """
    INBOX_DIR.mkdir(parents=True, exist_ok=True)
    ts_ms = int(time.time() * 1000)
    source = payload.get("_source", "webhook")
    filename = f"{ts_ms}-{source}-{random_id()}.json"
    filepath = INBOX_DIR / filename
    tmppath = INBOX_DIR / f".tmp-{random_id()}"
    try:
        with open(tmppath, "w") as f:
            json.dump(payload, f)
        os.chmod(str(tmppath), 0o600)
        os.rename(str(tmppath), str(filepath))
    except OSError:
        # Fallback: direct write if rename fails (same filesystem)
        with open(filepath, "w") as f:
            json.dump(payload, f)
    log(f"Wrote channel-inbox message: {filename}")


async def download_photo(file_id: str) -> str:
    """Download a photo from Telegram and return the local path."""
    IMAGE_DIR.mkdir(parents=True, exist_ok=True)
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/getFile?file_id={file_id}"
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as resp:
            data = await resp.json()
            if not data.get("ok"):
                return ""
            file_path = data["result"].get("file_path", "")
            if not file_path:
                return ""

        download_url = f"https://api.telegram.org/file/bot{BOT_TOKEN}/{file_path}"
        local_path = str(IMAGE_DIR / f"{int(time.time())}.jpg")
        async with session.get(download_url) as resp:
            with open(local_path, "wb") as f:
                f.write(await resp.read())
        return local_path


async def send_reaction(chat_id: int, message_id: int) -> None:
    """React with eyes emoji so user knows bot received the message."""
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/setMessageReaction"
    payload = {
        "chat_id": chat_id,
        "message_id": message_id,
        "reaction": [{"type": "emoji", "emoji": "\U0001f440"}],
    }
    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(url, json=payload):
                pass
    except Exception:
        pass  # Best-effort, don't block on failure


async def send_typing(chat_id: int) -> None:
    """Send typing indicator."""
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendChatAction"
    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(url, data={"chat_id": chat_id, "action": "typing"}):
                pass
    except Exception:
        pass


async def handle_webhook(request: web.Request) -> web.Response:
    """Handle incoming Telegram webhook POST."""
    # Validate secret token
    if WEBHOOK_SECRET:
        header_secret = request.headers.get("X-Telegram-Bot-Api-Secret-Token", "")
        if header_secret != WEBHOOK_SECRET:
            log(f"Rejected: invalid secret token")
            return web.Response(status=403, text="Forbidden")

    try:
        update = await request.json()
    except json.JSONDecodeError:
        return web.Response(status=400, text="Invalid JSON")

    # --- Process message ---
    message = update.get("message")
    callback_query = update.get("callback_query")

    if message:
        from_user = message.get("from", {})
        user_id = str(from_user.get("id", ""))

        # Filter by ALLOWED_USER
        if ALLOWED_USER and user_id != ALLOWED_USER:
            log(f"Rejected message from user {user_id} (allowed: {ALLOWED_USER})")
            return web.Response(text="ok")

        chat_id = message.get("chat", {}).get("id", 0)
        from_name = from_user.get("first_name", "unknown")
        date = message.get("date", 0)

        # Photo message
        if "photo" in message:
            # Get largest photo (last in array)
            file_id = message["photo"][-1]["file_id"]
            caption = message.get("caption", "")
            local_path = await download_photo(file_id)

            write_to_inbox({
                "_source": "webhook",
                "_type": "photo",
                "_timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "_message_id": str(message.get("message_id", "")),
                "platform": "telegram",
                "chat_id": str(chat_id),
                "from": from_name,
                "user_id": user_id,
                "text": caption,
                "media": {
                    "type": "photo",
                    "local_path": local_path,
                    "caption": caption,
                },
                # Legacy compat fields (fast-checker reads these)
                "image_path": local_path,
                "date": date,
                "type": "photo",
            })

        # Text message
        elif "text" in message:
            write_to_inbox({
                "_source": "webhook",
                "_type": "message",
                "_timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "_message_id": str(message.get("message_id", "")),
                "platform": "telegram",
                "chat_id": str(chat_id),
                "from": from_name,
                "user_id": user_id,
                "text": message["text"],
                # Legacy compat fields (fast-checker reads these)
                "date": date,
                "type": "message",
            })
            await send_typing(chat_id)

    elif callback_query:
        from_user = callback_query.get("from", {})
        user_id = str(from_user.get("id", ""))

        if ALLOWED_USER and user_id != ALLOWED_USER:
            log(f"Rejected callback from user {user_id}")
            return web.Response(text="ok")

        cb_message = callback_query.get("message", {})
        cb_chat_id = cb_message.get("chat", {}).get("id", 0)
        write_to_inbox({
            "_source": "webhook",
            "_type": "callback",
            "_timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "_message_id": str(cb_message.get("message_id", "")),
            "platform": "telegram",
            "chat_id": str(cb_chat_id),
            "from": from_user.get("first_name", "unknown"),
            "user_id": user_id,
            "text": "",
            "callback_data": callback_query.get("data", ""),
            "callback_query_id": callback_query.get("id", ""),
            # Legacy compat fields (fast-checker reads these)
            "message_id": cb_message.get("message_id", 0),
            "date": cb_message.get("date", 0),
            "type": "callback",
        })

    return web.Response(text="ok")


async def handle_discord_interactions(request: web.Request) -> web.Response:
    """Handle Discord interaction webhooks (button clicks, etc.).

    Discord requires Ed25519 signature verification on all interaction endpoints.
    Type 1 = PING (verification), Type 3 = MESSAGE_COMPONENT (button click).
    """
    body = await request.read()
    body_text = body.decode("utf-8")

    # Verify Ed25519 signature (Discord requirement)
    if DISCORD_PUBLIC_KEY and HAS_NACL:
        signature = request.headers.get("X-Signature-Ed25519", "")
        timestamp = request.headers.get("X-Signature-Timestamp", "")
        try:
            verify_key = VerifyKey(bytes.fromhex(DISCORD_PUBLIC_KEY))
            verify_key.verify(f"{timestamp}{body_text}".encode(), bytes.fromhex(signature))
        except (BadSignatureError, ValueError, Exception):
            log("Discord interaction: invalid signature")
            return web.Response(status=401, text="Invalid signature")
    elif DISCORD_PUBLIC_KEY and not HAS_NACL:
        log("WARNING: DISCORD_PUBLIC_KEY set but PyNaCl not installed. Skipping verification.")

    try:
        interaction = json.loads(body_text)
    except json.JSONDecodeError:
        return web.Response(status=400, text="Invalid JSON")

    interaction_type = interaction.get("type", 0)

    # Type 1: PING — Discord verification handshake
    if interaction_type == 1:
        log("Discord PING received (verification)")
        return web.json_response({"type": 1})

    # Type 3: MESSAGE_COMPONENT — button click
    if interaction_type == 3:
        data = interaction.get("data", {})
        custom_id = data.get("custom_id", "")
        user = interaction.get("member", {}).get("user", {}) or interaction.get("user", {})
        username = user.get("username", "unknown")

        log(f"Discord interaction: custom_id={custom_id} by {username}")

        # Permission button: custom_id format = perm_allow_{req_id} or perm_deny_{req_id}
        if custom_id.startswith("perm_allow_") or custom_id.startswith("perm_deny_"):
            if custom_id.startswith("perm_allow_"):
                decision = "approve"
                req_id = custom_id[len("perm_allow_"):]
            else:
                decision = "deny"
                req_id = custom_id[len("perm_deny_"):]

            # Write response file for hook-permission-discord.sh to pick up
            response_file = Path(f"/tmp/crm-hook-response-{AGENT_NAME}-{req_id}.json")
            try:
                response_file.write_text(json.dumps({"decision": decision, "user": username}))
            except OSError as e:
                log(f"Failed to write response file: {e}")

            # Acknowledge the interaction with a visible response
            decision_text = "Approved" if decision == "approve" else "Denied"
            return web.json_response({
                "type": 4,
                "data": {
                    "content": f"**{decision_text}** by {username}",
                    "flags": 64,  # Ephemeral
                },
            })

        # Generic interaction — acknowledge silently
        return web.json_response({"type": 6})

    # Unknown type — acknowledge
    return web.json_response({"type": 1})


async def handle_whatsapp_verify(request: web.Request) -> web.Response:
    """Handle WhatsApp webhook verification (GET).

    WhatsApp Cloud API sends: GET /whatsapp?hub.mode=subscribe&hub.verify_token=xxx&hub.challenge=yyy
    """
    mode = request.query.get("hub.mode", "")
    token = request.query.get("hub.verify_token", "")
    challenge = request.query.get("hub.challenge", "")

    if mode == "subscribe" and token == WHATSAPP_VERIFY_TOKEN and WHATSAPP_VERIFY_TOKEN:
        log(f"WhatsApp webhook verified (challenge={challenge})")
        return web.Response(text=challenge)

    log(f"WhatsApp webhook verification failed (mode={mode})")
    return web.Response(status=403, text="Forbidden")


async def handle_whatsapp_webhook(request: web.Request) -> web.Response:
    """Handle incoming WhatsApp Cloud API webhook POST.

    Payload structure: entry[].changes[].value.messages[]
    """
    try:
        payload = await request.json()
    except json.JSONDecodeError:
        return web.Response(status=400, text="Invalid JSON")

    entries = payload.get("entry", [])
    for entry in entries:
        for change in entry.get("changes", []):
            value = change.get("value", {})
            messages = value.get("messages", [])
            contacts = value.get("contacts", [])

            # Build contacts lookup
            contact_map = {}
            for c in contacts:
                wa_id = c.get("wa_id", "")
                name = c.get("profile", {}).get("name", wa_id)
                contact_map[wa_id] = name

            for msg in messages:
                sender = msg.get("from", "")

                # Filter by allowed numbers
                if WHATSAPP_ALLOWED_NUMBERS and sender not in WHATSAPP_ALLOWED_NUMBERS:
                    log(f"WhatsApp: rejected message from {sender} (not in allowed list)")
                    continue

                msg_type = msg.get("type", "text")
                msg_id = msg.get("id", "")
                timestamp = msg.get("timestamp", str(int(time.time())))
                from_name = contact_map.get(sender, sender)

                # Extract text
                text = ""
                normalized_type = "message"
                if msg_type == "text":
                    text = msg.get("text", {}).get("body", "")
                elif msg_type == "image":
                    text = msg.get("image", {}).get("caption", "")
                    normalized_type = "photo"
                elif msg_type == "interactive":
                    # Button reply from permission request
                    interactive = msg.get("interactive", {})
                    if interactive.get("type") == "button_reply":
                        button_id = interactive.get("button_reply", {}).get("id", "")
                        text = button_id  # "approve" or "deny"
                        normalized_type = "callback"
                elif msg_type == "button":
                    text = msg.get("button", {}).get("text", "")
                else:
                    text = f"[{msg_type} message]"

                normalized = {
                    "_source": "whatsapp",
                    "_type": normalized_type,
                    "_timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                    "_message_id": msg_id,
                    "platform": "whatsapp",
                    "chat_id": sender,
                    "from": from_name,
                    "user_id": sender,
                    "text": text,
                }
                write_to_inbox(normalized)
                log(f"WhatsApp message from {from_name}: {text[:80]}")

    return web.Response(text="ok")


async def handle_health(request: web.Request) -> web.Response:
    """Health check endpoint."""
    return web.Response(
        text=json.dumps({
            "status": "ok",
            "agent": AGENT_NAME,
            "mode": "webhook",
            "uptime_s": int(time.time() - START_TIME),
        }),
        content_type="application/json",
    )


# --- Startup ---
START_TIME = time.time()


def main() -> None:
    if not BOT_TOKEN:
        print("ERROR: BOT_TOKEN not set", file=sys.stderr)
        sys.exit(1)
    if not ALLOWED_USER:
        print("ERROR: ALLOWED_USER not set", file=sys.stderr)
        sys.exit(1)

    INBOX_DIR.mkdir(parents=True, exist_ok=True)
    IMAGE_DIR.mkdir(parents=True, exist_ok=True)

    app = web.Application()
    app.router.add_post(f"/webhook/{AGENT_NAME}", handle_webhook)
    app.router.add_post("/discord/interactions", handle_discord_interactions)
    app.router.add_get("/whatsapp", handle_whatsapp_verify)
    app.router.add_post("/whatsapp", handle_whatsapp_webhook)
    app.router.add_get("/health", handle_health)

    log(f"Starting webhook receiver on port {WEBHOOK_PORT}")
    log(f"Endpoints:")
    log(f"  POST /webhook/{AGENT_NAME}  (Telegram)")
    log(f"  POST /discord/interactions   (Discord buttons)")
    log(f"  GET  /whatsapp               (WhatsApp verify)")
    log(f"  POST /whatsapp               (WhatsApp messages)")
    log(f"  GET  /health")
    log(f"Inbox: {INBOX_DIR}")

    print(f"Webhook receiver listening on port {WEBHOOK_PORT}")
    print(f"  POST /webhook/{AGENT_NAME}  (Telegram)")
    print(f"  POST /discord/interactions   (Discord)")
    print(f"  GET|POST /whatsapp           (WhatsApp)")
    print(f"  GET  /health")
    web.run_app(app, host="0.0.0.0", port=WEBHOOK_PORT, print=None)


if __name__ == "__main__":
    main()
