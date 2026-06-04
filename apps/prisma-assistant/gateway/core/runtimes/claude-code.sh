#!/usr/bin/env bash
# claude-code.sh — Runtime driver for Claude Code CLI
#
# Implements the 12-function runtime interface for Claude Code (Anthropic).
# This is the reference driver — all functions are mandatory.
#
# CLI: claude (Claude Code CLI)
# Docs: https://docs.anthropic.com/en/docs/claude-code
#
# Epic 114 / Story 114.1

# --- 1. runtime_launch ---
# Start a fresh interactive session in the current directory.
# Args: <startup_prompt> [extra_flags...]
# Must run inside tmux (Claude Code requires PTY).
runtime_launch() {
    local prompt="$1"; shift
    local flags=("$@")
    local cmd=(claude)
    cmd+=(--dangerously-skip-permissions)

    # Model flag
    local mflag
    mflag=$(runtime_model_flag)
    [[ -n "${mflag}" ]] && cmd+=(${mflag})

    # System prompt file
    local spflag
    spflag=$(runtime_system_prompt_flag)
    [[ -n "${spflag}" ]] && cmd+=(${spflag})

    # Extra flags passed by agent-wrapper
    cmd+=("${flags[@]}")

    # Prompt is the last positional argument
    cmd+=("${prompt}")

    "${cmd[@]}"
}

# --- 2. runtime_continue ---
# Resume a previous session (preserves conversation history).
# Args: <continue_prompt> [extra_flags...]
runtime_continue() {
    local prompt="$1"; shift
    local flags=("$@")
    local cmd=(claude --continue --dangerously-skip-permissions)

    local mflag
    mflag=$(runtime_model_flag)
    [[ -n "${mflag}" ]] && cmd+=(${mflag})

    cmd+=("${flags[@]}")
    cmd+=("${prompt}")

    "${cmd[@]}"
}

# --- 3. runtime_print ---
# One-shot prompt: send prompt, get response, exit. No interactive session.
# Used for: isolated crons, quick-reply, one-off queries.
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

    local cmd=(claude --print -p "${prompt}")
    if [[ -n "${model_override}" ]]; then
        cmd+=(--model "${model_override}")
    elif [[ -n "${RUNTIME_MODEL:-}" ]]; then
        cmd+=(--model "${RUNTIME_MODEL}")
    fi

    "${cmd[@]}" 2>/dev/null
}

# --- 4. runtime_model_flag ---
# Returns the CLI flag for model selection.
# Reads RUNTIME_MODEL from environment (set by agent-wrapper from config.json).
runtime_model_flag() {
    if [[ -n "${RUNTIME_MODEL:-}" ]]; then
        echo "--model ${RUNTIME_MODEL}"
    fi
}

# --- 5. runtime_system_prompt_flag ---
# Returns the CLI flag for injecting the system prompt/bootstrap file.
# Reads RUNTIME_BOOTSTRAP_FILE from environment.
runtime_system_prompt_flag() {
    local bootstrap="${RUNTIME_BOOTSTRAP_FILE:-}"
    if [[ -n "${bootstrap}" && -f "${bootstrap}" ]]; then
        echo "--append-system-prompt-file ${bootstrap}"
    fi
}

# --- 6. runtime_settings_path ---
# Returns the path pattern for runtime-specific settings (hooks, permissions).
# Claude Code uses .claude/settings.json
runtime_settings_path() {
    echo ".claude/settings.json"
}

# --- 7. runtime_detect_busy ---
# Detect if the runtime is actively processing (busy) in a tmux session.
# Args: <tmux_session>
# Returns: 0 if busy, 1 if not busy (idle or unknown).
runtime_detect_busy() {
    local session="$1"
    local pane_content
    pane_content=$(tmux capture-pane -t "${session}:0.0" -p 2>/dev/null | tail -5)

    # Empty pane = tmux issue, not busy
    [[ -z "$pane_content" ]] && return 1

    # Claude Code shows spinner characters or "Thinking" when processing
    if echo "$pane_content" | grep -qE '[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]|Thinking|working'; then
        return 0  # busy
    fi

    # If we can see the idle prompt, definitely not busy
    if runtime_detect_idle "$session"; then
        return 1
    fi

    # Safe default: assume busy if unsure (prevents injection mid-response)
    return 0
}

# --- 8. runtime_detect_idle ---
# Detect if the runtime is waiting for input (idle).
# Args: <tmux_session>
# Returns: 0 if idle, 1 if not idle.
runtime_detect_idle() {
    local session="$1"
    local last_line
    last_line=$(tmux capture-pane -t "${session}:0.0" -p 2>/dev/null | tail -1)

    # Claude Code idle indicators: input prompt ">" or status bar "permissions"
    if echo "$last_line" | grep -qE '^\s*>|^\s*\$|permissions'; then
        return 0  # idle
    fi
    return 1
}

# --- 9. runtime_builtin_commands ---
# Returns space-separated list of built-in slash commands the runtime supports.
# These are injected raw (without message headers) by fast-checker.
runtime_builtin_commands() {
    echo "compact clear help cost login logout status doctor config bug init review fast slow"
}

# --- 10. runtime_cron_command ---
# Returns the command to create a recurring task (cron) in the runtime.
# Args: <interval> <prompt>
# Returns: the full command string, or "__EXTERNAL_CRON__" if runtime has no native crons.
runtime_cron_command() {
    local interval="$1"
    local prompt="$2"
    echo "/loop ${interval} ${prompt}"
}

# --- 11. runtime_permissions_flag ---
# Returns the CLI flag that enables headless/unattended permission mode.
runtime_permissions_flag() {
    echo "--dangerously-skip-permissions"
}

# --- 12. runtime_conversation_dir ---
# Returns the directory where the runtime stores conversation state.
# Args: <launch_dir> (the working directory of the agent)
runtime_conversation_dir() {
    local launch_dir="$1"
    # Claude Code stores conversations in ~/.claude/projects/-{path_with_dashes}
    echo "${HOME}/.claude/projects/-$(echo "${launch_dir}" | tr '/' '-')"
}
