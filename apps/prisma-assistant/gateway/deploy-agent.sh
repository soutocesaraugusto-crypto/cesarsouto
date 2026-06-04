#!/usr/bin/env bash
# deploy-agent.sh — Deploy a message-gateway agent (100% local, zero external dependency)
#
# In the self-contained Prisma package, the wizard (instalar.sh) calls this
# script for you. You normally do NOT need to run it by hand.
#
# Source of truth (resolved files, written by instalar.sh from the package templates):
#   - SOUL.md / CLAUDE.md / config.json:  gateway/agents/<slug>/
#   - Gateway core:                       gateway/core/  (MIT-internalized bus)
#
# Path model (self-contained):
#   PRISMA_HOME defaults to the package root (gateway/..). The agent lives in
#   gateway/agents/<slug>/, which is exactly the path the runtime wrapper falls
#   back to when no external runtime dir exists.
#
# Secrets:
#   ~/.claude-remote/<instance>/config/<slug>/.env  (chmod 600, never committed)
#
# Usage:
#   bash deploy-agent.sh [agent_slug]      # default slug: prisma

set -euo pipefail

# --- Resolve paths ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GATEWAY_ROOT="${SCRIPT_DIR}"
# PRISMA_HOME is the install root. Default: the package root (one level above gateway/).
PRISMA_HOME="${PRISMA_HOME:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

AGENT_NAME="${1:-${PRISMA_AGENT_SLUG:-prisma}}"
# Agent runs self-contained inside the gateway template root (wrapper fallback path).
AGENT_DIR="${GATEWAY_ROOT}/agents/${AGENT_NAME}"
# Persona files are resolved by instalar.sh and written into the agent dir BEFORE
# this script runs. They are the single source of truth here (no OMNI templates).
SOUL_SOURCE="${AGENT_DIR}/SOUL.md"
CONFIG_TEMPLATE="${AGENT_DIR}/config.json"
CLAUDE_TEMPLATE="${AGENT_DIR}/CLAUDE.md"
AGENT_TEMPLATE="${GATEWAY_ROOT}/agents/agent-template"
SINKRA_HUB_PATH="${PRISMA_HOME}"
RUNTIME_DIR="${GATEWAY_ROOT}/agents"
# Read instance id from gateway .env if present (set by install.sh)
CRM_INSTANCE_ID="default"
[[ -f "${GATEWAY_ROOT}/.env" ]] && CRM_INSTANCE_ID="$(grep '^CRM_INSTANCE_ID=' "${GATEWAY_ROOT}/.env" 2>/dev/null | cut -d= -f2 || echo default)"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
ENV_DIR="${HOME}/.claude-remote/${CRM_INSTANCE_ID}/config/${AGENT_NAME}"
ENV_FILE="${ENV_DIR}/.env"

# --- Validation ---
echo "==========================================="
echo "  Message Gateway — Deploy"
echo "==========================================="
echo ""
echo "  Install root:  ${SINKRA_HUB_PATH}"
echo "  Gateway:       ${GATEWAY_ROOT}"
echo "  Agent:         ${AGENT_NAME}"
echo "  Agent dir:     ${AGENT_DIR}"
echo ""

if [[ ! -d "${GATEWAY_ROOT}/core" ]]; then
    echo "ERROR: Gateway core not found at ${GATEWAY_ROOT}/core/"
    echo "This should not happen — core/ is part of the package."
    exit 1
fi

# Persona files must already be resolved by instalar.sh
for required in "${SOUL_SOURCE}" "${CLAUDE_TEMPLATE}" "${CONFIG_TEMPLATE}"; do
    if [[ ! -f "${required}" ]]; then
        echo "ERROR: persona file not found: ${required}"
        echo "Run the wizard first:  bash instalar.sh"
        exit 1
    fi
done

# --- Check gateway is installed ---
if [[ ! -d "${HOME}/.claude-remote/${CRM_INSTANCE_ID}" ]]; then
    echo "Gateway not installed. Running install.sh..."
    bash "${GATEWAY_ROOT}/install.sh"
fi

# --- Create agent directory (scaffold from agent-template, preserve resolved files) ---
mkdir -p "${RUNTIME_DIR}"
echo "Preparing agent directory..."
if [[ ! -d "${AGENT_DIR}" ]]; then
    echo "  Copying scaffold from agent-template..."
    cp -r "${AGENT_TEMPLATE}" "${AGENT_DIR}"
