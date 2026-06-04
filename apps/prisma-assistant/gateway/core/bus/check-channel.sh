#!/usr/bin/env bash
# check-channel.sh — Channel-agnostic message poller (router)
#
# Routes polling to the correct channel adapter based on CHANNEL_TYPE.
# Returns JSON array of new messages in unified format:
#   [{"id": "msg_id", "from": "user_name", "from_id": "user_id", "text": "message", "channel": "telegram"}]
#
# Usage:
#   bash check-channel.sh [offset]
#
# Environment:
#   CHANNEL_TYPE - Channel to poll (telegram|web|discord)
#
# Epic 110 Story 110.16

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHANNEL_TYPE="${CHANNEL_TYPE:-telegram}"

case "${CHANNEL_TYPE}" in
    telegram)
        bash "${SCRIPT_DIR}/check-telegram.sh" "$@"
        ;;
    web)
        bash "${SCRIPT_DIR}/check-web.sh" "$@"
        ;;
    discord)
        bash "${SCRIPT_DIR}/check-discord.sh" "$@"
        ;;
    whatsapp)
        bash "${SCRIPT_DIR}/check-whatsapp.sh" "$@"
        ;;
    slack)
        bash "${SCRIPT_DIR}/check-slack.sh" "$@"
        ;;
    *)
        echo "[]"
        ;;
esac
