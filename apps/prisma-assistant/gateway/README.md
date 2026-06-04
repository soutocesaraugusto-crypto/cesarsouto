# AIOX Message Gateway — Universal Agent Gateway

Multi-runtime, multi-model, multi-channel gateway. Delivers AI agents via 5 channels with 4 runtime drivers, smart model routing, fallback chain with circuit breaker, credential rotation, and 103 security patterns.

**Epic 114** | 19/22 stories DONE | SINKRA pipeline score: 98/100

## Architecture

```
You (any channel)
    │
    ├── Telegram  ──→ adapter (webhook/poll) ─┐
    ├── Discord   ──→ adapter (REST poll)     │
    ├── Web Chat  ──→ adapter (HTTP server)   ├──→ channel-inbox/ ──→ fast-checker.sh
    ├── WhatsApp  ──→ adapter (Baileys bridge)│         │
    └── Slack     ──→ adapter (Socket Mode)  ─┘    safety-scanner.sh (30 patterns)
                                                       │
                                               classify-turn.sh (quick/standard/deep)
                                                       │
                                    ┌──────────────────┼──────────────────┐
                                    │ quick             │ standard/deep    │
                              quick-reply.sh      tmux paste-buffer       │
                              (zero-context)            │                  │
                                    │         Runtime Facade (12 functions)│
                                    │                   │                  │
                                    │     ┌─────────────┼─────────────┐   │
                                    │     │             │             │   │
                                    │  claude-code   codex    api-openrouter
                                    │  (tmux+PTY)  (tmux+PTY)  (Python daemon)
                                    │                                     │
                                    └──────────── send-channel.sh ←───────┘
                                                       │
                                              delivery-queue.sh (retry 5x)
                                                       │
                                    fallback.sh (circuit breaker, cooldown 30s→5m)
                                    _credential-pool.sh (least-used rotation)
                                    context-monitor.sh (auto-compact at 80%)
                                    config-watcher.sh (hot-reload 30s)
                                    health-alerter.sh (6 conditions, 1h cooldown)
                                    metrics-collector.sh (JSONL per interaction)
```

### Modes

The fast-checker supports two modes:

| Mode | Env Var | Description |
|------|---------|-------------|
| Polling (default) | `ADAPTER_MODE=false` | fast-checker polls Telegram via `check-telegram.sh` + checks agent inbox |
| Adapter | `ADAPTER_MODE=true` | Adapters write normalized JSON to `channel-inbox/`. fast-checker only reads inbox. No direct Telegram polling |

Adapter mode enables webhook-based architectures and custom adapters. See `core/schemas/adapter-message.schema.json` for the normalized message format.

## Quick Start

```bash
# 1. Install (once)
bash gateway/install.sh

# 2. Configure channel (interactive)
bash gateway/setup-channel.sh

# 3. Deploy agent
bash gateway/deploy-agent.sh

# 4. Start
bash gateway/enable-agent.sh prisma
```

## Channels (5 PRODUCTION)

| Channel | Inbound | Outbound | Approval UI | Key Deps |
|---------|---------|----------|-------------|----------|
| **Telegram** | Webhook/polling (3s) | API + progressive + topics | Inline buttons + callback | curl + jq (zero SDK) |
| **Discord** | REST poll + interaction webhooks | API + embeds + threading + typing | Button components | curl + jq (zero SDK) |
| **Web Chat** | HTTP polling (2s) | HTTP + SQLite persistence | HTML buttons | Python stdlib |
| **WhatsApp** | Baileys bridge (real-time) | Bridge HTTP API | Interactive buttons (3 max) | Node.js + @whiskeysockets/baileys |
| **Slack** | Socket Mode (real-time) | Web API + threads | Block Kit buttons | Python + slack-bolt |

### Channel Setup

**Telegram:** `@BotFather` → `/newbot` → `setup-channel.sh` → paste token

**Discord:** discord.com/developers → bot → `setup-channel.sh` → paste token + channel ID

**Web Chat:** `setup-channel.sh` → choose port → open `http://localhost:8080`

**WhatsApp:** First boot shows QR code → scan with WhatsApp → connected

