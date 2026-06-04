#!/usr/bin/env bash
# deliver-multi.sh — Multi-target message delivery router
# Hermes pattern: DeliveryRouter.resolve_targets() + deliver()
#
# Sends a message to multiple targets simultaneously.
# Target specs: "origin", "local", "telegram:<chat_id>", "discord:<chat_id>", "telegram" (home channel)
#
# Usage:
#   deliver-multi.sh <agent> "<message>" "telegram:123" "discord:456" "local"
#   deliver-multi.sh <agent> "<message>" "origin"  # reply to source (requires ORIGIN_PLATFORM + ORIGIN_CHAT_ID env)
#
# Epic 110 / Story 110.29 Phase 4

set -uo pipefail

AGENT="${1:-${CRM_AGENT_NAME:-prisma}}"
MESSAGE="${2:-}"
shift 2 2>/dev/null || true
TARGETS=("$@")

if [[ -z "${MESSAGE}" || ${#TARGETS[@]} -eq 0 ]]; then
    echo "Usage: deliver-multi.sh <agent> \"<message>\" target1 [target2 ...]" >&2
    echo "Targets: origin, local, telegram[:<chat_id>], discord[:<chat_id>], web[:<port>]" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
LOG_DIR="${CRM_ROOT}/logs/${AGENT}"
OUTPUT_DIR="${CRM_ROOT}/delivery-output/${AGENT}"

mkdir -p "${LOG_DIR}" "${OUTPUT_DIR}" 2>/dev/null || true

source "${SCRIPT_DIR}/_logger.sh" 2>/dev/null || true

RESULTS='{"targets":[],"success":0,"failed":0}'

for target in "${TARGETS[@]}"; do
    PLATFORM=""
    CHAT_ID_TARGET=""
    STATUS="success"
    ERROR=""

    case "$target" in
        origin)
            # Reply to the originating channel
            PLATFORM="${ORIGIN_PLATFORM:-telegram}"
            CHAT_ID_TARGET="${ORIGIN_CHAT_ID:-${CHAT_ID:-}}"
            if [[ -z "${CHAT_ID_TARGET}" ]]; then
                STATUS="failed"
                ERROR="No ORIGIN_CHAT_ID or CHAT_ID set for 'origin' target"
            fi
            ;;
        local)
            # Save to local file
            TIMESTAMP=$(date -u +"%Y%m%dT%H%M%S")
            LOCAL_FILE="${OUTPUT_DIR}/${TIMESTAMP}.md"
            printf '%s\n' "$MESSAGE" > "${LOCAL_FILE}" 2>/dev/null && STATUS="success" || STATUS="failed"
            RESULTS=$(echo "$RESULTS" | jq -c --arg t "$target" --arg s "$STATUS" --arg p "${LOCAL_FILE}" \
                '.targets += [{"target": $t, "status": $s, "path": $p}]')
            [[ "$STATUS" == "success" ]] && RESULTS=$(echo "$RESULTS" | jq -c '.success += 1') || RESULTS=$(echo "$RESULTS" | jq -c '.failed += 1')
            continue
            ;;
        telegram:*|discord:*|web:*)
            PLATFORM="${target%%:*}"
            CHAT_ID_TARGET="${target#*:}"
            ;;
        telegram|discord|web)
            # Platform without chat_id — use home channel (CHAT_ID env for telegram)
            PLATFORM="$target"
            case "$PLATFORM" in
                telegram) CHAT_ID_TARGET="${CHAT_ID:-}" ;;
                discord) CHAT_ID_TARGET="${DISCORD_CHANNEL_ID:-}" ;;
                web) CHAT_ID_TARGET="${WEB_PORT:-8080}" ;;
            esac
            if [[ -z "${CHAT_ID_TARGET}" ]]; then
                STATUS="failed"
                ERROR="No home channel configured for ${PLATFORM}"
            fi
            ;;
        *)
            STATUS="failed"
            ERROR="Unknown target: ${target}"
            ;;
    esac

    # Send to platform
    if [[ "$STATUS" == "success" && -n "$PLATFORM" ]]; then
        SEND_OUTPUT=$(bash "${SCRIPT_DIR}/deliver-outbound.sh" "${AGENT}" "${PLATFORM}" "${CHAT_ID_TARGET}" "${MESSAGE}" 2>&1)
        SEND_EXIT=$?
        if [[ ${SEND_EXIT} -ne 0 ]]; then
            STATUS="failed"
            ERROR="${SEND_OUTPUT}"
        fi
    fi

    RESULTS=$(echo "$RESULTS" | jq -c --arg t "$target" --arg s "$STATUS" --arg e "${ERROR:-}" \
        '.targets += [{"target": $t, "status": $s, "error": $e}]')
    [[ "$STATUS" == "success" ]] && RESULTS=$(echo "$RESULTS" | jq -c '.success += 1') || RESULTS=$(echo "$RESULTS" | jq -c '.failed += 1')
done

TOTAL_OK=$(echo "$RESULTS" | jq -r '.success')
TOTAL_FAIL=$(echo "$RESULTS" | jq -r '.failed')
crm_log "delivery_multi" "Delivered to ${#TARGETS[@]} targets (${TOTAL_OK} ok, ${TOTAL_FAIL} failed)" 2>/dev/null || true

echo "$RESULTS" | jq .
