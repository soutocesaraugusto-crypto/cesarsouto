#!/usr/bin/env bash
# multi-channel-checker.sh — Poll multiple channels simultaneously
#
# Reads channels config from config.json and spawns a checker per channel.
# Each channel poller runs in background and injects messages into tmux.
#
# Usage: multi-channel-checker.sh <agent> <tmux_session> <agent_dir> <template_root>
#
# config.json format:
#   "channels": [
#     {"type": "telegram", "enabled": true},
#     {"type": "web", "enabled": true, "port": 8080},
#     {"type": "discord", "enabled": false, "channel_id": "...", "token_env": "DISCORD_TOKEN"}
#   ]
#
# Falls back to Telegram-only (fast-checker.sh) if no channels config.
#
# Epic 110 Story 110.19

set -uo pipefail

AGENT="$1"
TMUX_SESSION="$2"
AGENT_DIR="$3"
TEMPLATE_ROOT="$4"

CONFIG_FILE="${AGENT_DIR}/config.json"
BUS_DIR="${TEMPLATE_ROOT}/core/bus"
SCRIPTS_DIR="${TEMPLATE_ROOT}/core/scripts"

# Read channels config
CHANNELS=$(jq -r '.channels // empty' "${CONFIG_FILE}" 2>/dev/null || echo "")

if [[ -z "${CHANNELS}" || "${CHANNELS}" == "null" ]]; then
    # No multi-channel config — fall back to Telegram-only (fast-checker.sh)
    exec bash "${SCRIPTS_DIR}/fast-checker.sh" "$@"
fi

# Parse channels and start pollers
PIDS=()
CHANNEL_COUNT=$(echo "${CHANNELS}" | jq 'length' 2>/dev/null || echo "0")

for i in $(seq 0 $((CHANNEL_COUNT - 1))); do
    TYPE=$(echo "${CHANNELS}" | jq -r ".[$i].type" 2>/dev/null)
    ENABLED=$(echo "${CHANNELS}" | jq -r ".[$i].enabled // true" 2>/dev/null)

    if [[ "${ENABLED}" != "true" ]]; then
        continue
    fi

    case "${TYPE}" in
        telegram)
            # Use existing fast-checker.sh for Telegram
            CHANNEL_TYPE=telegram bash "${SCRIPTS_DIR}/fast-checker.sh" "$@" &
            PIDS+=($!)
            echo "Started Telegram poller (PID: ${PIDS[-1]})"
            ;;
        web)
            PORT=$(echo "${CHANNELS}" | jq -r ".[$i].port // 8080" 2>/dev/null)
            # Start web chat server
            WEB_PORT="${PORT}" python3 "${TEMPLATE_ROOT}/web-chat-server.py" --port "${PORT}" &
            WEB_PID=$!
            PIDS+=($WEB_PID)
            echo "Started Web Chat server on port ${PORT} (PID: ${WEB_PID})"

            # Start web poller (polls /api/messages and injects into tmux)
            (
                LAST_ID=0
                while true; do
                    MSGS=$(curl -s "http://localhost:${PORT}/api/messages?since=${LAST_ID}" 2>/dev/null || echo "[]")
                    NEW=$(echo "${MSGS}" | python3 -c "
import json, sys
msgs = json.loads(sys.stdin.read())
for m in msgs:
    if m.get('from') == 'user':
        print(f'=== WEB CHAT from {m.get(\"from\",\"user\")} ===')
        print(m.get('text',''))
        print(f'Reply using: bash ../../core/bus/send-web.sh user \"<your reply>\"')
" 2>/dev/null)
                    if [[ -n "${NEW}" ]]; then
                        LAST_ID=$(echo "${MSGS}" | python3 -c "import json,sys; msgs=json.loads(sys.stdin.read()); print(max(m['id'] for m in msgs) if msgs else 0)" 2>/dev/null || echo "${LAST_ID}")
                        tmux send-keys -t "${TMUX_SESSION}" "" 2>/dev/null
                        sleep 0.3
                        echo "${NEW}" | while IFS= read -r line; do
                            tmux send-keys -t "${TMUX_SESSION}" "${line}" Enter 2>/dev/null
                        done
                    fi
                    sleep 3
                done
            ) &
            PIDS+=($!)
            echo "Started Web Chat poller (PID: ${PIDS[-1]})"
            ;;
        discord)
            CHANNEL_ID=$(echo "${CHANNELS}" | jq -r ".[$i].channel_id // \"\"" 2>/dev/null)
            (
                LAST_MSG_ID=""
                while true; do
                    MSGS=$(DISCORD_CHANNEL_ID="${CHANNEL_ID}" bash "${BUS_DIR}/check-discord.sh" "${LAST_MSG_ID}" 2>/dev/null)
                    COUNT=$(echo "${MSGS}" | python3 -c "import json,sys; print(len(json.loads(sys.stdin.read())))" 2>/dev/null || echo "0")
                    if [[ "${COUNT}" -gt 0 ]]; then
                        LAST_MSG_ID=$(echo "${MSGS}" | python3 -c "import json,sys; msgs=json.loads(sys.stdin.read()); print(msgs[-1]['id'] if msgs else '')" 2>/dev/null)
                        echo "${MSGS}" | python3 -c "
import json, sys
msgs = json.loads(sys.stdin.read())
for m in msgs:
    print(f'=== DISCORD from {m[\"from\"]} ===')
    print(m['text'])
    print(f'Reply using: bash ../../core/bus/send-discord.sh ${m.get(\"from_id\",\"\")} \"<your reply>\"')
" 2>/dev/null | while IFS= read -r line; do
                            tmux send-keys -t "${TMUX_SESSION}" "${line}" Enter 2>/dev/null
                        done
                    fi
                    sleep 5  # Discord rate limit: 5s between polls
                done
            ) &
            PIDS+=($!)
            echo "Started Discord poller for channel ${CHANNEL_ID} (PID: ${PIDS[-1]})"
            ;;
    esac
done

echo "Multi-channel checker: ${#PIDS[@]} pollers active"

# Wait for all pollers (they run forever until parent dies)
cleanup() {
    for pid in "${PIDS[@]}"; do
        kill "${pid}" 2>/dev/null
    done
}
trap cleanup EXIT

wait
