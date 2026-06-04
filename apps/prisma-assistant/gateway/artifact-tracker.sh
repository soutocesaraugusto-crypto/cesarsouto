#!/usr/bin/env bash
# artifact-tracker.sh — PostToolUse(Write/Edit) hook: track artifacts + drift detection
#
# On Write/Edit: register file with SHA-256 hash in artifacts.db
# On Read (PreToolUse): compare hash — if changed externally, alert drift
#
# Epic 110 Story 110.12 | Design reference: OpenClaw drift detection (SHA-256 baseline)
#
# Usage as PostToolUse hook:
#   HOOK_EVENT=PostToolUse artifact-tracker.sh   (stdin: JSON with tool_name, tool_input)
# Usage as PreToolUse hook:
#   HOOK_EVENT=PreToolUse artifact-tracker.sh    (stdin: JSON with tool_name, tool_input)

set -uo pipefail

AGENT="${CRM_AGENT_NAME:-prisma}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/default}"
STATE_DIR="${CRM_ROOT}/state/${AGENT}"
DB_PATH="${STATE_DIR}/artifacts.db"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "${STATE_DIR}"

# Read hook input
HOOK_INPUT=$(cat 2>/dev/null || echo '{}')
TOOL_NAME=$(echo "${HOOK_INPUT}" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
FILE_PATH=$(echo "${HOOK_INPUT}" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
SESSION_ID=$(echo "${HOOK_INPUT}" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

# Only track actual file operations
if [[ -z "${FILE_PATH}" || -z "${TOOL_NAME}" ]]; then
    exit 0
fi

# Skip non-project files (but allow /var/folders temp dirs for testing)
case "${FILE_PATH}" in
    /tmp/*|/var/log/*|/dev/*|~/.claude-remote/*) exit 0 ;;
esac

# Initialize DB
python3 -c "
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
conn.executescript('''
    PRAGMA journal_mode=WAL;
    PRAGMA busy_timeout=3000;
    CREATE TABLE IF NOT EXISTS artifacts (
        file_path TEXT PRIMARY KEY,
        sha256 TEXT NOT NULL,
        last_session_id TEXT,
        last_modified_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        modify_count INTEGER DEFAULT 1
    );
''')
conn.close()
" "${DB_PATH}" 2>/dev/null

case "${TOOL_NAME}" in
    Write|Edit)
        # Register/update artifact with current hash
        if [[ -f "${FILE_PATH}" ]]; then
            SHA=$(shasum -a 256 "${FILE_PATH}" 2>/dev/null | cut -d' ' -f1)
            python3 -c "
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
conn.execute('''
    INSERT INTO artifacts (file_path, sha256, last_session_id, last_modified_at, created_at)
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(file_path) DO UPDATE SET
        sha256 = excluded.sha256,
        last_session_id = excluded.last_session_id,
        last_modified_at = excluded.last_modified_at,
        modify_count = modify_count + 1
''', (sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[5]))
conn.commit()
conn.close()
" "${DB_PATH}" "${FILE_PATH}" "${SHA}" "${SESSION_ID}" "${TIMESTAMP}" 2>/dev/null
        fi
        ;;

    Read)
        # Check for drift: compare stored hash vs current file hash
        if [[ -f "${FILE_PATH}" ]]; then
            CURRENT_SHA=$(shasum -a 256 "${FILE_PATH}" 2>/dev/null | cut -d' ' -f1)
            STORED_SHA=$(python3 -c "
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
row = conn.execute('SELECT sha256 FROM artifacts WHERE file_path = ?', (sys.argv[2],)).fetchone()
print(row[0] if row else '')
conn.close()
" "${DB_PATH}" "${FILE_PATH}" 2>/dev/null)

            if [[ -n "${STORED_SHA}" && "${STORED_SHA}" != "${CURRENT_SHA}" ]]; then
                # Drift detected!
                echo "${TIMESTAMP} DRIFT_DETECTED file=${FILE_PATH} stored=${STORED_SHA:0:12} current=${CURRENT_SHA:0:12}" \
                    >> "${CRM_ROOT}/logs/${AGENT}/activity.log" 2>/dev/null

                # Alert via channel (channel-agnostic router)
                MSG="DRIFT DETECTED: ${FILE_PATH} was modified outside this session. Hash mismatch."
                SEND_SCRIPT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")" && pwd)}/core/bus/send-channel.sh"
                RECIPIENT="${CHAT_ID:-${DISCORD_CHANNEL_ID:-localhost}}"
                if [[ -f "${SEND_SCRIPT}" && -n "${RECIPIENT}" ]]; then
                    bash "${SEND_SCRIPT}" "${RECIPIENT}" "${MSG}" > /dev/null 2>&1 || true
                fi
            fi
        fi
        ;;
esac

exit 0
