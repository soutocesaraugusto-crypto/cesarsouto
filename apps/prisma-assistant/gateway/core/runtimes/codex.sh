#!/usr/bin/env bash
# codex.sh — Runtime driver for OpenAI Codex CLI
#
# Implements the 12-function runtime interface for Codex CLI.
# Codex is OpenAI's coding agent CLI (codex exec, codex resume).
#
# Key differences from Claude Code:
#   - No native /loop crons → use external cron-executor
#   - System prompt via CODEX_INSTRUCTIONS.md in cwd (auto-read, not CLI flag)
#   - Continue session via `codex resume --last`
#   - Headless: --dangerously-bypass-approvals-and-sandbox
#   - Non-interactive: `codex exec <prompt>`
#   - --no-alt-screen needed for tmux compatibility
#
# CLI reference: codex --help (verified 2026-04-05)
# Epic 114 / Story 114.2

# --- 1. runtime_launch ---
# Start a fresh interactive Codex session in tmux.
# Args: <startup_prompt> [extra_flags...]
# CODEX_INSTRUCTIONS.md is auto-read from cwd (no explicit flag needed).
runtime_launch() {
    local prompt="$1"; shift
    local flags=("$@")
    local cmd=(codex)
    cmd+=(--dangerously-bypass-approvals-and-sandbox)
    cmd+=(--no-alt-screen)  # Required for tmux paste-buffer injection

    # Model flag
    if [[ -n "${RUNTIME_MODEL:-}" ]]; then
        cmd+=(-c "model=\"${RUNTIME_MODEL}\"")
    fi

    # Extra flags (e.g., --add-dir, -C)
    cmd+=("${flags[@]}")

    # Prompt is the last positional argument
    cmd+=("${prompt}")

    "${cmd[@]}"
}

# --- 2. runtime_continue ---
# Resume the most recent Codex session.
# Args: <continue_prompt> [extra_flags...]
runtime_continue() {
    local prompt="$1"; shift
    local flags=("$@")
    local cmd=(codex resume --last)
    cmd+=(--dangerously-bypass-approvals-and-sandbox)
    cmd+=(--no-alt-screen)

    if [[ -n "${RUNTIME_MODEL:-}" ]]; then
        cmd+=(-c "model=\"${RUNTIME_MODEL}\"")
    fi

    cmd+=("${flags[@]}")
    cmd+=("${prompt}")

    "${cmd[@]}"
}

# --- 3. runtime_print ---
# One-shot non-interactive execution. Used for isolated crons and quick-reply.
# Args: <prompt> [--model <model_override>]
# Returns: stdout with the response text.
runtime_print() {
    local prompt="$1"; shift
    local model_override=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --model) model_override="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local cmd=(codex exec)
    cmd+=(--dangerously-bypass-approvals-and-sandbox)

    if [[ -n "${model_override}" ]]; then
        cmd+=(-c "model=\"${model_override}\"")
    elif [[ -n "${RUNTIME_MODEL:-}" ]]; then
        cmd+=(-c "model=\"${RUNTIME_MODEL}\"")
    fi

    cmd+=("${prompt}")

    "${cmd[@]}" 2>/dev/null
}

# --- 4. runtime_model_flag ---
# Returns the CLI config override for model selection.
runtime_model_flag() {
    if [[ -n "${RUNTIME_MODEL:-}" ]]; then
        echo "-c model=\"${RUNTIME_MODEL}\""
    fi
}

# --- 5. runtime_system_prompt_flag ---
# Codex auto-reads CODEX_INSTRUCTIONS.md from cwd — no explicit flag needed.
# Returns empty string (bootstrap file must be placed in working directory).
runtime_system_prompt_flag() {
    # Codex convention: auto-reads CODEX_INSTRUCTIONS.md from cwd
    # No CLI flag required — the file just needs to exist
    echo ""
}

# --- 6. runtime_settings_path ---
# Returns the path to Codex's config file.
runtime_settings_path() {
    echo "${HOME}/.codex/config.toml"
}

# --- 7. runtime_detect_busy ---
# Detect if Codex is actively processing in a tmux session.
# Args: <tmux_session>
# Codex TUI shows "Running", "Executing", progress bars when busy.
# With --no-alt-screen, output is inline in the scrollback.
runtime_detect_busy() {
    local session="$1"
    local pane_content
    pane_content=$(tmux capture-pane -t "${session}:0.0" -p 2>/dev/null | tail -8)

    [[ -z "$pane_content" ]] && return 1

    # Codex busy indicators (with --no-alt-screen)
    if echo "$pane_content" | grep -qEi 'Running|Executing|Searching|Thinking|[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]|\.\.\.'; then
        return 0  # busy
    fi

    if runtime_detect_idle "$session"; then
        return 1
    fi

    # Safe default: assume busy
    return 0
}

# --- 8. runtime_detect_idle ---
# Detect if Codex is waiting for user input.
# Args: <tmux_session>
runtime_detect_idle() {
    local session="$1"
    local last_line
    last_line=$(tmux capture-pane -t "${session}:0.0" -p 2>/dev/null | tail -1)

    # Codex idle indicators (with --no-alt-screen):
    # The prompt shows ">" or the session shows awaiting input
    if echo "$last_line" | grep -qE '^\s*>|^\s*\$|codex>|Enter a prompt'; then
        return 0  # idle
    fi
    return 1
}

# --- 9. runtime_builtin_commands ---
# Codex has no built-in slash commands like /loop, /compact, etc.
# Returns empty string.
runtime_builtin_commands() {
    echo ""
}

# --- 10. runtime_cron_command ---
# Codex has no native cron/loop support.
# Returns __EXTERNAL_CRON__ to signal cron-executor.sh to use runtime_print.
runtime_cron_command() {
    local interval="$1"
    local prompt="$2"
    echo "__EXTERNAL_CRON__"
}

# --- 11. runtime_permissions_flag ---
# Returns the flag for fully headless/unattended mode.
runtime_permissions_flag() {
    echo "--dangerously-bypass-approvals-and-sandbox"
}

# --- 12. runtime_conversation_dir ---
# Returns where Codex stores conversation/session state.
# Args: <launch_dir>
# Codex stores sessions in ~/.codex/sessions/ (indexed by UUID, not by path).
runtime_conversation_dir() {
    local launch_dir="$1"
    echo "${HOME}/.codex/sessions"
}
