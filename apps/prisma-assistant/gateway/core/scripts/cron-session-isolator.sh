#!/usr/bin/env bash
# cron-session-isolator.sh — Cron job session isolation wrapper
# OpenClaw pattern: each cron gets its own session key
#
# Wraps a cron prompt with session isolation markers so the agent
# knows to use a separate context (not pollute user conversation).
#
# Usage: cron-session-isolator.sh <cron_name> "<prompt>"
# Output: Formatted cron prompt with isolation markers
#
# Epic 110 / Story 110.29 Phase 10

set -uo pipefail

CRON_NAME="${1:-unnamed-cron}"
PROMPT="${2:-}"

if [[ -z "${PROMPT}" ]]; then
    echo "Usage: cron-session-isolator.sh <cron_name> \"<prompt>\"" >&2
    exit 1
fi

CRON_ID="cron-${CRON_NAME}-$(date +%s)"

# Output isolated cron prompt
# The markers tell the agent this is a background task, not interactive conversation
cat << EOF
=== SCHEDULED TASK [${CRON_ID}] ===
Task: ${CRON_NAME}
Type: cron (non-interactive, isolated context)

${PROMPT}

IMPORTANT: This is a scheduled task. Do NOT reference or continue any previous conversation.
Complete this task independently and send results via the delivery method specified.
=== END SCHEDULED TASK ===
EOF
