# Universal Agent Gateway — Architecture

## Overview

The Universal Agent Gateway is a **runtime-agnostic message gateway** that connects messaging platforms (Telegram, Discord, Web) to AI agent runtimes (Claude Code, Codex, OpenRouter API).

```
Messaging Platforms          Gateway Core              Agent Runtimes
┌──────────┐              ┌──────────────┐          ┌────────────────┐
│ Telegram │──adapter──→  │ channel-inbox │──fast──→ │  Claude Code   │
│ Discord  │──adapter──→  │              │ checker  │  (tmux + PTY)  │
│ Web Chat │──adapter──→  │              │          ├────────────────┤
│ Webhook  │──receiver─→  │              │          │  OpenAI Codex  │
└──────────┘              └──────────────┘          │  (tmux + PTY)  │
                                │                    ├────────────────┤
                                │                    │  API-OpenRouter │
                                └──send-channel.sh─→ │  (Python daemon)│
                                                     └────────────────┘
```

## Key Design Decisions

### 1. Runtime Driver Pattern
All CLI-specific logic lives in **driver files** (`core/runtimes/*.sh`). The facade (`runtime.sh`) loads the correct driver based on `config.json` and validates a **12-function contract**. No code outside the drivers references any specific CLI.

### 2. Channel-Inbox Normalization
All inbound messages (from any platform) pass through `channel-inbox/` as normalized JSON conforming to `core/schemas/adapter-message.schema.json`. This decouples platforms from runtimes completely.

### 3. File-Based Everything
Messages, conversations, queues, and state are file-based (JSON, JSONL). No database required for core operation. SQLite used only for session-recall (optional).

### 4. Backward Compatibility as Non-Negotiable
Every new feature must work with existing configs. Missing `"runtime"` field defaults to `claude-code`. Missing `"adapter_mode"` defaults to `false` (legacy polling).

## Runtime Comparison

| Capability | claude-code | codex | api-openrouter |
|-----------|-------------|-------|----------------|
| Process model | tmux + PTY | tmux + PTY | Python daemon |
| Tools (Bash, Read, Write) | Yes | Yes | No (chat-only) |
| Session continue | `--continue` | `resume --last` | JSONL history |
| Native crons | `/loop` | None | None |
| Hooks support | Yes (.claude/settings.json) | No | No |
| Models | Claude family | OpenAI family | 200+ via OpenRouter |
| One-shot mode | `--print -p` | `exec` | `--once` (Python) |

## Directory Structure

```
gateway/
├── core/
│   ├── runtimes/           # Runtime abstraction layer
│   │   ├── runtime.sh      # Facade (loads driver, validates contract)
│   │   ├── claude-code.sh   # Claude Code CLI driver
│   │   ├── codex.sh        # OpenAI Codex CLI driver
│   │   ├── api-openrouter.sh # API driver wrapper
│   │   ├── api-client.py   # API Python daemon
│   │   ├── mock.sh         # Mock driver (testing)
│   │   └── custom.sh.template # Guide for new drivers
│   ├── bus/                # Message bus scripts
│   │   ├── send-telegram.sh
│   │   ├── send-channel.sh  # Platform router
│   │   ├── delivery-queue.sh # Persistent retry queue
│   │   └── write-channel-inbox.sh # Normalized inbox writer
│   ├── scripts/            # Orchestration
│   │   ├── agent-wrapper.sh # Lifecycle manager
│   │   ├── fast-checker.sh  # Message injector
│   │   └── crash-alert.sh
│   ├── webhook/            # Webhook receiver
│   │   ├── webhook-receiver.py
│   │   ├── setup-webhook.sh
│   │   └── teardown-webhook.sh
│   └── schemas/            # JSON schemas
│       ├── adapter-message.schema.json
│       └── config.schema.json
├── adapters/               # Platform adapters
│   ├── telegram/
│   ├── discord/
│   └── web/
├── tests/                  # Test suites
│   ├── run-tests.sh        # Unit tests (92+)
│   ├── test-runtime-compat.sh # Runtime smoke (51)
│   └── test-gateway-e2e.sh # E2E tests (34)
├── config.json.template    # Claude Code config (default)
├── config.json.codex-example
├── config.json.api-example
├── CLAUDE.md.template      # Claude Code bootstrap
├── CODEX_INSTRUCTIONS.md.template # Codex bootstrap
└── API-AGENT.md.template   # API mode bootstrap
```

## Adding a New Runtime

1. Copy `core/runtimes/custom.sh.template` to `core/runtimes/my-runtime.sh`
2. Implement all 12 functions (the template documents each one)
3. Set `"runtime": "my-runtime"` in your agent's `config.json`
4. Create a bootstrap template (`MY-RUNTIME-INSTRUCTIONS.md.template`)
5. Run tests: `bash tests/test-runtime-compat.sh`

## Test Coverage

| Suite | Tests | What |
|-------|-------|------|
| `run-tests.sh` | 92+ | Syntax, session persist, skill lifecycle, security patterns |
| `test-runtime-compat.sh` | 51 | All drivers load, 12 functions per driver, config handling |
| `test-gateway-e2e.sh` | 34 | Mock runtime, delivery queue, channel-inbox, webhook, config schema |
| **Total** | **177+** | |
