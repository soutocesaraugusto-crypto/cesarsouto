#!/usr/bin/env bash
# session-router.sh — Deterministic session key generator
# Hermes reference: gateway/session.py build_session_key()
#
# Generates a deterministic session key from platform + chat_id + user_id + thread_id.
# Same input → same output across restarts.
#
# Usage:
#   session-router.sh <agent> <platform> <chat_id> [user_id] [thread_id]
#   Output: session key string
#
# Key format:
#   {agent}:{platform}:dm:{user_id}                      (DM)
#   {agent}:{platform}:group:{chat_id}:{user_id}         (Group + user)
#   {agent}:{platform}:group:{chat_id}:{thread_id}:{user_id}  (Group + thread + user)
#
# Epic 114 / Story 114.10

set -uo pipefail

AGENT="${1:-${CRM_AGENT_NAME:-prisma}}"
PLATFORM="${2:-telegram}"
CHAT_ID="${3:-}"
USER_ID="${4:-}"
THREAD_ID="${5:-}"

if [[ -z "${CHAT_ID}" ]]; then
    echo "Usage: session-router.sh <agent> <platform> <chat_id> [user_id] [thread_id]" >&2
    exit 1
fi

# Determine scope: DM vs Group
# Telegram: negative chat_id = group, positive = DM
# Discord: channel type determines scope
# Default: treat as DM if user_id == chat_id or no user_id
SCOPE="dm"
if [[ "${CHAT_ID}" =~ ^- ]]; then
    SCOPE="group"  # Telegram group (negative chat_id)
fi

# Build deterministic key
if [[ "${SCOPE}" == "dm" ]]; then
    # DM: use user_id (or chat_id as fallback)
    KEY="${AGENT}:${PLATFORM}:dm:${USER_ID:-${CHAT_ID}}"
elif [[ -n "${THREAD_ID}" ]]; then
    # Group + thread + user
    KEY="${AGENT}:${PLATFORM}:group:${CHAT_ID}:${THREAD_ID}:${USER_ID:-anonymous}"
else
    # Group + user
    KEY="${AGENT}:${PLATFORM}:group:${CHAT_ID}:${USER_ID:-anonymous}"
fi

echo "${KEY}"
