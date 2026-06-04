#!/usr/bin/env bash
# check-discord.sh — Poll Discord channel for new messages via REST API
#
# Discord doesn't support HTTP long-polling like Telegram's getUpdates.
# This uses the REST GET /channels/{id}/messages endpoint with ?after= param.
# For real-time, use discord-gateway-bridge.py (WebSocket→file bridge).
#
# Usage: bash check-discord.sh [after_message_id]
#
# Environment:
#   DISCORD_TOKEN      - Discord bot token
#   DISCORD_CHANNEL_ID - Channel to poll
#   DISCORD_ALLOWED_USER - User ID filter (like Telegram's ALLOWED_USER)
#
# Epic 110 Story 110.18

set -uo pipefail

DISCORD_TOKEN="${DISCORD_TOKEN:-}"
CHANNEL_ID="${DISCORD_CHANNEL_ID:-}"
ALLOWED_USER="${DISCORD_ALLOWED_USER:-}"
AFTER="${1:-}"

if [[ -z "${DISCORD_TOKEN}" || -z "${CHANNEL_ID}" ]]; then
    echo "[]"
    exit 0
fi

PARAMS=""
[[ -n "${AFTER}" ]] && PARAMS="?after=${AFTER}&limit=10"

RESPONSE=$(curl -s "https://discord.com/api/v10/channels/${CHANNEL_ID}/messages${PARAMS}" \
    -H "Authorization: Bot ${DISCORD_TOKEN}" 2>/dev/null)

# Filter by allowed user and format output
python3 -c "
import json, sys
try:
    msgs = json.loads(sys.argv[1])
    if not isinstance(msgs, list):
        print('[]'); sys.exit()
    allowed = sys.argv[2] if len(sys.argv) > 2 else ''
    result = []
    for m in reversed(msgs):  # oldest first
        if m.get('author', {}).get('bot'):
            continue  # skip bot's own messages
        if allowed and str(m.get('author', {}).get('id', '')) != allowed:
            continue
        result.append({
            'id': m['id'],
            'from': m.get('author', {}).get('username', 'unknown'),
            'from_id': str(m.get('author', {}).get('id', '')),
            'text': m.get('content', ''),
            'channel': 'discord'
        })
    print(json.dumps(result))
except Exception:
    print('[]')
" "${RESPONSE}" "${ALLOWED_USER}" 2>/dev/null || echo "[]"
