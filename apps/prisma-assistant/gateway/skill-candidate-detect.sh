#!/usr/bin/env bash
# skill-candidate-detect.sh — SessionEnd hook: detect skill candidates from session
#
# Heuristics (all must be true):
#   1. Session duration > 10 minutes
#   2. > 3 files modified (Write/Edit tool uses)
#   3. Pattern not covered by existing skill (fuzzy match)
#   4. Not a trivial fix (filter chore/style commits)
#
# If candidate detected: insert into skills.db + notify Telegram
# Does NOT create SKILL.md — only registers candidate for lifecycle promotion
#
# Epic 110 Story 110.7 | Design reference: Hermes skill nudge mechanism

set -uo pipefail

AGENT="${CRM_AGENT_NAME:-prisma}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/default}"
TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
STATE_DIR="${CRM_ROOT}/state/${AGENT}"
DB_PATH="${STATE_DIR}/skills.db"
SESSIONS_DB="${STATE_DIR}/sessions.db"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SINKRA_HUB="${PRISMA_HOME:-${CRM_TEMPLATE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || echo "")}}"

mkdir -p "${STATE_DIR}"

# --- Read hook input ---
HOOK_INPUT=$(cat 2>/dev/null || echo '{}')
SESSION_ID=$(echo "${HOOK_INPUT}" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
DURATION=$(echo "${HOOK_INPUT}" | jq -r '.duration_seconds // 0' 2>/dev/null || echo "0")

# --- Initialize skills database ---
python3 -c "
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
conn.executescript('''
    PRAGMA journal_mode=WAL;
    PRAGMA busy_timeout=5000;

    CREATE TABLE IF NOT EXISTS skills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        description TEXT DEFAULT '',
        status TEXT DEFAULT 'CANDIDATE' CHECK(status IN ('CANDIDATE','ACTIVE','PROVEN','STALE','ARCHIVED')),
        usage_count INTEGER DEFAULT 0,
        distinct_sessions INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        last_used_at TEXT,
        promoted_at TEXT,
        stale_at TEXT,
        archived_at TEXT,
        source_session_id TEXT,
        summary TEXT DEFAULT '',
        files_touched TEXT DEFAULT '[]',
        security_verdict TEXT DEFAULT 'PENDING'
    );

    CREATE TABLE IF NOT EXISTS skill_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        skill_id INTEGER NOT NULL,
        session_id TEXT NOT NULL,
        used_at TEXT NOT NULL,
        FOREIGN KEY (skill_id) REFERENCES skills(id),
        UNIQUE(skill_id, session_id)
    );
''')
conn.close()
" "${DB_PATH}" 2>/dev/null

# --- Heuristic 1: Duration > 10 minutes (600 seconds) ---
if [[ "${DURATION}" -lt 600 ]]; then
    exit 0  # Too short — skip
fi

# --- Get session transcript for analysis ---
TRANSCRIPT=""
if [[ -f "${SESSIONS_DB}" ]]; then
    TRANSCRIPT=$(sqlite3 "${SESSIONS_DB}" "SELECT content FROM messages WHERE session_id='${SESSION_ID}' ORDER BY id DESC LIMIT 1;" 2>/dev/null || echo "")
fi

if [[ -z "${TRANSCRIPT}" || "${#TRANSCRIPT}" -lt 100 ]]; then
    exit 0  # No transcript or too short
fi

# --- Heuristic 2-4: Analyze with Python ---
# Export all vars needed by the Python heredoc
export SESSION_ID DB_PATH TIMESTAMP SINKRA_HUB
export TRANSCRIPT_CONTENT="${TRANSCRIPT}"

python3 << 'PYEOF'
import sqlite3
import os
import re
import json
import sys

session_id = os.environ.get("SESSION_ID", "unknown")
db_path = os.environ.get("DB_PATH", "")
transcript = os.environ.get("TRANSCRIPT_CONTENT", "")[:100000]  # Cap at 100K
timestamp = os.environ.get("TIMESTAMP", "")
sinkra_hub = os.environ.get("SINKRA_HUB", "")
chat_id = os.environ.get("CHAT_ID", "")
bot_token = os.environ.get("BOT_TOKEN", "")

if not transcript or not db_path:
    sys.exit(0)

# Heuristic 2: Count file modifications (Write/Edit tool uses)
write_edit_count = len(re.findall(r'(?:Write|Edit)\(', transcript))
if write_edit_count < 3:
    sys.exit(0)  # Not enough file modifications

# Heuristic 4: Filter trivial fixes
trivial_patterns = [
    r'chore\(', r'style\(', r'typo', r'fix: lint',
    r'fix: format', r'whitespace', r'indentation'
]
trivial_count = sum(1 for p in trivial_patterns if re.search(p, transcript, re.I))
if trivial_count > 2:
    sys.exit(0)  # Likely a trivial fix session

# Extract what was done (simple heuristic: look for file paths)
files_touched = list(set(re.findall(r'(?:Write|Edit)\(["\']?([^"\')\s]+)', transcript)))[:20]

# Generate a candidate name from the most common directory
if files_touched:
    dirs = [os.path.dirname(f).split('/')[-1] for f in files_touched if '/' in f]
    if dirs:
        from collections import Counter
        most_common_dir = Counter(dirs).most_common(1)[0][0] if dirs else "unknown"
    else:
        most_common_dir = "unknown"
    candidate_name = f"auto-{most_common_dir}-{session_id[:8]}"
else:
    candidate_name = f"auto-session-{session_id[:8]}"

# Generate summary (first 200 chars of meaningful content)
summary_match = re.search(r'(?:feat|fix|refactor|implement|create|build|add)\b[^.]{10,200}', transcript, re.I)
summary = summary_match.group(0).strip() if summary_match else f"Session with {write_edit_count} file modifications"

# Heuristic 3: Check if pattern is already covered by existing skill
existing_skills = []
skills_dir = os.path.join(sinkra_hub, ".claude", "skills") if sinkra_hub else ""
if skills_dir and os.path.isdir(skills_dir):
    for root, dirs, skill_files in os.walk(skills_dir):
        for sf in skill_files:
            if sf.endswith('.md'):
                existing_skills.append(sf.replace('.md', '').lower())

# Fuzzy match: if candidate name overlaps significantly with existing skill, skip
candidate_words = set(candidate_name.lower().replace('-', ' ').split())
for existing in existing_skills:
    existing_words = set(existing.replace('-', ' ').split())
    overlap = candidate_words & existing_words
    if len(overlap) >= 2:
        sys.exit(0)  # Already covered

# --- Insert candidate into skills.db ---
conn = sqlite3.connect(db_path)
try:
    conn.execute(
        """INSERT OR IGNORE INTO skills
           (name, description, status, usage_count, distinct_sessions, created_at,
            source_session_id, summary, files_touched, security_verdict)
           VALUES (?, ?, 'CANDIDATE', 1, 1, ?, ?, ?, ?, 'PENDING')""",
        (candidate_name, summary, timestamp, session_id,
         summary, json.dumps(files_touched[:10]))
    )
    conn.commit()

    # Check if actually inserted (not duplicate)
    row = conn.execute("SELECT id FROM skills WHERE name = ?", (candidate_name,)).fetchone()
    if row:
        print(f"CANDIDATE_CREATED: {candidate_name}", file=sys.stderr)
    else:
        sys.exit(0)
finally:
    conn.close()

# --- Notify via channel (channel-agnostic) ---
# Notification is handled by the shell layer using send-telegram.sh (or future send-slack.sh)
msg = f"Skill candidate detected: {candidate_name}\n{summary[:100]}\nFiles: {len(files_touched)} modified\nStatus: CANDIDATE (needs 3 uses to promote)"
print(msg)  # Output to stderr for the shell wrapper to pick up

PYEOF

# Send notification via channel router (channel-agnostic)
RECIPIENT="${CHAT_ID:-${DISCORD_CHANNEL_ID:-localhost}}"
if [[ -n "${RECIPIENT}" ]]; then
    SEND_SCRIPT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")" && pwd)}/core/bus/send-channel.sh"
    if [[ -f "${SEND_SCRIPT}" ]]; then
        NOTIFY_MSG=$(python3 -c "
import sqlite3, os
db = os.environ.get('DB_PATH','')
if db and os.path.exists(db):
    conn = sqlite3.connect(db)
    row = conn.execute('SELECT name, summary FROM skills ORDER BY id DESC LIMIT 1').fetchone()
    if row: print(f'Skill candidate: {row[0]}\n{row[1][:100]}')
    conn.close()
" 2>/dev/null)
        if [[ -n "${NOTIFY_MSG}" ]]; then
            bash "${SEND_SCRIPT}" "${CHAT_ID}" "${NOTIFY_MSG}" > /dev/null 2>&1 || true
        fi
    fi
fi

exit 0
