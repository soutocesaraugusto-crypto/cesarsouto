#!/usr/bin/env bash
# hook-permission-web.sh — Permission request via Web Chat UI
#
# Sends a permission request with Approve/Deny buttons to the web chat.
# Waits for user response via polling.
#
# Epic 110 Story 110.17

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_HOST="${WEB_HOST:-localhost}"
WEB_PORT="${WEB_PORT:-8080}"

# Read hook input from stdin
HOOK_INPUT=$(cat 2>/dev/null || echo '{}')
TOOL_NAME=$(echo "${HOOK_INPUT}" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")
TOOL_INPUT=$(echo "${HOOK_INPUT}" | jq -r '.tool_input | tostring' 2>/dev/null || echo "{}")

# Generate unique request ID
REQ_ID="perm-$(date +%s)-$$"

# Send permission request with buttons
curl -s -X POST "http://${WEB_HOST}:${WEB_PORT}/api/permission" \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"${REQ_ID}\",\"tool\":\"${TOOL_NAME}\",\"input\":${TOOL_INPUT}}" \
    > /dev/null 2>&1

# Poll for response (timeout: 30 minutes)
TIMEOUT=1800
ELAPSED=0
while [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
    RESPONSE=$(curl -s "http://${WEB_HOST}:${WEB_PORT}/api/permission/${REQ_ID}" 2>/dev/null || echo "")
    if [[ -n "${RESPONSE}" && "${RESPONSE}" != "null" && "${RESPONSE}" != "" ]]; then
        DECISION=$(echo "${RESPONSE}" | jq -r '.decision // "deny"' 2>/dev/null || echo "deny")
        echo "{\"hookSpecificOutput\":{\"decision\":\"${DECISION}\"}}"
        exit 0
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

# Timeout — deny by default (fail-closed)
echo '{"hookSpecificOutput":{"decision":"deny"}}'
exit 0
