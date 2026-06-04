#!/usr/bin/env bash
# check-whatsapp.sh — WhatsApp message checker (bridge wrapper)
#
# In ADAPTER_MODE: the bridge writes directly to channel-inbox/ (noop).
# In legacy mode: polls bridge HTTP API for new messages.
#
# Usage: bash check-whatsapp.sh
#
# Story 114.18 Phase 3

set -uo pipefail

# In adapter mode, bridge writes to channel-inbox/ directly — nothing to do
if [[ "${ADAPTER_MODE:-false}" == "true" ]]; then
    exit 0
fi

# Legacy polling mode (not recommended — use adapter mode)
WHATSAPP_BRIDGE_PORT="${WHATSAPP_BRIDGE_PORT:-8445}"
BRIDGE_URL="http://127.0.0.1:${WHATSAPP_BRIDGE_PORT}"

# Check bridge health
HEALTH=$(curl -s --max-time 3 "${BRIDGE_URL}/health" 2>/dev/null || echo "")
if [[ -z "${HEALTH}" ]]; then
    echo "[]"
    exit 0
fi

# Bridge handles message ingestion into channel-inbox/ already
# This script is a noop in both modes since bridge does the heavy lifting
echo "[]"
