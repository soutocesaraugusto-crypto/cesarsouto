#!/usr/bin/env bash
# hook-permission-discord.sh — Permission request via Discord button components
#
# Sends a permission request with Approve/Deny buttons to Discord.
# Two capture modes:
#   1. Webhook: Discord sends interactions to webhook-receiver.py /discord/interactions
#      → writes response file at /tmp/crm-hook-response-{AGENT}-{ID}.json
#   2. Fallback: polls channel for text replies ("approve"/"deny")
#
# Story 114.18 Phase 1 — Discord Production

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_logger.sh" 2>/dev/null || true

DISCORD_TOKEN="${DISCORD_TOKEN:-}"
CHANNEL_ID="${DISCORD_CHANNEL_ID:-}"
CRM_AGENT_NAME="${CRM_AGENT_NAME:-$(basename "$(pwd)")}"

if [[ -z "${DISCORD_TOKEN}" || -z "${CHANNEL_ID}" ]]; then
    crm_log_error "discord_permission" "Missing DISCORD_TOKEN or DISCORD_CHANNEL_ID" 2>/dev/null || true
    echo '{"hookSpecificOutput":{"decision":"deny"}}'
    exit 0
fi

DISCORD_API="https://discord.com/api/v10"

# Read hook input from stdin
HOOK_INPUT=$(cat 2>/dev/null || echo '{}')
TOOL_NAME=$(echo "${HOOK_INPUT}" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")
TOOL_INPUT=$(echo "${HOOK_INPUT}" | jq -r '.tool_input // "" | tostring' 2>/dev/null || echo "")

# Truncate tool input for display (max 500 chars)
if [[ ${#TOOL_INPUT} -gt 500 ]]; then
    TOOL_INPUT="${TOOL_INPUT:0:497}..."
fi

REQ_ID="perm-$(date +%s)-$$"
RESPONSE_FILE="/tmp/crm-hook-response-${CRM_AGENT_NAME}-${REQ_ID}.json"

crm_log "discord_permission" "Sending permission request" "tool=${TOOL_NAME}" "req_id=${REQ_ID}" 2>/dev/null || true

# Send message with button components
PAYLOAD=$(jq -n -c \
    --arg tool "${TOOL_NAME}" \
    --arg input "${TOOL_INPUT}" \
    --arg req_id "${REQ_ID}" \
    '{
        "embeds": [{
            "title": "Permission Request",
            "description": ("**Tool:** `" + $tool + "`\n**Input:**\n```\n" + $input + "\n```\n**ID:** `" + $req_id + "`"),
            "color": 16744448
        }],
        "components": [{
            "type": 1,
            "components": [
                {"type": 2, "style": 3, "label": "Approve", "custom_id": ("perm_allow_" + $req_id)},
                {"type": 2, "style": 4, "label": "Deny", "custom_id": ("perm_deny_" + $req_id)}
            ]
        }]
    }')

RESPONSE=$(curl -s -X POST "${DISCORD_API}/channels/${CHANNEL_ID}/messages" \
    -H "Authorization: Bot ${DISCORD_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}" 2>/dev/null)

MSG_ID=$(echo "${RESPONSE}" | jq -r '.id // ""' 2>/dev/null || echo "")

if [[ -z "${MSG_ID}" ]]; then
    crm_log_error "discord_permission" "Failed to send permission request" "response=${RESPONSE}" 2>/dev/null || true
    echo '{"hookSpecificOutput":{"decision":"deny"}}'
    exit 0
fi

crm_log "discord_permission" "Permission request sent" "msg_id=${MSG_ID}" "req_id=${REQ_ID}" 2>/dev/null || true

# Poll for interaction response
# Priority 1: check response file (set by webhook-receiver.py /discord/interactions)
# Priority 2: check channel for text replies (fallback)
TIMEOUT=1800
ELAPSED=0
POLL_INTERVAL=3

while [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
    # Check webhook response file first (fast path)
    if [[ -f "${RESPONSE_FILE}" ]]; then
        DECISION=$(jq -r '.decision // ""' "${RESPONSE_FILE}" 2>/dev/null || echo "")
        rm -f "${RESPONSE_FILE}" 2>/dev/null
        if [[ "${DECISION}" == "approve" || "${DECISION}" == "deny" ]]; then
            crm_log "discord_permission" "Decision received via webhook" "decision=${DECISION}" "req_id=${REQ_ID}" "elapsed_s=${ELAPSED}" 2>/dev/null || true
            echo "{\"hookSpecificOutput\":{\"decision\":\"${DECISION}\"}}"
            exit 0
        fi
    fi

    # Fallback: poll channel for text replies
    MSGS=$(curl -s "${DISCORD_API}/channels/${CHANNEL_ID}/messages?after=${MSG_ID}&limit=5" \
        -H "Authorization: Bot ${DISCORD_TOKEN}" 2>/dev/null)

    DECISION=$(echo "${MSGS}" | python3 -c "
import json, sys
try:
    msgs = json.loads(sys.stdin.read())
    for m in msgs:
        content = m.get('content', '').lower().strip()
        if content in ('approve', 'yes', 'ok', 'allow', '1'):
            print('approve'); sys.exit()
        if content in ('deny', 'no', 'reject', 'block', '2'):
            print('deny'); sys.exit()
except: pass
" 2>/dev/null)

    if [[ -n "${DECISION}" ]]; then
        crm_log "discord_permission" "Decision received via text" "decision=${DECISION}" "req_id=${REQ_ID}" "elapsed_s=${ELAPSED}" 2>/dev/null || true
        echo "{\"hookSpecificOutput\":{\"decision\":\"${DECISION}\"}}"
        exit 0
    fi

    sleep ${POLL_INTERVAL}
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

# Timeout — fail-closed
crm_log "discord_permission" "Permission timed out (auto-deny)" "req_id=${REQ_ID}" "timeout=${TIMEOUT}" 2>/dev/null || true
echo '{"hookSpecificOutput":{"decision":"deny"}}'
exit 0
