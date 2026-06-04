#!/usr/bin/env bash
# hook-permission-whatsapp.sh — Permission request via WhatsApp interactive buttons
#
# Sends an interactive button message (Approve/Deny) via the WhatsApp bridge.
# Bridge captures button reply → writes response file.
# Fallback: accepts text replies ("1"/"2" or "approve"/"deny").
#
# Story 114.18 Phase 3

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_logger.sh" 2>/dev/null || true

CRM_AGENT_NAME="${CRM_AGENT_NAME:-$(basename "$(pwd)")}"
WHATSAPP_BRIDGE_PORT="${WHATSAPP_BRIDGE_PORT:-8445}"
BRIDGE_URL="http://127.0.0.1:${WHATSAPP_BRIDGE_PORT}"

# Get recipient from env (primary WhatsApp contact)
RECIPIENT="${WHATSAPP_ALLOWED_NUMBERS%%,*}"  # First allowed number
RECIPIENT="${RECIPIENT:-${WHATSAPP_RECIPIENT:-}}"

if [[ -z "${RECIPIENT}" ]]; then
    crm_log_error "whatsapp_permission" "No recipient configured" 2>/dev/null || true
    echo '{"hookSpecificOutput":{"decision":"deny"}}'
    exit 0
fi

# Check bridge connectivity
HEALTH=$(curl -s --max-time 3 "${BRIDGE_URL}/health" 2>/dev/null || echo "")
WA_CONNECTED=$(echo "${HEALTH}" | jq -r '.connected // false' 2>/dev/null || echo "false")
if [[ "${WA_CONNECTED}" != "true" ]]; then
    crm_log_error "whatsapp_permission" "WhatsApp not connected" 2>/dev/null || true
    echo '{"hookSpecificOutput":{"decision":"deny"}}'
    exit 0
fi

# Read hook input from stdin
HOOK_INPUT=$(cat 2>/dev/null || echo '{}')
TOOL_NAME=$(echo "${HOOK_INPUT}" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")
TOOL_INPUT=$(echo "${HOOK_INPUT}" | jq -r '.tool_input // "" | tostring' 2>/dev/null || echo "")

# Truncate for display
if [[ ${#TOOL_INPUT} -gt 300 ]]; then
    TOOL_INPUT="${TOOL_INPUT:0:297}..."
fi

REQ_ID="perm-$(date +%s)-$$"
RESPONSE_FILE="/tmp/crm-hook-response-${CRM_AGENT_NAME}-${REQ_ID}.json"

crm_log "whatsapp_permission" "Sending permission request" "tool=${TOOL_NAME}" "req_id=${REQ_ID}" "to=${RECIPIENT}" 2>/dev/null || true

# Send interactive button message via bridge
PAYLOAD=$(jq -n -c \
    --arg to "${RECIPIENT}" \
    --arg text "$(printf "Permission Request\n\nTool: %s\nInput:\n%s\n\nID: %s\n\nReply:\n1 - Approve\n2 - Deny" "${TOOL_NAME}" "${TOOL_INPUT}" "${REQ_ID}")" \
    '{to: $to, text: $text, buttons: [
        {"buttonId": "approve", "buttonText": {"displayText": "Approve"}, "type": 1},
        {"buttonId": "deny", "buttonText": {"displayText": "Deny"}, "type": 1}
    ]}')

SEND_RESULT=$(curl -s -X POST "${BRIDGE_URL}/send" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}" 2>/dev/null || echo "")

if ! echo "${SEND_RESULT}" | jq -e '.ok == true' > /dev/null 2>&1; then
    # Button send failed — try plain text with numbered options
    FALLBACK_TEXT=$(printf "Permission Request\n\nTool: %s\nInput:\n%s\n\nReply with:\n1 - Approve\n2 - Deny" "${TOOL_NAME}" "${TOOL_INPUT}")
    FALLBACK_PAYLOAD=$(jq -n -c --arg to "${RECIPIENT}" --arg text "${FALLBACK_TEXT}" '{to: $to, text: $text}')
    curl -s -X POST "${BRIDGE_URL}/send" \
        -H "Content-Type: application/json" \
        -d "${FALLBACK_PAYLOAD}" > /dev/null 2>&1 || true
fi

# Poll for response
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
INBOX_DIR="${CRM_ROOT}/channel-inbox/${CRM_AGENT_NAME}"

TIMEOUT=1800
ELAPSED=0
POLL_INTERVAL=3

while [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
    # Check response file (set by bridge when button reply received)
    if [[ -f "${RESPONSE_FILE}" ]]; then
        DECISION=$(jq -r '.decision // ""' "${RESPONSE_FILE}" 2>/dev/null || echo "")
        rm -f "${RESPONSE_FILE}" 2>/dev/null
        if [[ "${DECISION}" == "approve" || "${DECISION}" == "deny" ]]; then
            crm_log "whatsapp_permission" "Decision via response file" "decision=${DECISION}" "elapsed_s=${ELAPSED}" 2>/dev/null || true
            echo "{\"hookSpecificOutput\":{\"decision\":\"${DECISION}\"}}"
            exit 0
        fi
    fi

    # Check channel-inbox for text replies from the same number
    if [[ -d "${INBOX_DIR}" ]]; then
        for inbox_file in "${INBOX_DIR}"/*-whatsapp-*.json; do
            [[ -f "${inbox_file}" ]] || continue
            FILE_SENDER=$(jq -r '.chat_id // ""' "${inbox_file}" 2>/dev/null || echo "")
            FILE_TEXT=$(jq -r '.text // ""' "${inbox_file}" 2>/dev/null || echo "")
            FILE_CB=$(jq -r '.callback_data // ""' "${inbox_file}" 2>/dev/null || echo "")

            if [[ "${FILE_SENDER}" == "${RECIPIENT}" ]]; then
                DECISION=""
                # Check button reply
                if [[ "${FILE_CB}" == "approve" || "${FILE_TEXT}" == "approve" || "${FILE_TEXT}" == "1" || "${FILE_TEXT,,}" == "yes" ]]; then
                    DECISION="approve"
                elif [[ "${FILE_CB}" == "deny" || "${FILE_TEXT}" == "deny" || "${FILE_TEXT}" == "2" || "${FILE_TEXT,,}" == "no" ]]; then
                    DECISION="deny"
                fi

                if [[ -n "${DECISION}" ]]; then
                    rm -f "${inbox_file}" 2>/dev/null  # Consume the message
                    crm_log "whatsapp_permission" "Decision via inbox" "decision=${DECISION}" "elapsed_s=${ELAPSED}" 2>/dev/null || true
                    echo "{\"hookSpecificOutput\":{\"decision\":\"${DECISION}\"}}"
                    exit 0
                fi
            fi
        done
    fi

    sleep ${POLL_INTERVAL}
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

# Timeout — auto-deny
crm_log "whatsapp_permission" "Permission timed out (auto-deny)" "req_id=${REQ_ID}" "timeout=${TIMEOUT}" 2>/dev/null || true
echo '{"hookSpecificOutput":{"decision":"deny"}}'
exit 0
