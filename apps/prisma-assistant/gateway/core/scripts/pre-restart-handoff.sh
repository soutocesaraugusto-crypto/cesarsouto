#!/usr/bin/env bash
# pre-restart-handoff.sh - Generate a handoff summary before session restart
# Called by agent-wrapper.sh before the 71h timer restart or soft restart.
# Injects a prompt into the tmux session asking the agent to save its current context.
#
# The generated handoff file is read on the next --continue boot via CONTINUE_PROMPT.
#
# Usage: pre-restart-handoff.sh <agent> <tmux_session>
# Env: CRM_ROOT, CRM_INSTANCE_ID (set by agent-wrapper.sh)
#
# Epic 110 / Story 110.25 Phase 4

set -uo pipefail

AGENT="${1:-}"
TMUX_SESSION="${2:-}"

if [[ -z "${AGENT}" || -z "${TMUX_SESSION}" ]]; then
    echo "Usage: pre-restart-handoff.sh <agent> <tmux_session>" >&2
    exit 1
fi

CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
STATE_DIR="${CRM_ROOT}/state/${AGENT}"
HANDOFF_FILE="${STATE_DIR}/last-handoff.md"
LOG_DIR="${CRM_ROOT}/logs/${AGENT}"

mkdir -p "${STATE_DIR}" "${LOG_DIR}"

log() {
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [pre-restart-handoff/${AGENT}] $1" >> "${LOG_DIR}/activity.log" 2>/dev/null
}

# Check tmux session exists
if ! tmux has-session -t "${TMUX_SESSION}" 2>/dev/null; then
    log "tmux session gone, skipping handoff"
    exit 0
fi

# Archive previous handoff before requesting new one (keep last 10)
if [[ -f "${HANDOFF_FILE}" ]]; then
    ARCHIVE_DIR="${STATE_DIR}/handoff-archive"
    mkdir -p "${ARCHIVE_DIR}"
    ARCHIVE_TS=$(date -u +"%Y%m%dT%H%M%S")
    cp "${HANDOFF_FILE}" "${ARCHIVE_DIR}/handoff-${ARCHIVE_TS}.md" 2>/dev/null || true
    # Rotate: keep only last 10 archives
    ls -t "${ARCHIVE_DIR}"/handoff-*.md 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    log "Archived previous handoff (keeping last 10)"
fi

log "Requesting handoff summary from agent..."

# Inject handoff prompt into the agent's session
HANDOFF_PROMPT="SESSION RESTART IMMINENT: Your session will restart in 60 seconds with --continue. Generate a concise handoff summary and save it using Write tool to '${HANDOFF_FILE}'. Include: (1) Active tasks and their status, (2) Key decisions made this session, (3) Pending items that need attention next session, (4) Any context the next session needs to continue seamlessly. Keep it under 2000 chars. DO THIS NOW — this is your last action before restart."

tmpfile=$(mktemp "${LOG_DIR}/.crm-handoff-XXXXXX.txt" 2>/dev/null) || {
    log "mktemp failed, skipping handoff"
    exit 0
}
chmod 600 "$tmpfile"
printf '%s' "$HANDOFF_PROMPT" > "$tmpfile"

tmux load-buffer -b "crm-handoff" "$tmpfile"
tmux paste-buffer -t "${TMUX_SESSION}:0.0" -b "crm-handoff"
sleep 0.3
tmux send-keys -t "${TMUX_SESSION}:0.0" Enter
rm -f "$tmpfile"

# Wait up to 60 seconds for the handoff file to be created
ELAPSED=0
TIMEOUT=60
while [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
    if [[ -f "${HANDOFF_FILE}" ]]; then
        HANDOFF_SIZE=$(wc -c < "${HANDOFF_FILE}" | tr -d ' ')
        if [[ ${HANDOFF_SIZE} -gt 10 ]]; then
            log "Handoff saved (${HANDOFF_SIZE} bytes) at ${HANDOFF_FILE}"
            exit 0
        fi
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

log "Handoff timeout after ${TIMEOUT}s — continuing restart without handoff"
exit 0
