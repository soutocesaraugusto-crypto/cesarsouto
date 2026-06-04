# Config Reference — Universal Agent Gateway

All agent configuration is in `agents/{agent}/config.json`.

## Runtime Configuration

```json
{
  "runtime": "claude-code",    // "claude-code" | "codex" | "api" | custom
  "model": "claude-opus-4-6",  // Model name for the runtime
  "agent_name": "prisma"
}
```

| Runtime | CLI | Models | Tools | Hooks | Continue |
|---------|-----|--------|-------|-------|----------|
| `claude-code` | `claude` | Claude family | Full (Bash, Read, Write, etc.) | Yes | `--continue` |
| `codex` | `codex` | OpenAI family (o4-mini, o3) | Full (sandboxed) | No | `resume --last` |
| `api` | None (Python daemon) | 200+ via OpenRouter | **None** (chat only) | No | N/A (persistent daemon) |

## Adapter Configuration

```json
{
  "adapter_mode": true,
  "channels": [
    {"type": "telegram", "enabled": true},
    {"type": "discord", "enabled": false},
    {"type": "web", "enabled": false, "port": 8080}
  ]
}
```

- `adapter_mode: false` (default): fast-checker polls Telegram directly (legacy mode)
- `adapter_mode: true`: adapters write to channel-inbox, fast-checker reads inbox only

## Smart Routing

```json
{
  "smart_routing": {
    "enabled": false,
    "model_quick": "claude-haiku-4-5",
    "model_deep": null
  }
}
```

- `model_quick`: Cheap model for greetings/confirmations (<20 words, no code)
- `model_deep`: Premium model for architecture tasks (null = use main model)
- Classification: regex-based (<50ms), no LLM call

## Cron Configuration

```json
{
  "crons": [
    {"name": "daily-status", "interval": "24h", "prompt": "...", "isolated": true, "model": "haiku"},
    {"name": "inbox-check", "interval": "5m", "prompt": "...", "isolated": false}
  ]
}
```

- `isolated: true`: Runs via `runtime_print()` in subprocess. Zero context pollution. Can use cheaper model.
- `isolated: false`: Runs via `/loop` in main session. Has access to tools. Consumes context.

## Session Policy

```json
{
  "session_policy": {
    "mode": "idle_and_daily",
    "idle_minutes": 1440,
    "daily_reset_hour": 4,
    "notify": true
  }
}
```

- `mode`: "never", "idle", "daily", "idle_and_daily"
- Agent auto-resets after idle timeout or at daily hour

## Memory Configuration

```json
{
  "memory": {
    "providers": ["session-recall"],
    "prefetch_on_message": true
  }
}
```

Providers implement 3 lifecycle hooks: `prefetch`, `sync_turn`, `on_session_end`.

## Credential Pool

Supports multiple API keys with automatic rotation:

```bash
# .env file
BOT_TOKEN_1=xxx
BOT_TOKEN_2=yyy
ANTHROPIC_API_KEY_1=sk-ant-xxx
ANTHROPIC_API_KEY_2=sk-ant-yyy
```

Single key (backward compat): `BOT_TOKEN=xxx` works without `_1`/`_2`.

## Quick Commands

```json
{
  "quick_commands": {
    "health": {"type": "exec", "command": "bash ../../gateway-health.sh", "timeout": 30},
    "queue": {"type": "exec", "command": "bash ../../core/bus/delivery-queue.sh status ${AGENT}"}
  }
}
```

Executed without going through the agent — instant results.

## Adding a New Runtime

1. Copy `core/runtimes/custom.sh.template` to `core/runtimes/my-runtime.sh`
2. Implement all 16 interface functions
3. Set `"runtime": "my-runtime"` in config.json
4. Test: start agent, send message, verify response

See `core/runtimes/claude-code.sh` as reference implementation.

## Adding a New Channel Adapter

1. Create `adapters/my-channel/start.sh`, `stop.sh`, `health.sh`
2. Create `core/bus/send-my-channel.sh`
3. Add to config.json channels array
4. Set `adapter_mode: true`

See `adapters/telegram/` as reference.
