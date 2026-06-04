#!/usr/bin/env bash
# runtime.sh — Runtime Abstraction Layer (facade)
#
# Loads the correct runtime driver based on config.json "runtime" field.
# All agent orchestration scripts (agent-wrapper.sh, fast-checker.sh, etc.)
# source THIS file and call runtime_* functions instead of invoking CLI directly.
#
# Usage:
#   source "$(dirname "$0")/../runtimes/runtime.sh"
#   runtime_launch "${STARTUP_PROMPT}"
#   runtime_continue "${CONTINUE_PROMPT}"
#   RESULT=$(runtime_print "What is 2+2?")
#
# Config:
#   config.json: { "runtime": "claude-code" }  (default if field missing)
#   Drivers live in: core/runtimes/{runtime_type}.sh
#
# Contract: every driver MUST implement all 12 functions listed in RUNTIME_INTERFACE.
# If a driver is missing any function, this facade will exit with a clear error.
#
# Epic 114 / Story 114.1

set -uo pipefail

# --- Resolve paths ---
_RUNTIME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_RUNTIME_TEMPLATE_ROOT="$(cd "${_RUNTIME_DIR}/../.." && pwd)"

# --- Determine runtime type from config ---
_resolve_runtime_type() {
    local config_file="${_RUNTIME_AGENT_DIR:-${_RUNTIME_TEMPLATE_ROOT}/agents/${CRM_AGENT_NAME:-prisma}}/config.json"
    local runtime_type="claude-code"

    if [[ -f "${config_file}" ]]; then
        local cfg_runtime
        cfg_runtime=$(jq -r '.runtime // "claude-code"' "${config_file}" 2>/dev/null || echo "claude-code")
        # Support both string and object forms
        if [[ "${cfg_runtime}" == "null" || -z "${cfg_runtime}" ]]; then
            runtime_type="claude-code"
        else
            runtime_type="${cfg_runtime}"
        fi
    fi

    echo "${runtime_type}"
}

# --- Load driver ---
RUNTIME_TYPE="${RUNTIME_TYPE:-$(_resolve_runtime_type)}"
_DRIVER_FILE="${_RUNTIME_DIR}/${RUNTIME_TYPE}.sh"

if [[ ! -f "${_DRIVER_FILE}" ]]; then
    echo "FATAL: Runtime driver not found: ${_DRIVER_FILE}" >&2
    echo "Available drivers:" >&2
    ls -1 "${_RUNTIME_DIR}"/*.sh 2>/dev/null | grep -v runtime.sh | grep -v custom.sh.template | sed 's/.*\//  /' | sed 's/\.sh$//' >&2
    exit 1
fi

source "${_DRIVER_FILE}"

# --- Validate interface contract ---
RUNTIME_INTERFACE=(
    runtime_launch
    runtime_continue
    runtime_print
    runtime_model_flag
    runtime_system_prompt_flag
    runtime_settings_path
    runtime_detect_busy
    runtime_detect_idle
    runtime_builtin_commands
    runtime_cron_command
    runtime_permissions_flag
    runtime_conversation_dir
)

_missing=()
for fn in "${RUNTIME_INTERFACE[@]}"; do
    if ! declare -f "${fn}" > /dev/null 2>&1; then
        _missing+=("${fn}")
    fi
done

if [[ ${#_missing[@]} -gt 0 ]]; then
    echo "FATAL: Runtime driver '${RUNTIME_TYPE}' is missing required functions:" >&2
    printf '  - %s\n' "${_missing[@]}" >&2
    echo "" >&2
    echo "See core/runtimes/custom.sh.template for the full interface contract." >&2
    exit 1
fi

# Export runtime type for downstream scripts
export RUNTIME_TYPE
