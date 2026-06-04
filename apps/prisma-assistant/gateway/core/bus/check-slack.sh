#!/usr/bin/env bash
# check-slack.sh — Slack message checker
#
# In ADAPTER_MODE: socket-listener.py handles everything (noop).
# In legacy mode: polls conversations.history API as fallback.
#
# Usage: bash check-slack.sh
#
# Story 114.18 Phase 4

set -uo pipefail

# In adapter mode, socket-listener.py writes to channel-inbox/ — nothing to do
if [[ "${ADAPTER_MODE:-false}" == "true" ]]; then
    exit 0
fi

# Legacy polling fallback via conversations.history API
SLACK_BOT_TOKEN="${SLACK_BOT_TOKEN:-}"
SLACK_CHANNEL_ID="${SLACK_CHANNEL_ID:-}"

if [[ -z "${SLACK_BOT_TOKEN}" || -z "${SLACK_CHANNEL_ID}" ]]; then
    echo "[]"
    exit 0
fi

CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
CRM_AGENT_NAME="${CRM_AGENT_NAME:-$(basename "$(pwd)")}"
LAST_TS_FILE="${CRM_ROOT}/state/${CRM_AGENT_NAME}/.slack-last-ts"
mkdir -p "$(dirname "${LAST_TS_FILE}")" 2>/dev/null || true

LAST_TS=$(cat "${LAST_TS_FILE}" 2>/dev/null || echo "")

URL="https://slack.com/api/conversations.history?channel=${SLACK_CHANNEL_ID}&limit=10"
[[ -n "${LAST_TS}" ]] && URL="${URL}&oldest=${LAST_TS}"

RESPONSE=$(curl -s -H "Authorization: Bearer ${SLACK_BOT_TOKEN}" "${URL}" 2>/dev/null || echo "")

if ! echo "${RESPONSE}" | jq -e '.ok == true' > /dev/null 2>&1; then
    echo "[]"
    exit 0
fi

# Parse and output messages
echo "${RESPONSE}" | python3 -c "
import json, sys, time
try:
    data = json.loads(sys.stdin.read())
    msgs = data.get('messages', [])
    results = []
    latest_ts = ''
    for m in reversed(msgs):  # Oldest first
        if m.get('bot_id'):
            continue
        ts = m.get('ts', '')
        results.append({
            'id': ts,
            'from': m.get('user', 'unknown'),
            'from_id': m.get('user', ''),
            'text': m.get('text', ''),
            'channel': 'slack',
            'thread_ts': m.get('thread_ts', ''),
        })
        if ts > latest_ts:
            latest_ts = ts
    print(json.dumps(results))
    if latest_ts:
        with open('${LAST_TS_FILE}', 'w') as f:
            f.write(latest_ts)
except Exception as e:
    print('[]')
" 2>/dev/null || echo "[]"
