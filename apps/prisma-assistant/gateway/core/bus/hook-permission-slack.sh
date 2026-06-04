#!/usr/bin/env bash
# hook-permission-slack.sh — Permission request via Slack Block Kit buttons
#
# Sends a permission request with Approve/Deny buttons using Block Kit.
# socket-listener.py captures block_actions → writes response file.
#
# Reference: OpenClaw extensions/slack/ — Block Kit rendering, structured replies
# Story 114.18 Phase 4

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/_logger.sh" 2>/dev/null || true

SLACK_BOT_TOKEN="${SLACK_BOT_TOKEN:-}"
SLACK_CHANNEL_ID="${SLACK_CHANNEL_ID:-}"
CRM_AGENT_NAME="${CRM_AGENT_NAME:-$(basename "$(pwd)")}"

if [[ -z "${SLACK_BOT_TOKEN}" || -z "${SLACK_CHANNEL_ID}" ]]; then
    crm_log_error "slack_permission" "Missing SLACK_BOT_TOKEN or SLACK_CHANNEL_ID" 2>/dev/null || true
    echo '{"hookSpecificOutput":{"decision":"deny"}}'
    exit 0
fi

SLACK_API="https://slack.com/api"

# Read hook input from stdin
HOOK_INPUT=$(cat 2>/dev/null || echo '{}')
TOOL_NAME=$(echo "${HOOK_INPUT}" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")
TOOL_INPUT=$(echo "${HOOK_INPUT}" | jq -r '.tool_input // "" | tostring' 2>/dev/null || echo "")

# Truncate for display
if [[ ${#TOOL_INPUT} -gt 500 ]]; then
    TOOL_INPUT="${TOOL_INPUT:0:497}..."
fi

REQ_ID="perm-$(date +%s)-$$"
RESPONSE_FILE="/tmp/crm-hook-response-${CRM_AGENT_NAME}-slack.json"

# Clean any stale response file
rm -f "${RESPONSE_FILE}" 2>/dev/null

crm_log "slack_permission" "Sending permission request" "tool=${TOOL_NAME}" "req_id=${REQ_ID}" 2>/dev/null || true

# Build Block Kit message with buttons
PAYLOAD=$(jq -n -c \
    --arg channel "${SLACK_CHANNEL_ID}" \
    --arg tool "${TOOL_NAME}" \
    --arg input "${TOOL_INPUT}" \
    --arg req_id "${REQ_ID}" \
    '{
        channel: $channel,
        text: ("Permission Request: " + $tool),
        blocks: [
            {
                type: "header",
                text: {type: "plain_text", text: "Permission Request", emoji: true}
            },
            {
                type: "section",
                fields: [
                    {type: "mrkdwn", text: ("*Tool:*\n`" + $tool + "`")},
                    {type: "mrkdwn", text: ("*ID:*\n`" + $req_id + "`")}
                ]
            },
            {
                type: "section",
                text: {type: "mrkdwn", text: ("*Input:*\n```" + $input + "```")}
            },
            {
                type: "actions",
                elements: [
                    {
                        type: "button",
                        text: {type: "plain_text", text: "Approve"},
                        action_id: "perm_allow",
                        style: "primary",
                        value: $req_id
                    },
                    {
                        type: "button",
                        text: {type: "plain_text", text: "Deny"},
                        action_id: "perm_deny",
                        style: "danger",
                        value: $req_id
                    }
                ]
            }
        ]
    }')

RESPONSE=$(curl -s -X POST "${SLACK_API}/chat.postMessage" \
    -H "Authorization: Bearer ${SLACK_BOT_TOKEN}" \
    -H "Content-Type: application/json; charset=utf-8" \
    -d "${PAYLOAD}" 2>/dev/null || echo "")

if ! echo "${RESPONSE}" | jq -e '.ok == true' > /dev/null 2>&1; then
    ERR=$(echo "${RESPONSE}" | jq -r '.error // "Unknown"' 2>/dev/null)
    crm_log_error "slack_permission" "Failed to send" "error=${ERR}" 2>/dev/null || true
    echo '{"hookSpecificOutput":{"decision":"deny"}}'
    exit 0
fi

MSG_TS=$(echo "${RESPONSE}" | jq -r '.ts // ""' 2>/dev/null)
crm_log "slack_permission" "Permission request sent" "ts=${MSG_TS}" "req_id=${REQ_ID}" 2>/dev/null || true

# Poll for response from socket-listener.py
TIMEOUT=1800
ELAPSED=0
POLL_INTERVAL=3

CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
INBOX_DIR="${CRM_ROOT}/channel-inbox/${CRM_AGENT_NAME}"

while [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
    # Check response file (written by socket-listener.py on button click)
    if [[ -f "${RESPONSE_FILE}" ]]; then
        DECISION=$(jq -r '.decision // ""' "${RESPONSE_FILE}" 2>/dev/null || echo "")
        rm -f "${RESPONSE_FILE}" 2>/dev/null
        if [[ "${DECISION}" == "approve" || "${DECISION}" == "deny" ]]; then
            crm_log "slack_permission" "Decision via socket" "decision=${DECISION}" "elapsed_s=${ELAPSED}" 2>/dev/null || true
            echo "{\"hookSpecificOutput\":{\"decision\":\"${DECISION}\"}}"
            exit 0
        fi
    fi

    # Fallback: check inbox for callback messages
    if [[ -d "${INBOX_DIR}" ]]; then
        for inbox_file in "${INBOX_DIR}"/*-slack-*.json; do
            [[ -f "${inbox_file}" ]] || continue
            FILE_TYPE=$(jq -r '._type // ""' "${inbox_file}" 2>/dev/null || echo "")
            FILE_CB=$(jq -r '.callback_data // ""' "${inbox_file}" 2>/dev/null || echo "")

            if [[ "${FILE_TYPE}" == "callback" ]]; then
                DECISION=""
                if [[ "${FILE_CB}" == "perm_allow" ]]; then
                    DECISION="approve"
                elif [[ "${FILE_CB}" == "perm_deny" ]]; then
                    DECISION="deny"
                fi

                if [[ -n "${DECISION}" ]]; then
                    rm -f "${inbox_file}" 2>/dev/null
                    crm_log "slack_permission" "Decision via inbox callback" "decision=${DECISION}" "elapsed_s=${ELAPSED}" 2>/dev/null || true
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
crm_log "slack_permission" "Permission timed out (auto-deny)" "timeout=${TIMEOUT}" 2>/dev/null || true
echo '{"hookSpecificOutput":{"decision":"deny"}}'
exit 0
