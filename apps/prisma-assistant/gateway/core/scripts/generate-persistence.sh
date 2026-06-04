#!/usr/bin/env bash
# generate-persistence.sh — Dispatcher: routes to the correct OS-specific persistence generator
# Usage: generate-persistence.sh <agent_name>
#
# Delegates to:
#   darwin  → generate-launchd.sh
#   linux   → generate-systemd.sh
#   windows → generate-schtasks.sh
#
# Story 114.24 — Cross-Platform Persistence

set -euo pipefail

AGENT="${1:?Usage: generate-persistence.sh <agent_name>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=detect-platform.sh
source "${SCRIPT_DIR}/detect-platform.sh"

case "${CRM_PLATFORM}" in
    darwin)
        exec "${SCRIPT_DIR}/generate-launchd.sh" "${AGENT}"
        ;;
    linux)
        exec "${SCRIPT_DIR}/generate-systemd.sh" "${AGENT}"
        ;;
    windows)
        exec "${SCRIPT_DIR}/generate-schtasks.sh" "${AGENT}"
        ;;
    *)
        echo "ERROR: Unsupported platform '${CRM_PLATFORM}'. Supported: darwin, linux, windows." >&2
        echo "You can run the agent manually: bash core/scripts/agent-wrapper.sh ${AGENT} \$(pwd)" >&2
        exit 1
        ;;
esac
