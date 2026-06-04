#!/usr/bin/env bash
# memory-router.sh — Memory provider orchestrator
# Routes lifecycle hooks (prefetch, sync_turn, on_session_end) to registered providers.
#
# Hermes reference: plugins/memory/ — pluggable provider ABC with lifecycle hooks.
#
# Usage:
#   memory-router.sh prefetch <agent> "<query>"      → returns merged context
#   memory-router.sh sync_turn <agent> "<user>" "<assistant>"  → persists key info
#   memory-router.sh on_session_end <agent>           → extracts long-term memories
#   memory-router.sh status <agent>                   → shows provider status
#
# Providers registered in config.json: "memory": {"providers": ["session-recall"]}
# Each provider implements: prefetch.sh, sync_turn.sh, on_session_end.sh
#
# Epic 114 / Story 114.9

set -uo pipefail

ACTION="${1:-status}"
AGENT="${2:-${CRM_AGENT_NAME:-prisma}}"
shift 2 2>/dev/null || true

TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
CONFIG_FILE="${TEMPLATE_ROOT}/agents/${AGENT}/config.json"
BUS_DIR="${TEMPLATE_ROOT}/core/bus"
MEMORY_DIR="${TEMPLATE_ROOT}/core/memory"

source "${BUS_DIR}/_logger.sh" 2>/dev/null || true

# Load provider list from config
PROVIDERS=()
if [[ -f "${CONFIG_FILE}" ]]; then
    while IFS= read -r p; do
        [[ -n "$p" ]] && PROVIDERS+=("$p")
    done < <(jq -r '.memory.providers // [] | .[]' "${CONFIG_FILE}" 2>/dev/null)
fi

if [[ ${#PROVIDERS[@]} -eq 0 ]]; then
    [[ "${ACTION}" == "status" ]] && echo "No memory providers configured"
    exit 0
fi

# Provider timeout (ms → seconds)
PROVIDER_TIMEOUT=5

case "${ACTION}" in
    prefetch)
        QUERY="${1:-}"
        RESULTS=""
        for provider in "${PROVIDERS[@]}"; do
            PROVIDER_SCRIPT="${MEMORY_DIR}/providers/${provider}/prefetch.sh"
            if [[ -f "${PROVIDER_SCRIPT}" ]]; then
                RESULT=$(timeout "${PROVIDER_TIMEOUT}" bash "${PROVIDER_SCRIPT}" "${AGENT}" "${QUERY}" 2>/dev/null) || RESULT=""
                [[ -n "${RESULT}" ]] && RESULTS+="${RESULT}"$'\n'
            fi
        done
        printf '%s' "${RESULTS}"
        ;;

    sync_turn)
        USER_MSG="${1:-}"
        ASST_MSG="${2:-}"
        for provider in "${PROVIDERS[@]}"; do
            PROVIDER_SCRIPT="${MEMORY_DIR}/providers/${provider}/sync_turn.sh"
            if [[ -f "${PROVIDER_SCRIPT}" ]]; then
                bash "${PROVIDER_SCRIPT}" "${AGENT}" "${USER_MSG}" "${ASST_MSG}" &>/dev/null &
            fi
        done
        # Async — don't wait
        ;;

    on_session_end)
        for provider in "${PROVIDERS[@]}"; do
            PROVIDER_SCRIPT="${MEMORY_DIR}/providers/${provider}/on_session_end.sh"
            if [[ -f "${PROVIDER_SCRIPT}" ]]; then
                timeout "${PROVIDER_TIMEOUT}" bash "${PROVIDER_SCRIPT}" "${AGENT}" 2>/dev/null || {
                    crm_log "memory_error" "Provider ${provider} on_session_end failed" "provider=${provider}" 2>/dev/null
                }
            fi
        done
        ;;

    status)
        echo "Memory providers for ${AGENT}:"
        for provider in "${PROVIDERS[@]}"; do
            PROVIDER_DIR="${MEMORY_DIR}/providers/${provider}"
            if [[ -d "${PROVIDER_DIR}" ]]; then
                HAS_PREFETCH=$([[ -f "${PROVIDER_DIR}/prefetch.sh" ]] && echo "yes" || echo "no")
                HAS_SYNC=$([[ -f "${PROVIDER_DIR}/sync_turn.sh" ]] && echo "yes" || echo "no")
                HAS_END=$([[ -f "${PROVIDER_DIR}/on_session_end.sh" ]] && echo "yes" || echo "no")
                echo "  ${provider}: prefetch=${HAS_PREFETCH} sync_turn=${HAS_SYNC} on_session_end=${HAS_END}"
            else
                echo "  ${provider}: NOT INSTALLED (${PROVIDER_DIR} missing)"
            fi
        done
        ;;

    *)
        echo "Usage: memory-router.sh {prefetch|sync_turn|on_session_end|status} <agent> [args...]" >&2
        exit 1
        ;;
esac
