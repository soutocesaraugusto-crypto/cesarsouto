#!/usr/bin/env bash
# deliver-outbound.sh — Public wrapper for outbound pipeline
#
# Identical to send-channel.sh but accepts <agent> as first parameter.
# Used by deliver-multi.sh and external scripts that need to specify the agent.
#
# Usage:
#   deliver-outbound.sh <agent> <platform> <chat_id> "<message>" [flags...]
#   deliver-outbound.sh prisma telegram 123456 "Hello" --topic general
#
# Story 114.19 Phase 3 — Outbound Pipeline Formalization

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

AGENT="${1:-${CRM_AGENT_NAME:-prisma}}"
shift 1 2>/dev/null || true

export CRM_AGENT_NAME="${AGENT}"
exec bash "${SCRIPT_DIR}/send-channel.sh" "$@"
