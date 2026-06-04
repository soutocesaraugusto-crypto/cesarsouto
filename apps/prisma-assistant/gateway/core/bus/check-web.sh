#!/usr/bin/env bash
# check-web.sh — Poll local Web Chat for new messages
#
# Returns JSON array of new messages since last offset.
#
# Usage: bash check-web.sh [since_id]
#
# Environment:
#   WEB_PORT - Web chat port (default: 8080)
#   WEB_HOST - Web chat host (default: localhost)
#
# Epic 110 Story 110.17

set -uo pipefail

WEB_HOST="${WEB_HOST:-localhost}"
WEB_PORT="${WEB_PORT:-8080}"
SINCE="${1:-0}"

curl -s "http://${WEB_HOST}:${WEB_PORT}/api/messages?since=${SINCE}" 2>/dev/null || echo "[]"
