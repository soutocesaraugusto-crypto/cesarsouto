#!/usr/bin/env bash
# export-conversation.sh — Export agent conversation as Markdown or JSON
#
# Reads from sessions.db (SQLite FTS5) and outputs formatted conversation.
#
# Usage:
#   export-conversation.sh <agent> [session_id] [format]
#   export-conversation.sh prisma                    # Latest session as MD
#   export-conversation.sh prisma abc123 json        # Specific session as JSON
#
# Output: saved to ~/.claude-remote/{instance}/exports/{agent}/
#
# Epic 114 / Story 114.12

set -uo pipefail

AGENT="${1:-${CRM_AGENT_NAME:-prisma}}"
SESSION_ID="${2:-}"
FORMAT="${3:-md}"

CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
DB_PATH="${CRM_ROOT}/state/${AGENT}/sessions.db"
EXPORT_DIR="${CRM_ROOT}/exports/${AGENT}"

mkdir -p "${EXPORT_DIR}" 2>/dev/null || true

if [[ ! -f "${DB_PATH}" ]]; then
    echo "No sessions database found at ${DB_PATH}" >&2
    echo "Sessions are stored after the first session ends via session-persist.sh" >&2
    exit 1
fi

# Resolve session_id
if [[ -z "${SESSION_ID}" ]]; then
    # Get latest session
    SESSION_ID=$(sqlite3 "${DB_PATH}" "SELECT id FROM sessions ORDER BY ended_at DESC LIMIT 1" 2>/dev/null || echo "")
    if [[ -z "${SESSION_ID}" ]]; then
        echo "No sessions found in database" >&2
        exit 1
    fi
fi

# Sanitize SESSION_ID to prevent SQL injection (QA fix 114.12)
if [[ ! "${SESSION_ID}" =~ ^[a-zA-Z0-9_.:-]+$ ]]; then
    echo "Invalid session ID format: ${SESSION_ID}" >&2
    exit 1
fi

# Get session metadata
SESSION_META=$(sqlite3 -json "${DB_PATH}" "
    SELECT id, started_at, ended_at, duration_seconds, cwd
    FROM sessions WHERE id = '${SESSION_ID}'
    LIMIT 1
" 2>/dev/null || echo "[]")

if [[ "${SESSION_META}" == "[]" || -z "${SESSION_META}" ]]; then
    echo "Session not found: ${SESSION_ID}" >&2
    exit 1
fi

TIMESTAMP=$(date -u +"%Y%m%dT%H%M%S")
EXPORT_FILE="${EXPORT_DIR}/${TIMESTAMP}-${SESSION_ID}.${FORMAT}"

case "${FORMAT}" in
    md|markdown)
        {
            echo "# Conversation Export"
            echo ""
            echo "- **Session:** ${SESSION_ID}"
            echo "- **Agent:** ${AGENT}"
            echo "- **Exported:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
            echo ""
            echo "---"
            echo ""

            # Use unit separator (0x1F) to avoid pipe collision in content (QA fix 114.12)
            sqlite3 -separator $'\x1f' "${DB_PATH}" "
                SELECT role, timestamp, content
                FROM messages
                WHERE session_id = '${SESSION_ID}'
                ORDER BY timestamp ASC
            " 2>/dev/null | while IFS=$'\x1f' read -r role ts content; do
                case "${role}" in
                    user) echo "### User (${ts})" ;;
                    assistant) echo "### Assistant (${ts})" ;;
                    system) echo "### System (${ts})" ;;
                    *) echo "### ${role} (${ts})" ;;
                esac
                echo ""
                echo "${content}"
                echo ""
                echo "---"
                echo ""
            done
        } > "${EXPORT_FILE}"
        ;;

    json)
        sqlite3 -json "${DB_PATH}" "
            SELECT role, content, timestamp
            FROM messages
            WHERE session_id = '${SESSION_ID}'
            ORDER BY timestamp ASC
        " 2>/dev/null > "${EXPORT_FILE}"
        ;;

    *)
        echo "Unknown format: ${FORMAT}. Supported: md, json" >&2
        exit 1
        ;;
esac

echo "${EXPORT_FILE}"
