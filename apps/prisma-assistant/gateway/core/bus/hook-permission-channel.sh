#!/usr/bin/env bash
# hook-permission-channel.sh — Channel-agnostic permission request hook (router)
#
# Routes PermissionRequest to the correct channel's approval UI:
# - Telegram: inline keyboard buttons (Approve/Deny)
# - Web: HTML buttons in chat UI
# - Discord: button components
#
# Usage (as hook):
#   hook-permission-channel.sh   (reads JSON from stdin)
#
# Environment:
#   CHANNEL_TYPE - Channel to route to
#
# Epic 110 Story 110.16

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHANNEL_TYPE="${CHANNEL_TYPE:-telegram}"

case "${CHANNEL_TYPE}" in
    telegram)
        bash "${SCRIPT_DIR}/hook-permission-telegram.sh"
        ;;
    web)
        bash "${SCRIPT_DIR}/hook-permission-web.sh"
        ;;
    discord)
        bash "${SCRIPT_DIR}/hook-permission-discord.sh"
        ;;
    whatsapp)
        bash "${SCRIPT_DIR}/hook-permission-whatsapp.sh"
        ;;
    slack)
        bash "${SCRIPT_DIR}/hook-permission-slack.sh"
        ;;
    *)
        # Fallback: auto-approve (dangerous — only for dev)
        echo '{"hookSpecificOutput":{"decision":"approve"}}'
        ;;
esac
