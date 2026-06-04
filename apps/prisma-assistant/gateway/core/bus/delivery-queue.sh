#!/usr/bin/env bash
# delivery-queue.sh — Persistent delivery queue with write-ahead semantics
# OpenClaw pattern: delivery-queue-recovery.ts with exponential backoff
#
# Write-ahead: message persisted BEFORE send. Ack removes after success.
# If process crashes during send, the message survives in queue for retry.
#
# Usage:
#   delivery-queue.sh enqueue <agent> <platform> <chat_id> "<message>" [flags...]
#   delivery-queue.sh pre-send <agent> <platform> <chat_id> "<message>" [flags...]
#   delivery-queue.sh ack <agent> <queue_id>
#   delivery-queue.sh nack <agent> <queue_id> "<error>"
#   delivery-queue.sh retry <agent>          # Retry all pending messages
#   delivery-queue.sh status <agent>         # Show queue status
#   delivery-queue.sh cleanup <agent>        # Delete failed messages >7d old
#
# Queue structure:
#   ~/.claude-remote/{instance}/queue/{agent}/pending/   — waiting for send or retry
#   ~/.claude-remote/{instance}/queue/{agent}/sent/      — delivered (retained 24h for audit)
#   ~/.claude-remote/{instance}/queue/{agent}/failed/    — permanently failed
#
# Write-ahead flow:
#   pre-send → pending/ (state: pending_send)
#   ack      → sent/ (retained 24h)
#   nack     → pending/ (state: pending_retry, retry_count++)
#   crash    → retry sweep detects pending_send > 5min → schedules retry
#
# Epic 110 / Story 110.28 Phase 6 + Story 114.19 Phase 1 (Write-Ahead)

set -uo pipefail

ACTION="${1:-status}"
AGENT="${2:-${CRM_AGENT_NAME:-prisma}}"
shift 2 2>/dev/null || true

CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
QUEUE_DIR="${CRM_ROOT}/queue/${AGENT}"
PENDING="${QUEUE_DIR}/pending"
SENT="${QUEUE_DIR}/sent"
FAILED="${QUEUE_DIR}/failed"
LOG_DIR="${CRM_ROOT}/logs/${AGENT}"

mkdir -p "${PENDING}" "${SENT}" "${FAILED}" "${LOG_DIR}" 2>/dev/null || true

# Generate unique queue ID
_gen_queue_id() {
    local epoch_ms rand5
    epoch_ms=$(date +%s%N 2>/dev/null | cut -c1-13 || date +%s)
    rand5=$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')
    echo "${epoch_ms}-${AGENT}-${rand5}"
}

log() {
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [delivery-queue/${AGENT}] $1" >> "${LOG_DIR}/activity.log" 2>/dev/null
}

MAX_RETRIES=5
# Backoff schedule: 5s, 25s, 2m, 10m, 30m
BACKOFF=(5 25 120 600 1800)

# Permanent error patterns (no point retrying)
is_permanent_error() {
    local err="$1"
    [[ "$err" == *"chat not found"* ]] && return 0
    [[ "$err" == *"bot was blocked"* ]] && return 0
    [[ "$err" == *"user not found"* ]] && return 0
    [[ "$err" == *"Unauthorized"* ]] && return 0
    [[ "$err" == *"Forbidden"* ]] && return 0
    return 1
}