**Slack:** api.slack.com → create app → enable Socket Mode → `setup-channel.sh` → paste bot token + app token

## File Structure

```
gateway/
  core/
    bus/                               ← Channel adapters (5 channels × 3 scripts each)
      send-{telegram,discord,web,whatsapp,slack}.sh
      check-{telegram,discord,web,whatsapp,slack}.sh
      hook-permission-{telegram,discord,web,whatsapp,slack}.sh
      send-channel.sh                  ← Multi-channel router
      _telegram-curl.sh                ← Telegram API helper (retry, rate limit)
      _credential-pool.sh              ← Multi-key rotation (least-used, 5min cooldown)
      _markdown-sanitize.sh            ← Markdown with Telegram fallback
      _logger.sh                       ← Structured JSON logging (JSON Lines)
      delivery-queue.sh                ← Persistent retry queue (5x backoff)
      deliver-multi.sh                 ← Multi-target delivery
      send-message.sh                  ← Inter-agent messaging protocol
    runtimes/                          ← Runtime abstraction (12-function facade)
      runtime.sh                       ← Facade: loads driver by config
      claude-code.sh                   ← Claude Code CLI driver
      codex.sh                         ← Codex CLI driver
      api-openrouter.sh                ← API driver (Python daemon)
      mock.sh                          ← Test mock driver
      fallback.sh                      ← Circuit breaker + model cooldown (30s→60s→5m)
      api-client.py                    ← API runtime Python daemon
    scripts/                           ← Agent lifecycle + intelligence
      agent-wrapper.sh                 ← tmux lifecycle, crash recovery, 71h refresh, watchdog
      fast-checker.sh                  ← Message poller + injector
      classify-turn.sh                 ← 3-tier routing (quick/standard/deep)
      quick-reply.sh                   ← Zero-context response via cheap model
      safety-scanner.sh                ← Pre-runtime command filter (30 patterns, 6 categories)
      safety-allowlist.sh              ← Allowlist with 3 scopes (once/session/always)
      context-monitor.sh               ← Auto-compact at 80% threshold
      config-watcher.sh                ← Hot-reload (md5 polling 30s)
      metrics-collector.sh             ← JSONL metrics per interaction
      health-alerter.sh                ← 6 proactive conditions, 1h cooldown
      cron-executor.sh                 ← Isolated cron execution
      session-policies.sh              ← Deterministic session keys
      generate-handoff-context.sh      ← Structured YAML handoff
    schemas/
      adapter-message.schema.json      ← Normalized message contract
      config.schema.json               ← Config validation schema
    webhook/
      webhook-receiver.py              ← Async webhook server (Telegram, Discord, WhatsApp)
  adapters/                            ← Per-channel lifecycle (start/health/stop)
    telegram/                          ← Polling daemon, 3-state health
    discord/                           ← REST poll, interaction webhooks
    web/                               ← HTTP server lifecycle
    whatsapp/                          ← Baileys bridge (Node.js)
    slack/                             ← Socket Mode listener (Python)
  tests/                               ← 20 E2E test suites
    run-tests.sh                       ← 92+ unit tests
    test-gateway-e2e.sh                ← E2E: runtime, queue, adapters, safety, metrics
  skill-lifecycle.py                   ← Skill promotion + security guard (73 patterns)
  session-persist.sh / session-recall-server.py  ← SQLite FTS5 session storage + MCP
  web-chat-server.py                   ← Web Chat HTTP server (SQLite persistence)
  deploy-agent.sh / enable-agent.sh / disable-agent.sh
```

## Telegram Commands

The bot registers slash commands for Telegram autocomplete. Type `/` in the chat to see all available commands.

### Session Commands (built-in)

These are handled directly by the gateway — no Claude Code injection needed.

| Command | Description |
|---------|-------------|
| `/new` | Start a fresh session (clears context) |
| `/compact` | Compress conversation context |
| `/status` | Show agent status and session info |
| `/cost` | Show token usage and cost for this session |
| `/restart` | Soft restart (preserves conversation history) |
| `/hardreset` | Hard restart (fresh session, loses history) |
| `/logs` | Show recent agent activity logs |
| `/help` | Show available commands and usage |
| `/fast` | Switch to fast output mode |
| `/slow` | Switch to standard output mode |
| `/review` | Review recent changes |
| `/update` | Re-sync Telegram commands with available skills |

