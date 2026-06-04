#!/usr/bin/env bash
# setup-channel.sh — Interactive channel onboarding for AIOX Message Gateway
#
# Guides the user through configuring each channel (Telegram, Web Chat, Discord).
# Updates the agent config.json (gateway/agents/<slug>/) with channel settings.
#
# Usage:
#   bash gateway/setup-channel.sh
#
# Epic 110 Story 110.22

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRISMA_HOME="${PRISMA_HOME:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
AGENT_SLUG="${PRISMA_AGENT_SLUG:-${CRM_AGENT_NAME:-prisma}}"
RUNTIME_DIR="${SCRIPT_DIR}/agents"
CRM_INSTANCE_ID="default"
[[ -f "${SCRIPT_DIR}/.env" ]] && CRM_INSTANCE_ID="$(grep '^CRM_INSTANCE_ID=' "${SCRIPT_DIR}/.env" 2>/dev/null | cut -d= -f2 || echo default)"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
ENV_DIR="${HOME}/.claude-remote/${CRM_INSTANCE_ID}/config/${AGENT_SLUG}"
ENV_FILE="${ENV_DIR}/.env"

mkdir -p "${RUNTIME_DIR}" "${ENV_DIR}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}  AIOX Message Gateway — Channel Setup${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""
echo "  Channels available:"
echo ""
echo -e "  ${GREEN}[1]${NC} Telegram  — Bot via @BotFather (mobile + desktop)"
echo -e "  ${GREEN}[2]${NC} Web Chat  — Local browser UI (localhost, zero config)"
echo -e "  ${GREEN}[3]${NC} Discord   — Bot via Developer Portal (desktop + mobile)"
echo ""
echo -e "  ${YELLOW}[4]${NC} Show current config"
echo -e "  ${YELLOW}[5]${NC} Exit"
echo ""

read -p "  Select channel to configure [1-5]: " choice

case "${choice}" in
    1)
        echo ""
        echo -e "${CYAN}--- Telegram Setup ---${NC}"
        echo ""

        # Check if already configured
        if [[ -f "${ENV_FILE}" ]] && grep -q "BOT_TOKEN=.\+" "${ENV_FILE}" 2>/dev/null; then
            echo -e "  ${GREEN}Telegram already configured.${NC}"
            echo "  Token: $(grep BOT_TOKEN "${ENV_FILE}" | cut -d= -f2 | cut -c1-10)..."
            echo ""
            read -p "  Reconfigure? [y/N]: " reconf
            [[ "${reconf}" != "y" && "${reconf}" != "Y" ]] && exit 0
        fi

        echo "  Step 1: Create a bot on Telegram"
        echo "    → Open Telegram and message @BotFather"
        echo "    → Send: /newbot"
        echo "    → Choose a name and username"
        echo "    → Copy the bot token"
        echo ""
        read -p "  Paste your bot token: " BOT_TOKEN

        if [[ -z "${BOT_TOKEN}" ]]; then
            echo -e "  ${RED}No token provided. Aborting.${NC}"
            exit 1
        fi

        echo ""
        echo "  Step 2: Get your chat ID"
        echo "    → Send any message to your new bot on Telegram"
        read -p "  Press Enter after sending a message..."

        echo "  Fetching chat ID..."
        CHAT_ID=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" | \
            python3 -c "import sys,json; r=json.load(sys.stdin).get('result',[]); print(r[-1]['message']['from']['id'] if r else '')" 2>/dev/null)

        if [[ -z "${CHAT_ID}" ]]; then
            echo -e "  ${RED}Could not fetch chat ID. Make sure you sent a message to the bot.${NC}"
            read -p "  Enter chat ID manually: " CHAT_ID
        fi

        echo -e "  ${GREEN}Chat ID: ${CHAT_ID}${NC}"
        echo ""

        # Flush offset so old messages don't replay
        LAST_UPDATE=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" | \
            python3 -c "import sys,json; r=json.load(sys.stdin).get('result',[]); print(r[-1]['update_id']+1 if r else '')" 2>/dev/null)
        if [[ -n "${LAST_UPDATE}" ]]; then
            curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${LAST_UPDATE}" > /dev/null 2>&1
        fi

        # Save to .env
        cat > "${ENV_FILE}" << EOF
