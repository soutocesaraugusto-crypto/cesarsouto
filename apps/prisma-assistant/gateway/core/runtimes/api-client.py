#!/usr/bin/env python3
"""
api-client.py — Lightweight API-based agent daemon (no CLI dependency)

Polls channel-inbox/ for incoming messages, calls OpenRouter-compatible API,
manages conversation history in JSONL, and responds via send-channel.sh.

This enables 200+ models (Claude, GPT-4o, Llama, DeepSeek, Gemini, Qwen, etc.)
without any CLI tool installed — just Python + an API key.

Architecture:
    channel-inbox/{agent}/*.json → this daemon → OpenRouter API → send-channel.sh

Usage:
    python3 api-client.py                  # Start daemon
    python3 api-client.py --once "prompt"  # One-shot (for cron-executor)

Environment:
    OPENROUTER_API_KEY   - API key (required)
    OPENROUTER_BASE_URL  - API base (default: https://openrouter.ai/api/v1)
    OPENROUTER_MODEL     - Model (default: anthropic/claude-3.5-haiku)
    CRM_AGENT_NAME       - Agent name (default: prisma)
    CRM_INSTANCE_ID      - Instance ID (default: default)

Zero pip install required — uses stdlib only (urllib.request).

Epic 114 / Story 114.3
"""

import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

# --- Configuration ---
API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
BASE_URL = os.environ.get("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
MODEL = os.environ.get("OPENROUTER_MODEL", os.environ.get("RUNTIME_MODEL", "anthropic/claude-3.5-haiku"))
AGENT_NAME = os.environ.get("CRM_AGENT_NAME", "prisma")
INSTANCE_ID = os.environ.get("CRM_INSTANCE_ID", "default")

CRM_ROOT = Path.home() / ".claude-remote" / INSTANCE_ID
INBOX_DIR = CRM_ROOT / "channel-inbox" / AGENT_NAME
CONV_DIR = CRM_ROOT / "state" / AGENT_NAME / "conversations"
LOG_FILE = CRM_ROOT / "logs" / AGENT_NAME / "api-client.log"
PID_FILE = CRM_ROOT / "logs" / AGENT_NAME / f"api-client-{AGENT_NAME}.pid"

TEMPLATE_ROOT = os.environ.get(
    "CRM_TEMPLATE_ROOT",
    str(Path(__file__).resolve().parent.parent.parent),
)

# System prompt loaded from API-AGENT.md or SOUL.md
SYSTEM_PROMPT = ""
POLL_INTERVAL = 2  # seconds
MAX_HISTORY = 50  # max messages in conversation context
RUNNING = True


def log(msg: str) -> None:
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with open(LOG_FILE, "a") as f:
        f.write(f"{ts} [api-client/{AGENT_NAME}] {msg}\n")


def load_system_prompt() -> str:
    """Load system prompt from API-AGENT.md, SOUL.md, or template."""
    for name in ["API-AGENT.md", "SOUL.md", "CODEX_INSTRUCTIONS.md"]:
        path = Path(TEMPLATE_ROOT) / "agents" / AGENT_NAME / name
        if path.exists():
            return path.read_text()
    # Fallback to template
    tmpl = Path(TEMPLATE_ROOT) / "API-AGENT.md.template"
    if tmpl.exists():
        return tmpl.read_text()
    return f"You are {AGENT_NAME}, an AI assistant. Respond helpfully."


def api_call(messages: list, model: str = "") -> str:
    """Call OpenRouter-compatible chat/completions API. Stdlib only."""
    url = f"{BASE_URL}/chat/completions"
    payload = {
        "model": model or MODEL,
        "messages": messages,
    }
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://sinkra.io",
        "X-Title": f"AIOX Gateway ({AGENT_NAME})",
    }

    data = json.dumps(payload).encode("utf-8")
    req = Request(url, data=data, headers=headers, method="POST")

    try:
        with urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            return result["choices"][0]["message"]["content"]
    except HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        log(f"API error {e.code}: {body[:500]}")
        raise
    except URLError as e:
        log(f"Network error: {e.reason}")
        raise


# --- Conversation History (JSONL) ---
def conv_path(session_id: str) -> Path:
    CONV_DIR.mkdir(parents=True, exist_ok=True)
    return CONV_DIR / f"{session_id}.jsonl"


