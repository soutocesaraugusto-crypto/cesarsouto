#!/usr/bin/env bash
# stop-persistence.sh — Dispatcher: routes to the correct OS-specific persistence stop
# Usage: stop-persistence.sh <agent_name>
#
# Delegates to:
#   darwin  → launchctl unload
#   linux   → stop-systemd.sh
#   windows → stop-schtasks.sh
#
# Story 114.24 — Cross-Platform Persistence

set -euo pipefail

AGENT="${1:?Usage: stop-persistence.sh <agent_name>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=detect-platform.sh
source "${SCRIPT_DIR}/detect-platform.sh"

# Load instance ID
TEMPLATE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${TEMPLATE_ROOT}/.env"
if [[ -f "${ENV_FILE}" ]]; then
    CRM_INSTANCE_ID=$(grep '^CRM_INSTANCE_ID=' "${ENV_FILE}" | cut -d= -f2)
fi
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"

case "${CRM_PLATFORM}" in
    darwin)
        PLIST="${HOME}/Library/LaunchAgents/com.claude-remote.${CRM_INSTANCE_ID}.${AGENT}.plist"
        if [[ -f "${PLIST}" ]]; then
            launchctl unload "${PLIST}" 2>/dev/null || true
            echo "  launchd: unloaded"
        fi
        ;;
    linux)
        exec "${SCRIPT_DIR}/stop-systemd.sh" "${AGENT}"
        ;;
    windows)
        exec "${SCRIPT_DIR}/stop-schtasks.sh" "${AGENT}"
        ;;
    *)
        echo "WARNING: Unknown platform '${CRM_PLATFORM}' — no persistence to stop" >&2
        ;;
esac
