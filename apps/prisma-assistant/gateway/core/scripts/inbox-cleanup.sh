#!/usr/bin/env bash
# inbox-cleanup.sh - TTL cleanup for processed inbox messages
# Deletes messages older than MAX_AGE_DAYS from processed/ directory.
# Intended to run as a weekly cron or manual maintenance task.
#
# Usage: inbox-cleanup.sh [agent_name]
# Env: CRM_ROOT, CRM_INSTANCE_ID
#
# Epic 110 / Story 110.26 Phase 3

set -uo pipefail

AGENT="${1:-${CRM_AGENT_NAME:-prisma}}"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
MAX_AGE_DAYS="${MAX_AGE_DAYS:-30}"

PROCESSED_DIR="${CRM_ROOT}/processed/${AGENT}"
LOG_DIR="${CRM_ROOT}/logs/${AGENT}"

mkdir -p "${LOG_DIR}" 2>/dev/null || true

log() {
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [inbox-cleanup/${AGENT}] $1" >> "${LOG_DIR}/activity.log" 2>/dev/null
}

if [[ ! -d "${PROCESSED_DIR}" ]]; then
    log "No processed directory found, nothing to clean"
    exit 0
fi

# Count files before cleanup
BEFORE=$(find "${PROCESSED_DIR}" -type f -name "*.json" 2>/dev/null | wc -l | tr -d ' ')

# Delete files older than MAX_AGE_DAYS
DELETED=0
while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    rm -f "$file" 2>/dev/null && DELETED=$((DELETED + 1))
done < <(find "${PROCESSED_DIR}" -type f -name "*.json" -mtime "+${MAX_AGE_DAYS}" 2>/dev/null)

AFTER=$((BEFORE - DELETED))
log "Cleanup complete: deleted ${DELETED} messages older than ${MAX_AGE_DAYS}d (${BEFORE} → ${AFTER})"

echo "Cleaned ${DELETED} processed messages older than ${MAX_AGE_DAYS} days"