def load_conversation(session_id: str) -> list:
    """Load conversation history from JSONL."""
    path = conv_path(session_id)
    messages = []
    if path.exists():
        for line in path.read_text().strip().split("\n"):
            if line:
                try:
                    messages.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    # Trim to max history
    if len(messages) > MAX_HISTORY:
        messages = messages[-MAX_HISTORY:]
    return messages


def append_conversation(session_id: str, role: str, content: str) -> None:
    """Append a message to conversation JSONL."""
    path = conv_path(session_id)
    entry = json.dumps({"role": role, "content": content, "ts": time.time()})
    with open(path, "a") as f:
        f.write(entry + "\n")


# --- Message Processing ---
def process_message(msg: dict) -> None:
    """Process one incoming message from channel-inbox."""
    chat_id = str(msg.get("chat_id", ""))
    text = msg.get("text", "")
    platform = msg.get("platform", msg.get("_source", "telegram"))
    from_name = msg.get("from", "user")

    if not text or not chat_id:
        return

    # Session ID = platform:chat_id (simple, deterministic)
    session_id = f"{platform}-{chat_id}"

    # Load history
    history = load_conversation(session_id)

    # Build messages for API
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    for h in history:
        messages.append({"role": h["role"], "content": h["content"]})
    messages.append({"role": "user", "content": text})

    # Persist user message
    append_conversation(session_id, "user", text)

    # Call API
    try:
        response = api_call(messages)
    except Exception as e:
        # Log full error internally but sanitize user-facing message
        log(f"API call failed for {session_id}: {e}")
        response = "Sorry, I encountered a temporary issue processing your request. Please try again in a moment."

    # Persist assistant response
    append_conversation(session_id, "assistant", response)

    # Send response via send-channel.sh
    send_script = f"{TEMPLATE_ROOT}/core/bus/send-channel.sh"
    try:
        subprocess.run(
            ["bash", send_script, platform, chat_id, response],
            timeout=30,
            capture_output=True,
        )
    except subprocess.TimeoutExpired:
        log(f"send-channel timeout for {platform}:{chat_id}")
    except FileNotFoundError:
        log(f"send-channel.sh not found at {send_script}")

    log(f"Processed message from {from_name} ({platform}:{chat_id}) → {len(response)} chars")


def poll_inbox() -> None:
    """Check channel-inbox for new messages and process them."""
    if not INBOX_DIR.exists():
        return

    for f in sorted(INBOX_DIR.glob("*.json")):
        try:
            msg = json.loads(f.read_text())
            process_message(msg)
            f.unlink()
        except json.JSONDecodeError:
            log(f"Invalid JSON in {f.name}, removing")
            f.unlink()
        except Exception as e:
            log(f"Error processing {f.name}: {e}")
            # Don't delete — will retry next cycle


def handle_signal(signum, frame):
    global RUNNING
    log(f"Received signal {signum}, shutting down")
    RUNNING = False


def write_pid() -> None:
    PID_FILE.parent.mkdir(parents=True, exist_ok=True)
    PID_FILE.write_text(str(os.getpid()))


def remove_pid() -> None:
    try:
        PID_FILE.unlink()
    except FileNotFoundError:
        pass


# --- One-shot mode (for cron-executor / runtime_print) ---
def one_shot(prompt: str, model: str = "") -> str:
    """Single prompt → response, no conversation history."""
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": prompt},
    ]
    return api_call(messages, model=model)


# --- Compress mode (Hermes-inspired 5-phase algorithm) ---
COMPRESS_TEMPLATE = """Summarize the following conversation concisely. Preserve:
- **Goal:** What the user is trying to accomplish
- **Progress:** What has been done / in progress / blocked
- **Key Decisions:** Important choices made
- **Relevant Files:** File paths mentioned
- **Next Steps:** What needs to happen next
- **Critical Context:** Any facts the assistant must remember

Conversation to summarize:
{conversation}"""