else
    echo "  Agent dir exists — keeping resolved persona files."
    # Ensure skills/.claude scaffolding exists without clobbering persona files
    [[ -d "${AGENT_DIR}/skills" ]] || cp -r "${AGENT_TEMPLATE}/skills" "${AGENT_DIR}/skills" 2>/dev/null || true
    [[ -d "${AGENT_DIR}/.claude" ]] || cp -r "${AGENT_TEMPLATE}/.claude" "${AGENT_DIR}/.claude" 2>/dev/null || true
fi

# --- Deploy SOUL.md (skip if source already IS the destination) ---
if [[ "${SOUL_SOURCE}" != "${AGENT_DIR}/SOUL.md" ]]; then
    echo "Deploying SOUL.md..."
    cp "${SOUL_SOURCE}" "${AGENT_DIR}/SOUL.md"
fi

# --- Deploy CLAUDE.md (skip if source already IS the destination) ---
if [[ "${CLAUDE_TEMPLATE}" != "${AGENT_DIR}/CLAUDE.md" ]]; then
    echo "Deploying CLAUDE.md..."
    cp "${CLAUDE_TEMPLATE}" "${AGENT_DIR}/CLAUDE.md"
fi

# --- Deploy config.json (resolve install-root variables; skip self-copy) ---
if [[ "${CONFIG_TEMPLATE}" != "${AGENT_DIR}/config.json" ]]; then
    echo "Deploying config.json..."
    sed -e "s|\${SINKRA_HUB_PATH}|${SINKRA_HUB_PATH}|g" \
        -e "s|\${PRISMA_HOME}|${PRISMA_HOME}|g" \
        "${CONFIG_TEMPLATE}" > "${AGENT_DIR}/config.json"
fi

# --- Deploy advanced hooks settings.json (optional override) ---
# The agent-template already ships a generic .claude/settings.json.
# If a custom settings.json.template exists at the gateway root, it overrides it.
SETTINGS_TEMPLATE="${GATEWAY_ROOT}/settings.json.template"
if [[ -f "${SETTINGS_TEMPLATE}" ]]; then
    echo "Deploying custom hooks settings.json..."
    mkdir -p "${AGENT_DIR}/.claude"
    cp "${SETTINGS_TEMPLATE}" "${AGENT_DIR}/.claude/settings.json"
fi

# --- Setup .env (secrets — outside repo) ---
mkdir -p "${ENV_DIR}"

if [[ -f "${ENV_FILE}" ]]; then
    echo "Secrets .env exists at ${ENV_FILE} — preserving."
else
    echo ""
    echo "==========================================="
    echo "  SECRETS REQUIRED"
    echo "==========================================="
    echo ""
    echo "  Create ${ENV_FILE} with:"
    echo ""
    echo "    BOT_TOKEN=<your-telegram-bot-token>"
    echo "    CHAT_ID=<your-telegram-chat-id>"
    echo "    ALLOWED_USER=<your-telegram-user-id>"
    echo ""
    echo "  Then re-run this script."
    echo ""

    cat > "${ENV_FILE}" << 'ENVEOF'
BOT_TOKEN=
CHAT_ID=
ALLOWED_USER=
ENVEOF
    chmod 600 "${ENV_FILE}"
fi

# --- Symlink .env from secure location into agent dir ---
if [[ -f "${ENV_FILE}" ]]; then
    ln -sf "${ENV_FILE}" "${AGENT_DIR}/.env"
    echo "Linked .env: ${AGENT_DIR}/.env -> ${ENV_FILE}"
fi

# --- Verify ---
echo ""
echo "==========================================="
echo "  Deploy Complete"
echo "==========================================="
echo ""
echo "  Agent Dir:     ${AGENT_DIR}"
echo "  SOUL.md:       $(wc -l < "${AGENT_DIR}/SOUL.md") lines"
echo "  config.json:   $(cat "${AGENT_DIR}/config.json" | python3 -c "import sys,json; c=json.load(sys.stdin); print(f'model={c.get(\"model\",\"default\")}, working_dir={c.get(\"working_directory\",\"unset\")}')" 2>/dev/null || echo "parsed")"
echo "  .env:          $(if grep -q 'BOT_TOKEN=.\+' "${AGENT_DIR}/.env" 2>/dev/null; then echo "configured"; else echo "NEEDS CONFIGURATION"; fi)"
echo ""
echo "  Next steps:"
echo "    1. Ensure .env has BOT_TOKEN, CHAT_ID, ALLOWED_USER"
echo "    2. Run: bash ${GATEWAY_ROOT}/enable-agent.sh ${AGENT_NAME}"
echo "    3. Send a message to your Telegram bot"
echo ""
