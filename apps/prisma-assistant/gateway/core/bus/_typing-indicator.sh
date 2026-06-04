#!/usr/bin/env bash
# _typing-indicator.sh — Cross-channel typing indicator manager
#
# Starts/stops a background process that continuously sends typing indicators
# to the chat platform. Telegram/Discord typing expires after ~5s, so we
# refresh every 2s (aligned with Hermes _keep_typing pattern).
#
# Usage:
#   source _typing-indicator.sh
#   typing_start "telegram" "${BOT_TOKEN}" "${CHAT_ID}"
#   ... (agent processes message) ...
#   typing_stop "telegram"
#
# Supports: telegram, discord, slack, whatsapp, web
# Reference: Hermes gateway/platforms/base.py _keep_typing()

# Start persistent typing indicator for a channel.
# Spawns a background process that refreshes every 2s until stopped.
typing_start() {
    local platform="$1"
    local agent="${CRM_AGENT_NAME:-prisma}"
    local crm_root="${CRM_ROOT:-${HOME}/.claude-remote/default}"
    local pid_file="${crm_root}/state/${agent}/.typing-${platform}.pid"

    mkdir -p "${crm_root}/state/${agent}" 2>/dev/null || true

    # Kill existing typing loop
    typing_stop "${platform}"

    local cmd=""
    case "${platform}" in
        telegram)
            local token="${2:-${BOT_TOKEN:-}}"
            local chat_id="${3:-${CHAT_ID:-}}"
            [[ -z "${token}" || -z "${chat_id}" ]] && return 0
            cmd="curl -s -X POST 'https://api.telegram.org/bot${token}/sendChatAction' -d 'chat_id=${chat_id}' -d 'action=typing'"
            ;;
        discord)
            local token="${2:-${DISCORD_TOKEN:-}}"
            local channel_id="${3:-}"
            [[ -z "${token}" || -z "${channel_id}" ]] && return 0
            cmd="curl -s -X POST 'https://discord.com/api/v10/channels/${channel_id}/typing' -H 'Authorization: Bot ${token}' -H 'Content-Length: 0'"
            ;;
        slack)
            # Slack doesn't have a persistent typing API — skip
            return 0
            ;;
        whatsapp)
            local port="${2:-${WHATSAPP_BRIDGE_PORT:-8445}}"
            local recipient="${3:-}"
            [[ -z "${recipient}" ]] && return 0
            cmd="curl -s -X POST 'http://127.0.0.1:${port}/typing' -H 'Content-Type: application/json' -d '{\"to\":\"${recipient}\"}'"
            ;;
        web)
            # Web chat doesn't need typing (responses are instant from server perspective)
            return 0
            ;;
        *)
            return 0
            ;;
    esac

    if [[ -n "${cmd}" ]]; then
        bash -c "while true; do ${cmd} > /dev/null 2>&1; sleep 2; done" &
        echo $! > "${pid_file}"
        disown $! 2>/dev/null || true
    fi
}

# Stop typing indicator for a channel.
typing_stop() {
    local platform="$1"
    local agent="${CRM_AGENT_NAME:-prisma}"
    local crm_root="${CRM_ROOT:-${HOME}/.claude-remote/default}"
    local pid_file="${crm_root}/state/${agent}/.typing-${platform}.pid"

    if [[ -f "${pid_file}" ]]; then
        kill "$(cat "${pid_file}")" 2>/dev/null || true
        rm -f "${pid_file}"
    fi
}

# Stop ALL typing indicators (called on agent shutdown).
typing_stop_all() {
    for platform in telegram discord whatsapp; do
        typing_stop "${platform}"
    done
}