def compress_conversation(session_id: str) -> None:
    """Compress a conversation JSONL using protect-head/tail + LLM summary.

    Hermes-inspired 5-phase algorithm (simplified for JSONL):
      Phase 1: Identify boundaries (head=5, tail=30)
      Phase 2: Extract middle section for summarization
      Phase 3: Call LLM to summarize middle
      Phase 4: Remove orphaned tool pairs (tool_call_id without match)
      Phase 5: Reassemble: head + summary-message + tail
    """
    path = conv_path(session_id)
    if not path.exists():
        return

    lines = path.read_text().strip().split("\n")
    messages = []
    for line in lines:
        if line:
            try:
                messages.append(json.loads(line))
            except json.JSONDecodeError:
                continue

    total = len(messages)
    if total <= 40:
        log(f"Compress: {session_id} has {total} messages, below threshold (40). Skipping.")
        return

    # Phase 1: Boundaries
    HEAD_COUNT = 5
    TAIL_COUNT = 30
    head = messages[:HEAD_COUNT]
    tail = messages[-TAIL_COUNT:]
    middle = messages[HEAD_COUNT:-TAIL_COUNT]

    if not middle:
        return

    # Phase 2: Build conversation text from middle for summarization
    conv_text = ""
    for msg in middle:
        role = msg.get("role", "unknown")
        content = msg.get("content", "")
        if len(content) > 500:
            content = content[:500] + "..."
        conv_text += f"{role}: {content}\n"

    # Phase 3: LLM summary
    summary_text = ""
    try:
        prompt = COMPRESS_TEMPLATE.format(conversation=conv_text[:8000])
        summary_text = api_call(
            [{"role": "user", "content": prompt}],
            model=MODEL,
        )
        log(f"Compress: LLM summary generated ({len(summary_text)} chars) for {len(middle)} middle messages")
    except Exception as e:
        log(f"Compress: LLM summary failed ({e}), falling back to trim-only")
        # Fallback: no summary, just trim

    # Phase 4: Tool pair sanitization (remove orphaned tool results)
    # In JSONL format, tool pairs are rare but check anyway
    cleaned_tail = []
    for msg in tail:
        role = msg.get("role", "")
        if role == "tool" and not any(
            m.get("role") == "assistant" and "tool_calls" in m
            for m in tail
        ):
            continue  # Orphaned tool result
        cleaned_tail.append(msg)

    # Phase 5: Reassemble
    compressed = list(head)
    if summary_text:
        compressed.append({
            "role": "system",
            "content": f"[Context Summary — {len(middle)} messages compressed]\n{summary_text}",
            "ts": time.time(),
            "_compressed": True,
        })
    compressed.extend(cleaned_tail)

    # Write back
    with open(path, "w") as f:
        for msg in compressed:
            f.write(json.dumps(msg) + "\n")

    log(f"Compress: {session_id} — {total} → {len(compressed)} messages (method: {'summary' if summary_text else 'trim'})")


# --- Main ---
def main() -> None:
    global SYSTEM_PROMPT

    if not API_KEY:
        print("ERROR: OPENROUTER_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    SYSTEM_PROMPT = load_system_prompt()

    # One-shot mode
    if len(sys.argv) > 1 and sys.argv[1] == "--once":
        prompt = sys.argv[2] if len(sys.argv) > 2 else sys.stdin.read()
        model = ""
        if "--model" in sys.argv:
            idx = sys.argv.index("--model")
            model = sys.argv[idx + 1] if idx + 1 < len(sys.argv) else ""
        print(one_shot(prompt, model))
        return

    # Compress mode: triggered by context-monitor.sh
    if len(sys.argv) > 1 and sys.argv[1] == "--compress":
        CONV_DIR.mkdir(parents=True, exist_ok=True)
        compressed = 0
        for f in sorted(CONV_DIR.glob("*.jsonl")):
            compress_conversation(f.stem)
            compressed += 1
        print(f"Compressed {compressed} conversation(s)")
        return

    # Daemon mode
    INBOX_DIR.mkdir(parents=True, exist_ok=True)
    CONV_DIR.mkdir(parents=True, exist_ok=True)

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    write_pid()
    log(f"Daemon started. Model: {MODEL}. Inbox: {INBOX_DIR}")
    print(f"API client daemon started (PID {os.getpid()})")
    print(f"  Model: {MODEL}")
    print(f"  Inbox: {INBOX_DIR}")

    try:
        while RUNNING:
            poll_inbox()
            time.sleep(POLL_INTERVAL)
    finally:
        remove_pid()
        log("Daemon stopped")


if __name__ == "__main__":
    main()