case "${ACTION}" in
    # === WRITE-AHEAD: persist message BEFORE send (Story 114.19 Phase 1) ===
    pre-send)
        PLATFORM="${1:-telegram}"
        CHAT_ID="${2:-}"
        MESSAGE="${3:-}"
        shift 3 2>/dev/null || true
        FLAGS="$*"

        QUEUE_ID=$(_gen_queue_id)
        FILENAME="${QUEUE_ID}.json"

        jq -n -c \
            --arg queue_id "${QUEUE_ID}" \
            --arg platform "${PLATFORM}" \
            --arg chat_id "${CHAT_ID}" \
            --arg message "${MESSAGE}" \
            --arg flags "${FLAGS}" \
            --arg enqueued_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{queue_id: $queue_id, platform: $platform, chat_id: $chat_id, message: $message, flags: $flags, enqueued_at: $enqueued_at, state: "pending_send", retry_count: 0, last_error: null}' \
            > "${PENDING}/${FILENAME}"

        log "Pre-send enqueued: ${PLATFORM}:${CHAT_ID} (${#MESSAGE} chars) queue_id=${QUEUE_ID}"
        echo "${QUEUE_ID}"
        ;;

    # === ACK: message delivered successfully — move to sent/ ===
    ack)
        QUEUE_ID="${1:-}"
        if [[ -z "${QUEUE_ID}" ]]; then
            echo "ERROR: queue_id required" >&2
            exit 1
        fi

        PENDING_FILE="${PENDING}/${QUEUE_ID}.json"
        if [[ -f "${PENDING_FILE}" ]]; then
            # Update state and move to sent/
            jq -c '.state = "delivered" | .delivered_at = now' "${PENDING_FILE}" > "${SENT}/${QUEUE_ID}.json" 2>/dev/null
            rm -f "${PENDING_FILE}"
            log "Ack delivered: queue_id=${QUEUE_ID}"
        fi
        echo "acked"
        ;;

    # === NACK: delivery failed — keep in pending with retry scheduling ===
    nack)
        QUEUE_ID="${1:-}"
        ERROR="${2:-unknown error}"
        if [[ -z "${QUEUE_ID}" ]]; then
            echo "ERROR: queue_id required" >&2
            exit 1
        fi

        PENDING_FILE="${PENDING}/${QUEUE_ID}.json"
        if [[ -f "${PENDING_FILE}" ]]; then
            ENTRY=$(cat "${PENDING_FILE}" 2>/dev/null)
            RETRY_COUNT=$(echo "$ENTRY" | jq -r '.retry_count // 0' 2>/dev/null)

            # Check permanent error
            if is_permanent_error "${ERROR}"; then
                jq -c --arg err "${ERROR}" '.state = "permanent_failure" | .last_error = $err' "${PENDING_FILE}" > "${FAILED}/${QUEUE_ID}.json" 2>/dev/null
                rm -f "${PENDING_FILE}"
                log "Nack permanent: queue_id=${QUEUE_ID} error=${ERROR}"
            elif [[ ${RETRY_COUNT} -ge ${MAX_RETRIES} ]]; then
                mv "${PENDING_FILE}" "${FAILED}/" 2>/dev/null || true
                log "Nack max retries: queue_id=${QUEUE_ID} retries=${RETRY_COUNT}"
            else
                # Schedule retry with backoff
                local backoff_idx=${RETRY_COUNT}
                [[ ${backoff_idx} -ge ${#BACKOFF[@]} ]] && backoff_idx=$(( ${#BACKOFF[@]} - 1 ))
                local next_retry_secs=${BACKOFF[${backoff_idx}]}
                local next_retry_at
                next_retry_at=$(date -u -v+${next_retry_secs}S +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)

                echo "$ENTRY" | jq -c \
                    --argjson rc "$((RETRY_COUNT + 1))" \
                    --arg err "${ERROR}" \
                    --arg state "pending_retry" \
                    --arg next "${next_retry_at}" \
                    '.retry_count = $rc | .last_error = $err | .state = $state | .next_retry = $next' \
                    > "${PENDING_FILE}.tmp" 2>/dev/null && mv "${PENDING_FILE}.tmp" "${PENDING_FILE}"
                log "Nack transient: queue_id=${QUEUE_ID} retry=${RETRY_COUNT} backoff=${next_retry_secs}s"
            fi
        fi
        echo "nacked"
        ;;

    # === LEGACY: post-failure enqueue (backward compat) ===
    enqueue)
        PLATFORM="${1:-telegram}"
        CHAT_ID="${2:-}"
        MESSAGE="${3:-}"
        shift 3 2>/dev/null || true
        FLAGS="$*"

        EPOCH_MS=$(date +%s%N 2>/dev/null | cut -c1-13 || date +%s)
        RAND=$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')
        FILENAME="${EPOCH_MS}-${PLATFORM}-${RAND}.json"

        jq -n -c \
            --arg platform "${PLATFORM}" \
            --arg chat_id "${CHAT_ID}" \
            --arg message "${MESSAGE}" \
            --arg flags "${FLAGS}" \
            --arg enqueued_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{platform: $platform, chat_id: $chat_id, message: $message, flags: $flags, enqueued_at: $enqueued_at, retry_count: 0, last_error: null}' \
            > "${PENDING}/${FILENAME}"

        log "Enqueued message for ${PLATFORM}:${CHAT_ID} (${#MESSAGE} chars)"
        echo "${FILENAME}"
        ;;

    retry)
        RETRIED=0
        FAILED_COUNT=0
        RECOVERED=0
        NOW_EPOCH=$(date +%s)
        PENDING_FILES=$(find "${PENDING}" -name "*.json" -type f 2>/dev/null | sort)

        for pf in ${PENDING_FILES}; do
            [[ ! -f "$pf" ]] && continue

            ENTRY=$(cat "$pf" 2>/dev/null)
            STATE=$(echo "$ENTRY" | jq -r '.state // "pending_retry"' 2>/dev/null)
            PLATFORM=$(echo "$ENTRY" | jq -r '.platform' 2>/dev/null)
            CHAT_ID=$(echo "$ENTRY" | jq -r '.chat_id' 2>/dev/null)
            MESSAGE=$(echo "$ENTRY" | jq -r '.message' 2>/dev/null)
            FLAGS=$(echo "$ENTRY" | jq -r '.flags // ""' 2>/dev/null)
            RETRY_COUNT=$(echo "$ENTRY" | jq -r '.retry_count // 0' 2>/dev/null)
            ENQUEUED_AT=$(echo "$ENTRY" | jq -r '.enqueued_at // ""' 2>/dev/null)

            # === Write-ahead crash recovery (Story 114.19) ===
            # Messages with state=pending_send and enqueued_at > 5min without ack
            # indicates a crash during send — schedule retry
            if [[ "${STATE}" == "pending_send" ]]; then
                if [[ -n "${ENQUEUED_AT}" ]]; then
                    ENQUEUED_EPOCH=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "${ENQUEUED_AT}" +%s 2>/dev/null || date -d "${ENQUEUED_AT}" +%s 2>/dev/null || echo "0")
                    AGE_SECS=$(( NOW_EPOCH - ENQUEUED_EPOCH ))
                    if [[ ${AGE_SECS} -gt 300 ]]; then
                        # 5min+ without ack → assume crash → promote to retry
                        echo "$ENTRY" | jq -c '.state = "pending_retry" | .retry_count = 1 | .last_error = "crash recovery: no ack after 5min"' \
                            > "${pf}.tmp" 2>/dev/null && mv "${pf}.tmp" "$pf"
                        log "Crash recovery: $(basename "$pf") — pending_send > 5min, scheduling retry"
                        RECOVERED=$((RECOVERED + 1))
                        # Re-read entry for retry below
                        ENTRY=$(cat "$pf" 2>/dev/null)
                        STATE="pending_retry"
                        RETRY_COUNT=1
                    else
                        continue  # Still within 5min window — send might be in progress
                    fi
                fi
            fi

            # Skip if not ready for retry
            if [[ "${STATE}" != "pending_retry" && "${STATE}" != "pending_send" ]]; then
                # Legacy entries without state field — treat as pending_retry
                [[ -z "${STATE}" || "${STATE}" == "null" ]] || continue
            fi

            # Check max retries
            if [[ ${RETRY_COUNT} -ge ${MAX_RETRIES} ]]; then
                mv "$pf" "${FAILED}/" 2>/dev/null || true
                log "Moved to failed after ${RETRY_COUNT} retries: $(basename "$pf")"
                FAILED_COUNT=$((FAILED_COUNT + 1))
                continue
            fi

            # Try sending (bypass write-ahead for retries — already in queue)
            export _QUEUE_BYPASS_WRITE_AHEAD=1
            SEND_RESULT=$(bash "${TEMPLATE_ROOT}/core/bus/send-channel.sh" "${PLATFORM}" "${CHAT_ID}" "${MESSAGE}" ${FLAGS} 2>&1)
            SEND_EXIT=$?
            unset _QUEUE_BYPASS_WRITE_AHEAD

            if [[ ${SEND_EXIT} -eq 0 ]]; then
                # Move to sent/ for audit
                jq -c '.state = "delivered" | .delivered_at = now' "$pf" > "${SENT}/$(basename "$pf")" 2>/dev/null
                rm -f "$pf"
                RETRIED=$((RETRIED + 1))
                log "Retry success: $(basename "$pf")"
            else
                if is_permanent_error "${SEND_RESULT}"; then
                    mv "$pf" "${FAILED}/" 2>/dev/null || true
                    log "Permanent failure: $(basename "$pf") — ${SEND_RESULT}"
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                else
                    echo "$ENTRY" | jq -c \
                        --argjson rc "$((RETRY_COUNT + 1))" \
                        --arg err "${SEND_RESULT}" \
                        '.retry_count = $rc | .last_error = $err | .state = "pending_retry"' \
                        > "${pf}.tmp" 2>/dev/null && mv "${pf}.tmp" "$pf"
                fi
            fi
        done

        # Clean sent/ older than 24h
        find "${SENT}" -name "*.json" -mmin +1440 -delete 2>/dev/null || true

        SUMMARY="Retry sweep: ${RETRIED} ok, ${FAILED_COUNT} failed"
        [[ ${RECOVERED} -gt 0 ]] && SUMMARY="${SUMMARY}, ${RECOVERED} crash-recovered"
        echo "${SUMMARY}"
        log "${SUMMARY}"
        ;;

    status)
        PENDING_COUNT=$(find "${PENDING}" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
        FAILED_COUNT=$(find "${FAILED}" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
        echo "Queue: ${PENDING_COUNT} pending, ${FAILED_COUNT} failed"
        ;;

    cleanup)
        # Delete failed messages older than 7 days
        DELETED=0
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue
            rm -f "$file" 2>/dev/null && DELETED=$((DELETED + 1))
        done < <(find "${FAILED}" -name "*.json" -mtime +7 2>/dev/null)
        echo "Cleaned ${DELETED} failed messages older than 7 days"
        log "Queue cleanup: ${DELETED} old failed messages removed"
        ;;

    *)
        echo "Usage: delivery-queue.sh {enqueue|retry|status|cleanup} <agent> [args...]" >&2
        exit 1
        ;;
esac