### Skill Commands (auto-discovered)

All Claude Code skills from `.claude/skills/` are registered as Telegram commands. Sub-agent skills (containing `--` in name, e.g. `brand--aaker`) are excluded — they are routed through their chief.

Examples: `/commit`, `/spy`, `/deploy`, `/aiox_architect`, `/data_chief`

The command list auto-updates on agent boot. Use `/update` to refresh without restarting.

### How Commands Work

```
/new, /restart, /hardreset, /logs, /update
  → Handled by fast-checker.sh directly (no Claude involvement)

/compact, /status, /cost, /help, /fast, /slow, /review
  → Injected as Claude Code CLI commands (raw, no wrapper)

/commit, /spy, /aiox_architect, ...
  → Injected as skill invocations (underscore → hyphen conversion)
```

### Telegram API Limits

- Max 100 commands via `setMyCommands`
- Undocumented payload size limit (~11KB) — descriptions truncated to 50 chars
- Registration script: `core/scripts/register-telegram-commands.sh`

## Telegram UX Features

| Feature | Description |
|---------|-------------|
| Typing indicator | Bot shows "typing..." immediately when receiving a message |
| Emoji reaction | Bot reacts with eyes emoji on received messages |
| Message batching | 1.5s window to coalesce rapid messages into one injection |
| Auto-split | Messages >4096 chars split at last newline, keyboard on last chunk |
| Skill routing | `/command` → `/skill-name` with underscore-to-hyphen conversion |
| Progressive mode | `--progressive` flag edits previous message in-place (streaming UX) |
| Forum topics | `--topic <name>` routes messages to Telegram forum threads |
| Edit-in-place | `--edit <msg_id>` updates an existing message |
| Markdown fallback | Try Markdown first, auto-fallback to plain text if Telegram rejects |
| Rate limiting | 100ms between sends (20 msg/s, below Telegram's 30 msg/s limit) |

## Observability

### Structured Logging

All gateway scripts use `_logger.sh` for JSON Lines logging to `activity.log`:

```json
{"ts":"2026-04-05T14:30:45Z","agent":"prisma","event":"telegram_send","msg":"Message sent","chat_id":"123","latency_ms":"120"}
```

| Event | Description |
|-------|-------------|
| `telegram_send` | Message sent to Telegram |
| `auth_rejected` | Message from unauthorized user blocked |
| `permission_decision` | Permission hook result (allow/deny) |
| `error` | Send failure, API error |
| `dry_run` | DRY_RUN=1 mode — logged but not sent |

### Dry-Run Mode

Set `DRY_RUN=1` to log all sends without actually calling the Telegram API. Useful for testing.

### Security Audit

`check-telegram.sh` logs rejected messages from non-ALLOWED_USER senders with count and user ID.

## Adapter Message Schema

Adapters write normalized JSON to `channel-inbox/`. Schema: `core/schemas/adapter-message.schema.json`

```json
{
  "_source": "telegram",
  "_type": "message",
  "_timestamp": "2026-04-05T14:30:45Z",
  "platform": "telegram",
  "chat_id": "123456",
  "from": "Alan",
  "text": "Hello Oracle",
  "media": null,
  "callback_data": null
}
```

Supported types: `message`, `callback`, `photo`, `command`, `voice`, `document`

## Management

| Action | Command |
|--------|---------|
| Configure channel | `bash gateway/setup-channel.sh` |
| Deploy | `bash gateway/deploy-agent.sh` |
| Start | `bash gateway/enable-agent.sh prisma` |
| Stop | `bash gateway/disable-agent.sh prisma` |
| View session | `tmux attach -t crm-default-prisma` |
| Logs | `tail -f ~/.claude-remote/default/logs/prisma/activity.log` |
| Structured logs | `jq '.' ~/.claude-remote/default/logs/prisma/activity.log` |
| Skill status | `python3 gateway/skill-lifecycle.py status` |
| Run tests | `bash gateway/tests/run-tests.sh` |
| Web Chat | `python3 gateway/web-chat-server.py` |
| Sync commands (terminal) | `bash core/scripts/register-telegram-commands.sh $BOT_TOKEN <scan_dirs>` |
| Sync commands (Telegram) | Type `/update` in the chat |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Agent not starting | `launchctl list \| grep claude-remote` |
| Crashes repeatedly | Check `~/.claude-remote/default/logs/prisma/crashes.log` |
| Bot doesn't respond | Verify BOT_TOKEN: `curl https://api.telegram.org/bot<TOKEN>/getMe` |
| Trust prompt needed | `tmux attach -t crm-default-prisma` → approve → Ctrl-b d |
| Hooks not firing | Re-deploy: `bash gateway/deploy-agent.sh` |
| Web Chat won't connect | `curl http://localhost:8080/api/health` |
| Commands not in autocomplete | Type `/update` or check logs for `BOT_COMMANDS_TOO_MUCH` |
| `/restart` not working | fast-checker must be running; check `ps aux \| grep fast-checker` |
| Markdown rendering broken | Auto-fallback to plain text handles this; check `_markdown-sanitize.sh` |
| Messages from strangers | `check-telegram.sh` blocks + logs them; check `activity.log` for `auth_rejected` |

## Adding a New Channel (2-4 hours)

### Step 1: Create 3 bus scripts

```bash
core/bus/send-<channel>.sh        # Send message to platform API
core/bus/check-<channel>.sh       # Poll or receive messages
core/bus/hook-permission-<channel>.sh  # Approval UI (buttons or numbered reply)
```

### Step 2: Update 3 routers (add `case` statement)

```bash
core/bus/send-channel.sh
core/bus/check-channel.sh
core/bus/hook-permission-channel.sh
```

### Step 3: Create adapter lifecycle

```bash
adapters/<channel>/start.sh       # Start daemon/bridge
adapters/<channel>/health.sh      # Exit 0=HEALTHY, 1=DEGRADED, 2=DEAD
adapters/<channel>/stop.sh        # Graceful shutdown
```

### Step 4: Add E2E tests

Add test block in `tests/test-gateway-e2e.sh` (syntax + lifecycle check).

### Message Contract

All adapters normalize to `adapter-message.schema.json`:

```json
{
  "_source": "<channel>", "_type": "message",
  "_timestamp": "ISO-8601", "platform": "<channel>",
  "chat_id": "...", "from": "...", "text": "..."
}
```

Business logic (safety scanner, smart routing, session-persist, skill-lifecycle) never changes — adapters are fully isolated.

## Security (103 patterns)

**Pre-runtime safety** (30 patterns in `safety-scanner.sh`):
- Destructive: `rm -rf /`, `mkfs`, `dd to /dev/`, fork bomb, `shred`
- Privilege: `sudo`, SUID chmod, NOPASSWD, `pkexec`
- Persistence: `crontab`, `authorized_keys`, `systemctl enable`
- Exfiltration: `curl + $TOKEN`, reverse shells, `/etc/shadow`
- Database: `DROP TABLE`, `DELETE without WHERE`, `TRUNCATE`
- Self-harm: `pkill claude`, `killall agent-wrapper`

**Skill lifecycle** (73 patterns in `skill-lifecycle.py`):
- 8 categories: exfiltration, injection, destructive, persistence, network, obfuscation, privilege, credentials
- State machine: CANDIDATE → ACTIVE → PROVEN → STALE → ARCHIVED / DANGEROUS

**Infrastructure security:**
- Blocklist hook blocks `git push`/`gh pr create` (Agent Authority)
- ALLOWED_USER filter per channel — unauthorized messages logged
- Credential pool with rotation (no single API key dependency)
- Secrets in `~/.claude-remote/` only (outside repo, chmod 600)
- Input sanitization: FROM field stripped of newlines/special chars
- Callback data length validation (max 256 chars)
- Rate limiter: 100ms between Telegram sends (20 msg/s)

## License

Core scripts from [claude-remote-manager](https://github.com/grandamenium/claude-remote-manager) (MIT). See `LICENSE-CRM`.
