# Runtime Abstraction Audit — `claude` References in Gateway Scripts

**Story:** 114.1 — Task T6
**Date:** 2026-04-05
**Total files with `claude` references:** 42

## Classification

**(a) CLI invocation** — MUST refactor to use `runtime_*` functions
**(b) Path/brand/doc reference** — OK, not CLI coupling

---

## (a) CLI Invocations — MUST REFACTOR (4 files)

| File | Line(s) | Reference | Target runtime_* |
|------|---------|-----------|-------------------|
| `core/scripts/agent-wrapper.sh` | 315 | `exec claude "${ARGS[@]}" '${STARTUP_PROMPT}'` | `runtime_launch` |
| `core/scripts/agent-wrapper.sh` | 320 | `claude --continue --dangerously-skip-permissions ...` | `runtime_continue` |
| `core/scripts/agent-wrapper.sh` | 396 | `claude --continue --dangerously-skip-permissions ...` | `runtime_continue` |
| `core/bus/self-restart.sh` | 75 | `claude --continue --dangerously-skip-permissions ...` | `runtime_continue` |
| `install.sh` | 25 | `claude --version` | `runtime_check_installed` (new helper, or keep as-is — install is pre-runtime) |
| `setup.sh` | 25 | `claude --version` | Same as install.sh — pre-runtime check |

**Note:** `install.sh` and `setup.sh` run BEFORE any agent exists, so they validate CLI availability. These can either:
- Stay as-is (they're setup scripts, not runtime scripts)
- Be updated to check for the configured runtime binary

**Recommendation:** Keep install.sh/setup.sh as-is (they check if ANY runtime CLI exists). Refactor agent-wrapper.sh (3 refs) and self-restart.sh (1 ref).

---

## (b) Path/Brand/Doc References — OK (38 files)

These reference `.claude/` paths, `claude-remote` names, or `claude` in comments/docs. Not CLI coupling.

| File | Type of reference |
|------|-------------------|
| `core/runtimes/claude-code.sh` | **Driver file** — expected to contain `claude` CLI calls |
| `core/runtimes/runtime.sh` | References `claude-code` as default driver name |
| `core/scripts/fast-checker.sh` | `.claude/settings.json` path, `claude` in comments. **BUT** also has `is_claude_busy()` function name — rename to `runtime_detect_busy` wrapper |
| `core/bus/hook-permission-telegram.sh` | `.claude/` path references |
| `core/bus/hook-planmode-telegram.sh` | `.claude/` path references |
| `core/bus/_logger.sh` | `CRM_ROOT` / `claude-remote` path |
| `core/bus/_secret-validator.sh` | `.claude/` path references |
| `core/bus/_fatal-error.sh` | Comments only |
| `core/bus/check-telegram.sh` | `claude-remote` path |
| `core/bus/check-inbox.sh` | `claude-remote` path |
| `core/bus/ack-inbox.sh` | `claude-remote` path |
| `core/bus/send-message.sh` | `claude-remote` path |
| `core/bus/delivery-queue.sh` | `claude-remote` path |
| `core/bus/deliver-multi.sh` | `claude-remote` path |
| `core/bus/write-channel-inbox.sh` | `claude-remote` path |
| `core/bus/hard-restart.sh` | `claude-remote` path, comments |
| `core/scripts/crash-alert.sh` | `claude-remote` path |
| `core/scripts/generate-launchd.sh` | `com.claude-remote` plist name, PATH detection for `claude` binary |
| `core/scripts/media-cleanup.sh` | `claude-remote` path |
| `core/scripts/inbox-cleanup.sh` | `claude-remote` path |
| `core/scripts/pre-restart-handoff.sh` | `claude-remote` path |
| `core/scripts/register-telegram-commands.sh` | `.claude/skills` path |
| `core/scripts/quick-commands.sh` | `claude-remote` path |
| `core/scripts/session-policies.sh` | `claude-remote` path |
| `core/webhook/setup-webhook.sh` | `claude-remote` path |
| `core/webhook/teardown-webhook.sh` | `claude-remote` path |
| `gateway-health.sh` | `claude-remote` path |
| `adapters/telegram/health.sh` | `claude-remote` path |
| `adapters/telegram/start.sh` | `claude-remote` path |
| `deploy-agent.sh` | `.claude/` path references |
| `enable-agent.sh` | `com.claude-remote` plist |
| `disable-agent.sh` | `com.claude-remote` plist |
| `setup-channel.sh` | `claude-remote` path |
| `uninstall.sh` | `claude-remote` path, plist |
| `session-persist.sh` | `claude-remote` path |
| `skill-candidate-detect.sh` | `.claude/` path |
| `artifact-tracker.sh` | `claude-remote` path |
| `tests/run-tests.sh` | Test references |

---

## Special Cases

### `generate-launchd.sh`
Contains PATH detection: `command -v claude` to find the binary path for launchd plist. This is runtime-specific but runs at enable-time, not execution-time. **Decision:** Update in 114.2 when adding Codex support (needs to detect `codex` binary too).

### `fast-checker.sh`
Has `is_claude_busy()` function that should be renamed/wrapped to call `runtime_detect_busy()`. This is a T4 task.

---

## Summary

| Category | Count | Action |
|----------|-------|--------|
| (a) CLI invocations to refactor | **4 files, 6 lines** | T3 (agent-wrapper), T5 (self-restart) |
| (a) Pre-runtime checks (install/setup) | **2 files, 2 lines** | Keep as-is (pre-runtime context) |
| (b) Path/brand references | **36 files** | No action needed |
| Driver file (expected) | **1 file** | No action (this IS the driver) |
| Facade (expected) | **1 file** | No action |

**Conclusion:** The refactoring scope is manageable — only 4 files need CLI call changes (6 total lines). The 36 path-reference files are fine as-is.
