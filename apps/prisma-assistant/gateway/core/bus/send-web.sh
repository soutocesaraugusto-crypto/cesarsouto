#!/usr/bin/env bash
# send-web.sh — Send message to local Web Chat
#
# Posts a message to the local web chat server's API.
# Reports errors properly (no silent suppression).
#
# Usage: bash send-web.sh <recipient_id> "<message>" [--image /path]
#
# Environment:
#   WEB_PORT - Web chat port (default: 8080)
#   WEB_HOST - Web chat host (default: localhost)
#
# Epic 110 Story 110.17, Story 114.18 Phase 2

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_logger.sh" 2>/dev/null || true

WEB_HOST="${WEB_HOST:-localhost}"
WEB_PORT="${WEB_PORT:-8080}"
RECIPIENT="${1:-agent}"
MESSAGE="${2:-}"
BASE_URL="http://${WEB_HOST}:${WEB_PORT}"

# Dry-run mode
if [[ "${DRY_RUN:-0}" == "1" ]]; then
    crm_log "dry_run" "Would send web message" "recipient=${RECIPIENT}" "msg_len=${#MESSAGE}" 2>/dev/null || true
    echo "DRY_RUN: message not sent (${#MESSAGE} chars)"
    exit 0
fi

# Validate server is responding before sending
HEALTH=$(curl -s --max-time 3 "${BASE_URL}/api/health" 2>/dev/null || echo "")
if [[ -z "${HEALTH}" ]] || ! echo "${HEALTH}" | jq -e '.status' > /dev/null 2>&1; then
    crm_log_error "send_web" "Web chat server not responding" "url=${BASE_URL}" 2>/dev/null || true
    echo "ERROR: Web chat server not responding at ${BASE_URL}" >&2
    exit 1
fi

# Build JSON payload safely using jq
PAYLOAD=$(jq -n -c \
    --arg from "agent" \
    --arg to "${RECIPIENT}" \
    --arg text "${MESSAGE}" \
    '{from: $from, to: $to, text: $text}')

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/messages" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}" 2>&1)

HTTP_CODE=$(echo "${RESPONSE}" | tail -1)
BODY=$(echo "${RESPONSE}" | head -n -1)

if [[ "${HTTP_CODE}" == "201" || "${HTTP_CODE}" == "200" ]]; then
    MSG_ID=$(echo "${BODY}" | jq -r '.id // ""' 2>/dev/null || echo "")
    crm_log "web_send" "Message sent" "recipient=${RECIPIENT}" "msg_id=${MSG_ID}" "msg_len=${#MESSAGE}" 2>/dev/null || true
    echo "${MSG_ID}"
else
    crm_log_error "send_web" "Failed to send message" "http_code=${HTTP_CODE}" "recipient=${RECIPIENT}" 2>/dev/null || true
    echo "ERROR: Failed to send (HTTP ${HTTP_CODE})" >&2
    exit 1
fi
