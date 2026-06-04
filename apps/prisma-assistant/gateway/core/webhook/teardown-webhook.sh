#!/usr/bin/env bash
# teardown-webhook.sh - Remove Telegram webhook and revert to polling mode
#
# Usage: teardown-webhook.sh
#
# This removes the webhook from Telegram (so getUpdates works again)
# and cleans up local webhook config files.
#
# Story 110.27 Phase 1

set -euo pipefail

TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
CRM_AGENT_NAME="${CRM_AGENT_NAME:-$(basename "$(pwd)")}"
ME="${CRM_AGENT_NAME}"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"

# Source .env for BOT_TOKEN
ENV_FILE="${TEMPLATE_ROOT}/agents/${ME}/.env"
{ set +x; } 2>/dev/null
if [[ -f "${ENV_FILE}" ]]; then
    set -a; source "${ENV_FILE}"; set +a
elif [[ -f ".env" ]]; then
    set -a; source ".env"; set +a
fi

if [[ -z "${BOT_TOKEN:-}" ]]; then
    echo "ERROR: BOT_TOKEN not configured." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../bus/_telegram-curl.sh"

echo "Removing Telegram webhook..."

RESPONSE=$(telegram_api_post "deleteWebhook" -d "drop_pending_updates=false")

if echo "${RESPONSE}" | jq -e '.ok' > /dev/null 2>&1; then
    echo "Webhook removed. Bot is now in polling mode."
    echo ""
    echo "Next steps:"
    echo "  1. Update agent .env:"
    echo "     WEBHOOK_MODE=false   (or remove the line)"
    echo ""
    echo "  2. Restart the agent:"
    echo "     bash ${TEMPLATE_ROOT}/enable-agent.sh ${ME} --restart"
    echo ""

    # Clean up local files (keep secret in case user re-enables)
    CONFIG_DIR="${HOME}/.claude-remote/${CRM_INSTANCE_ID}/config/${ME}"
    rm -f "${CONFIG_DIR}/.webhook-url" 2>/dev/null || true
else
    echo "ERROR: Failed to remove webhook" >&2
    echo "${RESPONSE}" | jq -r '.description // "Unknown error"' >&2
    exit 1
fi
