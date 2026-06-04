#!/usr/bin/env bash
# prefetch.sh — Session Recall memory provider: prefetch hook
# Searches past sessions via FTS5 for context relevant to the current query.
#
# Usage: prefetch.sh <agent> "<query>"
# Output: Relevant session excerpts (text, max 500 chars)
#
# Epic 114 / Story 114.9

set -uo pipefail

AGENT="${1:-prisma}"
QUERY="${2:-}"

[[ -z "${QUERY}" ]] && exit 0

CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
DB_PATH="${CRM_ROOT}/state/${AGENT}/sessions.db"

[[ ! -f "${DB_PATH}" ]] && exit 0

# FTS5 search with snippet (truncate to 500 chars)
RESULT=$(sqlite3 "${DB_PATH}" "
    SELECT snippet(messages_fts, 1, '>>>', '<<<', '...', 30)
    FROM messages_fts
    WHERE messages_fts MATCH '${QUERY//\'/\'\'}'
    ORDER BY rank LIMIT 2
" 2>/dev/null || echo "")

[[ -z "${RESULT}" ]] && exit 0

echo "[Session Memory] Relevant context from past sessions:"
echo "${RESULT}" | head -c 500