BOT_TOKEN=${BOT_TOKEN}
CHAT_ID=${CHAT_ID}
ALLOWED_USER=${CHAT_ID}
EOF
        chmod 600 "${ENV_FILE}"

        echo -e "  ${GREEN}Telegram configured!${NC}"
        echo "  Secrets saved to: ${ENV_FILE}"
        echo ""
        echo "  Next steps:"
        echo "    bash ${SCRIPT_DIR}/deploy-agent.sh ${AGENT_SLUG}"
        echo "    bash ${SCRIPT_DIR}/enable-agent.sh ${AGENT_SLUG}"
        ;;

    2)
        echo ""
        echo -e "${CYAN}--- Web Chat Setup ---${NC}"
        echo ""
        echo "  Web Chat runs locally — zero external config needed."
        echo ""

        read -p "  Port [8080]: " WEB_PORT
        WEB_PORT="${WEB_PORT:-8080}"

        echo ""
        echo -e "  ${GREEN}Web Chat configured on port ${WEB_PORT}${NC}"
        echo ""
        echo "  To start:"
        echo "    python3 gateway/web-chat-server.py --port ${WEB_PORT}"
        echo ""
        echo "  Then open: http://localhost:${WEB_PORT}"
        echo ""
        echo "  To enable as channel in agent config, add to gateway/agents/'${AGENT_SLUG}'/config.json:"
        echo "    {\"type\": \"web\", \"enabled\": true, \"port\": ${WEB_PORT}}"
        ;;

    3)
        echo ""
        echo -e "${CYAN}--- Discord Setup ---${NC}"
        echo ""
        echo "  Step 1: Create a Discord Application"
        echo "    → Go to: https://discord.com/developers/applications"
        echo "    → Click 'New Application' → name it"
        echo "    → Go to 'Bot' tab → click 'Add Bot'"
        echo "    → Copy the bot token"
        echo ""
        read -p "  Paste your Discord bot token: " DISCORD_TOKEN

        if [[ -z "${DISCORD_TOKEN}" ]]; then
            echo -e "  ${RED}No token provided. Aborting.${NC}"
            exit 1
        fi

        echo ""
        echo "  Step 2: Invite bot to your server"
        echo "    → Go to 'OAuth2' → 'URL Generator'"
        echo "    → Select scopes: bot"
        echo "    → Select permissions: Send Messages, Read Message History, Add Reactions"
        echo "    → Copy the invite URL and open it in browser"
        echo ""
        read -p "  Press Enter after inviting the bot..."

        echo ""
        echo "  Step 3: Get channel ID"
        echo "    → In Discord, enable Developer Mode (Settings → Advanced → Developer Mode)"
        echo "    → Right-click the channel you want the bot in → 'Copy Channel ID'"
        echo ""
        read -p "  Paste channel ID: " DISCORD_CHANNEL_ID

        echo ""
        read -p "  Your Discord user ID (right-click your name → Copy User ID): " DISCORD_ALLOWED_USER

        # Save Discord config
        cat >> "${ENV_FILE}" << EOF

# Discord
DISCORD_TOKEN=${DISCORD_TOKEN}
DISCORD_CHANNEL_ID=${DISCORD_CHANNEL_ID}
DISCORD_ALLOWED_USER=${DISCORD_ALLOWED_USER}
EOF
        chmod 600 "${ENV_FILE}"

        echo ""
        echo -e "  ${GREEN}Discord configured!${NC}"
        echo "  Secrets appended to: ${ENV_FILE}"
        echo ""
        echo "  To enable as channel in agent config, add to gateway/agents/'${AGENT_SLUG}'/config.json:"
        echo "    {\"type\": \"discord\", \"enabled\": true, \"channel_id\": \"${DISCORD_CHANNEL_ID}\"}"
        ;;

    4)
        echo ""
        echo -e "${CYAN}--- Current Configuration ---${NC}"
        echo ""
        echo "  Secrets (.env):"
        if [[ -f "${ENV_FILE}" ]]; then
            grep -E "^[A-Z]" "${ENV_FILE}" | while IFS= read -r line; do
                key=$(echo "${line}" | cut -d= -f1)
                val=$(echo "${line}" | cut -d= -f2)
                echo "    ${key}=${val:0:10}..."
            done
        else
            echo "    Not configured"
        fi
        echo ""
        echo "  SOUL.md:"
        test -f "${RUNTIME_DIR}/SOUL.md" && echo "    $(wc -l < "${RUNTIME_DIR}/SOUL.md") lines" || echo "    Not found"
        echo ""
        echo "  config.yaml:"
        test -f "${RUNTIME_DIR}/config.yaml" && echo "    $(wc -l < "${RUNTIME_DIR}/config.yaml") lines" || echo "    Not found"
        echo ""
        echo "  Agent deployed:"
        test -d "${RUNTIME_DIR}/${AGENT_SLUG}" && echo "    YES" || echo "    NO — run deploy-agent.sh"
        echo ""
        echo "  Service status:"
        launchctl list 2>/dev/null | grep claude-remote || echo "    Not running"
        ;;

    5)
        echo "  Bye!"
        exit 0
        ;;

    *)
        echo -e "  ${RED}Invalid option.${NC}"
        exit 1
        ;;
esac
