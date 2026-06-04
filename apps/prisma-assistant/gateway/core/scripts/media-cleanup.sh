#!/usr/bin/env bash
# media-cleanup.sh — Clean up cached media files older than MAX_AGE_HOURS
# Hermes pattern: cleanup_image_cache(max_age_hours=24)
#
# Usage: media-cleanup.sh <agent> [max_age_hours]
# Default: 24 hours
#
# Epic 110 / Story 110.28 Phase 4

set -uo pipefail

AGENT="${1:-${CRM_AGENT_NAME:-prisma}}"
MAX_AGE_HOURS="${2:-24}"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
IMAGE_DIR="${TEMPLATE_ROOT}/agents/${AGENT}/telegram-images"
LOG_DIR="${CRM_ROOT}/logs/${AGENT}"

mkdir -p "${LOG_DIR}" 2>/dev/null || true

if [[ ! -d "${IMAGE_DIR}" ]]; then
    echo "No media directory found: ${IMAGE_DIR}"
    exit 0
fi

# Convert hours to minutes for find -mmin
MAX_AGE_MINUTES=$((MAX_AGE_HOURS * 60))

BEFORE=$(find "${IMAGE_DIR}" -type f 2>/dev/null | wc -l | tr -d ' ')
DELETED=0

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    rm -f "$file" 2>/dev/null && DELETED=$((DELETED + 1))
done < <(find "${IMAGE_DIR}" -type f -mmin "+${MAX_AGE_MINUTES}" 2>/dev/null)

AFTER=$((BEFORE - DELETED))
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [media-cleanup/${AGENT}] Cleaned ${DELETED} files older than ${MAX_AGE_HOURS}h (${BEFORE} → ${AFTER})" >> "${LOG_DIR}/activity.log" 2>/dev/null
echo "Cleaned ${DELETED} media files older than ${MAX_AGE_HOURS} hours"
