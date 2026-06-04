#!/usr/bin/env bash
# quick-commands.sh — Config-driven quick commands (bypass agent loop)
# Hermes pattern: config.quick_commands with type system
#
# Quick commands execute immediately without going through Claude Code.
# Defined in config.json under "quick_commands".
#
# Usage:
#   quick-commands.sh <agent> <command_name> [args...]
#   quick-commands.sh <agent> --list   # List available quick commands
#
# Config format (in config.json):
#   "quick_commands": {
#     "health": {"type": "exec", "command": "bash ../../gateway-health.sh", "description": "Gateway health check"},
#     "queue":  {"type": "exec", "command": "bash ../../core/bus/delivery-queue.sh status ${AGENT}", "description": "Queue status"},
#     "media-clean": {"type": "exec", "command": "bash ../../core/scripts/media-cleanup.sh ${AGENT}", "description": "Clean media cache"}
#   }
#
# Epic 110 / Story 110.29 Phase 6

set -uo pipefail

AGENT="${1:-${CRM_AGENT_NAME:-prisma}}"
CMD_NAME="${2:-}"
shift 2 2>/dev/null || true
CMD_ARGS="$*"

TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
CONFIG_FILE="${TEMPLATE_ROOT}/agents/${AGENT}/config.json"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "No config.json found for agent ${AGENT}" >&2
    exit 1
fi

# List mode
if [[ "${CMD_NAME}" == "--list" ]]; then
    COMMANDS=$(jq -r '.quick_commands // {} | to_entries[] | "\(.key)\t\(.value.description // "No description")"' "${CONFIG_FILE}" 2>/dev/null)
    if [[ -z "${COMMANDS}" ]]; then
        echo "No quick commands defined in config.json"
    else
        echo "Quick commands for ${AGENT}:"
        echo "${COMMANDS}" | while IFS=$'\t' read -r name desc; do
            printf "  /%s — %s\n" "$name" "$desc"
        done
    fi
    exit 0
fi

if [[ -z "${CMD_NAME}" ]]; then
    echo "Usage: quick-commands.sh <agent> <command_name> [args...]" >&2
    echo "       quick-commands.sh <agent> --list" >&2
    exit 1
fi

# Lookup command
CMD_DEF=$(jq -c ".quick_commands[\"${CMD_NAME}\"] // null" "${CONFIG_FILE}" 2>/dev/null)

if [[ "${CMD_DEF}" == "null" || -z "${CMD_DEF}" ]]; then
    echo "Unknown quick command: ${CMD_NAME}" >&2
    echo "Run with --list to see available commands" >&2
    exit 1
fi

CMD_TYPE=$(echo "${CMD_DEF}" | jq -r '.type // "exec"')
CMD_COMMAND=$(echo "${CMD_DEF}" | jq -r '.command // ""')
CMD_TIMEOUT=$(echo "${CMD_DEF}" | jq -r '.timeout // 30')

if [[ -z "${CMD_COMMAND}" ]]; then
    echo "Quick command '${CMD_NAME}' has no command defined" >&2
    exit 1
fi

# Resolve variables in command
CMD_COMMAND="${CMD_COMMAND//\$\{AGENT\}/${AGENT}}"
CMD_COMMAND="${CMD_COMMAND//\$\{CRM_ROOT\}/${CRM_ROOT}}"
CMD_COMMAND="${CMD_COMMAND//\$\{TEMPLATE_ROOT\}/${TEMPLATE_ROOT}}"

# Execute with timeout
case "${CMD_TYPE}" in
    exec)
        cd "${TEMPLATE_ROOT}" 2>/dev/null || true
        if command -v timeout &>/dev/null; then
            timeout "${CMD_TIMEOUT}" bash -c "${CMD_COMMAND} ${CMD_ARGS}" 2>&1
        else
            # macOS doesn't have timeout by default
            bash -c "${CMD_COMMAND} ${CMD_ARGS}" 2>&1 &
            CMD_PID=$!
            ( sleep "${CMD_TIMEOUT}" && kill "${CMD_PID}" 2>/dev/null ) &
            TIMER_PID=$!
            wait "${CMD_PID}" 2>/dev/null
            kill "${TIMER_PID}" 2>/dev/null || true
        fi
        ;;
    *)
        echo "Unknown command type: ${CMD_TYPE}" >&2
        exit 1
        ;;
esac
