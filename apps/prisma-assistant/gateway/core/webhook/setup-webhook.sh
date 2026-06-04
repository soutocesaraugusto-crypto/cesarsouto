#!/usr/bin/env bash
# setup-webhook.sh - Register Telegram webhook for instant message delivery
#
# Usage: setup-webhook.sh <webhook_url>
#        setup-webhook.sh --auto   (auto-detect ngrok/cloudflared tunnel)
#        setup-webhook.sh --info   (show current webhook info)
#
# The webhook URL must be HTTPS. Options:
#   A) ngrok:       ngrok http 8443 → auto-detected
#   B) cloudflared: cloudflared tunnel --url http://localhost:8443 → auto-detected
#   C) Direct:      provide full URL, e.g. https://myserver.com:8443/webhook/prisma
#
# Story 110.27 Phase 1

set -euo pipefail

TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
CRM_AGENT_NAME="${CRM_AGENT_NAME:-$(basename "$(pwd)")}"
ME="${CRM_AGENT_NAME}"

# Source .env for BOT_TOKEN
ENV_FILE="${TEMPLATE_ROOT}/agents/${ME}/.env"
{ set +x; } 2>/dev/null
if [[ -f "${ENV_FILE}" ]]; then
    set -a; source "${ENV_FILE}"; set +a
elif [[ -f ".env" ]]; then
    set -a; source ".env"; set +a
fi

if [[ -z "${BOT_TOKEN:-}" ]]; then
    echo "ERROR: BOT_TOKEN not configured. Run setup-channel.sh first." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../bus/_telegram-curl.sh"

WEBHOOK_PORT="${WEBHOOK_PORT:-8443}"
ACTION="${1:---info}"

# Generate or load secret token
SECRET_FILE="${HOME}/.claude-remote/${CRM_INSTANCE_ID:-default}/config/${ME}/.webhook-secret"
generate_secret() {
    local secret
    secret=$(openssl rand -hex 32 2>/dev/null || od -An -tx1 -N32 /dev/urandom | tr -d ' \n')
    mkdir -p "$(dirname "${SECRET_FILE}")"
    echo "${secret}" > "${SECRET_FILE}"
    chmod 600 "${SECRET_FILE}"
    echo "${secret}"
}

load_or_create_secret() {
    if [[ -f "${SECRET_FILE}" ]]; then
        cat "${SECRET_FILE}"
    else
        generate_secret
    fi
}

# Auto-detect tunnel URL
detect_tunnel_url() {
    # Try ngrok first
    if command -v ngrok &>/dev/null; then
        local ngrok_url
        ngrok_url=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null \
            | jq -r '.tunnels[] | select(.proto == "https") | .public_url' 2>/dev/null \
            | head -1)
        if [[ -n "${ngrok_url}" ]]; then
            echo "${ngrok_url}/webhook/${ME}"
            return 0
        fi
    fi

    # Try cloudflared
    if command -v cloudflared &>/dev/null; then
        # cloudflared quick tunnels print the URL to stderr on startup.
        # If running, check the metrics endpoint.
        local cf_url
        cf_url=$(curl -s http://localhost:20241/metrics 2>/dev/null \
            | grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' \
            | head -1)
        if [[ -n "${cf_url}" ]]; then
            echo "${cf_url}/webhook/${ME}"
            return 0
        fi
    fi

    echo ""
    return 1
}

# Show current webhook info
show_info() {
    echo "=== Telegram Webhook Info ==="
    RESPONSE=$(telegram_api_get "getWebhookInfo" 2>/dev/null)
    echo "${RESPONSE}" | jq '.' 2>/dev/null || echo "${RESPONSE}"
    echo ""
    URL=$(echo "${RESPONSE}" | jq -r '.result.url // ""' 2>/dev/null)
    if [[ -n "${URL}" ]]; then
        echo "Status: WEBHOOK ACTIVE"
        echo "URL: ${URL}"
        PENDING=$(echo "${RESPONSE}" | jq -r '.result.pending_update_count // 0' 2>/dev/null)
        echo "Pending updates: ${PENDING}"
        LAST_ERROR=$(echo "${RESPONSE}" | jq -r '.result.last_error_message // "none"' 2>/dev/null)
        echo "Last error: ${LAST_ERROR}"
    else
        echo "Status: NO WEBHOOK (polling mode)"
    fi
}

# Register webhook
register_webhook() {
    local url="$1"
    local secret
    secret=$(load_or_create_secret)

    echo "Registering webhook..."
    echo "  URL: ${url}"
    echo "  Agent: ${ME}"
    echo "  Secret: ${SECRET_FILE}"

    RESPONSE=$(telegram_api_post "setWebhook" \
        --data-urlencode "url=${url}" \
        -d "secret_token=${secret}" \
        -d "allowed_updates=[\"message\",\"callback_query\"]" \
        -d "drop_pending_updates=false")

    if echo "${RESPONSE}" | jq -e '.ok' > /dev/null 2>&1; then
        echo ""
        echo "Webhook registered successfully!"
        echo ""
        echo "Next steps:"
        echo "  1. Add to agent .env:"
        echo "     WEBHOOK_MODE=true"
        echo "     WEBHOOK_SECRET=${secret}"
        echo "     WEBHOOK_PORT=${WEBHOOK_PORT}"
        echo ""
        echo "  2. Start the webhook receiver:"
        echo "     python3 ${SCRIPT_DIR}/webhook-receiver.py"
        echo ""
        echo "  3. Restart the agent (it will use inbox-only mode):"
        echo "     bash ${TEMPLATE_ROOT}/enable-agent.sh ${ME} --restart"
        echo ""

        # Save webhook URL for reference
        echo "${url}" > "${HOME}/.claude-remote/${CRM_INSTANCE_ID:-default}/config/${ME}/.webhook-url"
    else
        echo "ERROR: Failed to register webhook" >&2
        echo "${RESPONSE}" | jq -r '.description // "Unknown error"' >&2
        exit 1
    fi
}

case "${ACTION}" in
    --info)
        show_info
        ;;
    --auto)
        echo "Auto-detecting tunnel URL..."
        URL=$(detect_tunnel_url)
        if [[ -z "${URL}" ]]; then
            echo "ERROR: No tunnel detected." >&2
            echo "" >&2
            echo "Start a tunnel first:" >&2
            echo "  ngrok http ${WEBHOOK_PORT}" >&2
            echo "  # or" >&2
            echo "  cloudflared tunnel --url http://localhost:${WEBHOOK_PORT}" >&2
            exit 1
        fi
        echo "Detected: ${URL}"
        register_webhook "${URL}"
        ;;
    --help|-h)
        echo "Usage: setup-webhook.sh <webhook_url>"
        echo "       setup-webhook.sh --auto    (detect ngrok/cloudflared)"
        echo "       setup-webhook.sh --info    (show current webhook)"
        echo ""
        echo "The webhook URL must be HTTPS and point to port ${WEBHOOK_PORT}."
        echo "Endpoint path: /webhook/${ME}"
        ;;
    *)
        URL="${ACTION}"
        # Append endpoint path if not already present
        if [[ "${URL}" != *"/webhook/"* ]]; then
            URL="${URL%/}/webhook/${ME}"
        fi
        register_webhook "${URL}"
        ;;
esac
