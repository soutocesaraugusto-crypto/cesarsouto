#!/usr/bin/env bash
# api-openrouter.sh — Runtime driver for OpenRouter API (no CLI dependency)
#
# Unlike claude-code.sh and codex.sh, this driver does NOT use tmux or PTY.
# It runs a Python daemon (api-client.py) that:
#   - Polls channel-inbox/ for messages
#   - Calls OpenRouter API (OpenAI-compatible)
#   - Responds via send-channel.sh
#   - Manages conversation history in JSONL
#
# Enables 200+ models: Claude, GPT-4o, Llama, DeepSeek, Gemini, Qwen, etc.
# Only requires: Python 3 + OPENROUTER_API_KEY
#
# Epic 114 / Story 114.3

_API_DRIVER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_API_DAEMON="${_API_DRIVER_DIR}/api-client.py"
_API_TEMPLATE_ROOT="$(cd "${_API_DRIVER_DIR}/../.." && pwd)"

# --- 1. runtime_launch ---
# Start the API daemon in the background. No tmux needed.
# Args: <startup_prompt> [extra_flags...] (prompt is used as initial greeting trigger)
runtime_launch() {
    local prompt="$1"; shift
    local agent="${CRM_AGENT_NAME:-prisma}"
    local instance="${CRM_INSTANCE_ID:-default}"
    local log_dir="${HOME}/.claude-remote/${instance}/logs/${agent}"
    mkdir -p "${log_dir}"

    # Export config for daemon
    export CRM_AGENT_NAME="${agent}"
    export CRM_INSTANCE_ID="${instance}"
    export CRM_TEMPLATE_ROOT="${_API_TEMPLATE_ROOT}"
    export OPENROUTER_MODEL="${RUNTIME_MODEL:-anthropic/claude-3.5-haiku}"

    # Start daemon
    nohup python3 "${_API_DAEMON}" >> "${log_dir}/api-client.log" 2>&1 &
    local daemon_pid=$!
    echo "${daemon_pid}" > "${log_dir}/api-client-${agent}.pid"

    echo "API daemon started (PID ${daemon_pid}, model: ${OPENROUTER_MODEL})"

    # If there's a startup prompt, write it to inbox so daemon processes it
    if [[ -n "${prompt}" && "${prompt}" != "SESSION"* ]]; then
        local inbox="${HOME}/.claude-remote/${instance}/channel-inbox/${agent}"
        mkdir -p "${inbox}"
        local ts_ms
        ts_ms=$(date +%s%N 2>/dev/null | cut -c1-13 || date +%s)
        cat > "${inbox}/${ts_ms}-startup-init.json" << STARTUP_MSG
{"_source":"system","_type":"message","platform":"system","chat_id":"${CHAT_ID:-system}","from":"system","text":"${prompt}"}
STARTUP_MSG
    fi

    # Keep the shell alive so agent-wrapper doesn't think we exited
    # (agent-wrapper monitors this process, not the daemon)
    wait "${daemon_pid}" 2>/dev/null || true
}

# --- 2. runtime_continue ---
# For API mode, "continue" just restarts the daemon (history is in JSONL, not in process).
# Args: <continue_prompt> [extra_flags...]
runtime_continue() {
    runtime_launch "$@"
}

# --- 3. runtime_print ---
# One-shot API call. No daemon needed.
# Args: <prompt> [--model <model_override>]
runtime_print() {
    local prompt="$1"; shift
    local model_flag=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --model) model_flag="--model $2"; shift 2 ;;
            *) shift ;;
        esac
    done

    export CRM_AGENT_NAME="${CRM_AGENT_NAME:-prisma}"
    export CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
    export CRM_TEMPLATE_ROOT="${_API_TEMPLATE_ROOT}"
    export OPENROUTER_MODEL="${RUNTIME_MODEL:-anthropic/claude-3.5-haiku}"

    python3 "${_API_DAEMON}" --once "${prompt}" ${model_flag}
}

# --- 4. runtime_model_flag ---
# API mode uses env var, not CLI flag. Returns empty (model set via RUNTIME_MODEL env).
runtime_model_flag() {
    echo ""
}

# --- 5. runtime_system_prompt_flag ---
# API mode loads system prompt in Python (from API-AGENT.md or SOUL.md). No CLI flag.
runtime_system_prompt_flag() {
    echo ""
}

# --- 6. runtime_settings_path ---
# No settings file (API mode has no hooks/permissions system).
runtime_settings_path() {
    echo ""
}

# --- 7. runtime_detect_busy ---
# Check if the daemon has an in-flight API request.
# Args: <tmux_session> (ignored — no tmux in API mode)
# For simplicity, check if PID is alive. Fine-grained busy detection not needed
# because the daemon handles its own message queue.
runtime_detect_busy() {
    # API daemon manages its own queue — never "busy" from fast-checker's perspective.
    # Messages go to channel-inbox, daemon picks them up asynchronously.
    return 1  # never busy (daemon self-manages)
}

# --- 8. runtime_detect_idle ---
# API daemon is always "idle" (ready to accept messages via inbox).
runtime_detect_idle() {
    return 0  # always idle
}

# --- 9. runtime_builtin_commands ---
# No built-in commands (no CLI TUI).
runtime_builtin_commands() {
    echo ""
}

# --- 10. runtime_cron_command ---
# No native cron support. Use external cron-executor.
runtime_cron_command() {
    echo "__EXTERNAL_CRON__"
}

# --- 11. runtime_permissions_flag ---
# No permission system in API mode.
runtime_permissions_flag() {
    echo ""
}

# --- 12. runtime_conversation_dir ---
# Conversations stored in JSONL files.
runtime_conversation_dir() {
    local agent="${CRM_AGENT_NAME:-prisma}"
    local instance="${CRM_INSTANCE_ID:-default}"
    echo "${HOME}/.claude-remote/${instance}/state/${agent}/conversations"
}
