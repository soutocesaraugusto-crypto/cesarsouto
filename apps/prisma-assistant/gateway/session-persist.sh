#!/usr/bin/env bash
# session-persist.sh — SessionEnd hook: persist session transcript to SQLite FTS5
#
# Called by Claude Code's SessionEnd hook. Receives JSON on stdin:
#   { session_id, transcript_path, cwd, hook_event_name, duration_seconds, ... }
#
# Environment (set by agent-wrapper.sh):
#   CRM_AGENT_NAME, CRM_ROOT, CRM_TEMPLATE_ROOT
#
# Storage: ~/.claude-remote/default/state/<agent>/sessions.db
#
# Epic 110 Story 110.5 | Roundtable: WAL mode mandatory, FTS5 required
# Design reference: Hermes session_search_tool.py (FTS5 queries, truncation logic)

set -uo pipefail

AGENT="${CRM_AGENT_NAME:-prisma}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/default}"
STATE_DIR="${CRM_ROOT}/state/${AGENT}"
DB_PATH="${STATE_DIR}/sessions.db"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
MAX_TRANSCRIPT_CHARS=500000  # 500K chars max per session

mkdir -p "${STATE_DIR}"

# --- Read hook input from stdin ---
HOOK_INPUT=$(cat 2>/dev/null || echo '{}')
SESSION_ID=$(echo "${HOOK_INPUT}" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
TRANSCRIPT_PATH=$(echo "${HOOK_INPUT}" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")
DURATION=$(echo "${HOOK_INPUT}" | jq -r '.duration_seconds // 0' 2>/dev/null || echo "0")
CWD=$(echo "${HOOK_INPUT}" | jq -r '.cwd // ""' 2>/dev/null || echo "")

# --- Initialize database (idempotent) ---
sqlite3 "${DB_PATH}" <<'SQL'
PRAGMA journal_mode=WAL;
PRAGMA busy_timeout=5000;

CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    started_at TEXT NOT NULL,
    ended_at TEXT NOT NULL,
    duration_seconds INTEGER DEFAULT 0,
    cwd TEXT DEFAULT '',
    summary TEXT DEFAULT '',
    message_count INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT NOT NULL,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    timestamp TEXT NOT NULL,
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);

-- Standalone FTS5 table (stores own copy — simpler, no content-sync triggers needed)
CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
    session_id,
    content,
    tokenize='unicode61'
);
SQL

# --- Extract transcript ---
TRANSCRIPT=""

if [[ -n "${TRANSCRIPT_PATH}" && -f "${TRANSCRIPT_PATH}" ]]; then
    # Read transcript file (Claude Code provides this)
    TRANSCRIPT=$(head -c "${MAX_TRANSCRIPT_CHARS}" "${TRANSCRIPT_PATH}" 2>/dev/null || echo "")
elif [[ -n "${CRM_AGENT_NAME:-}" ]]; then
    # Fallback: capture from tmux pane history
    TMUX_SESSION="crm-${CRM_INSTANCE_ID:-default}-${AGENT}"
    if tmux has-session -t "${TMUX_SESSION}" 2>/dev/null; then
        TRANSCRIPT=$(tmux capture-pane -t "${TMUX_SESSION}" -p -S -10000 2>/dev/null | head -c "${MAX_TRANSCRIPT_CHARS}" || echo "")
    fi
fi

if [[ -z "${TRANSCRIPT}" ]]; then
    # No transcript available — still record the session metadata
    TRANSCRIPT="[No transcript captured]"
fi

# --- Parse transcript into messages ---
# Simple heuristic: split on role markers (Human:, Assistant:, System:)
# For now, store as a single message — future versions can parse roles
MSG_COUNT=1

# --- Calculate started_at from duration ---
if command -v gdate &>/dev/null; then
    STARTED_AT=$(gdate -u -d "${DURATION} seconds ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "${TIMESTAMP}")
elif [[ "$(uname)" == "Darwin" ]]; then
    STARTED_AT=$(date -u -v-"${DURATION}"S +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "${TIMESTAMP}")
else
    STARTED_AT=$(date -u -d "${DURATION} seconds ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "${TIMESTAMP}")
fi

# --- Insert session + transcript (atomic, parameterized via Python) ---
python3 -c "
import sqlite3, sys, os

db = sys.argv[1]
sid = sys.argv[2]
started = sys.argv[3]
ended = sys.argv[4]
duration = int(sys.argv[5]) if sys.argv[5].isdigit() else 0
cwd = sys.argv[6]
msg_count = int(sys.argv[7]) if sys.argv[7].isdigit() else 1

# Read transcript from stdin (avoids arg length limits)
transcript = sys.stdin.read()

conn = sqlite3.connect(db)
conn.execute('PRAGMA journal_mode=WAL')
conn.execute('PRAGMA busy_timeout=5000')

conn.execute(
    'INSERT OR REPLACE INTO sessions (id, started_at, ended_at, duration_seconds, cwd, message_count) VALUES (?,?,?,?,?,?)',
    (sid, started, ended, duration, cwd, msg_count)
)
conn.execute(
    'INSERT INTO messages (session_id, role, content, timestamp) VALUES (?,?,?,?)',
    (sid, 'transcript', transcript, ended)
)
conn.execute(
    'INSERT INTO messages_fts (session_id, content) VALUES (?,?)',
    (sid, transcript)
)
conn.commit()
conn.close()
" "${DB_PATH}" "${SESSION_ID}" "${STARTED_AT}" "${TIMESTAMP}" "${DURATION:-0}" "${CWD}" "${MSG_COUNT}" <<< "${TRANSCRIPT}"

# --- Log ---
echo "${TIMESTAMP} SESSION_PERSISTED agent=${AGENT} session=${SESSION_ID} duration=${DURATION}s chars=${#TRANSCRIPT}" \
    >> "${CRM_ROOT}/logs/${AGENT}/activity.log" 2>/dev/null || true

exit 0
