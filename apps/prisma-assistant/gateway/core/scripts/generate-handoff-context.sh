#!/usr/bin/env bash
# generate-handoff-context.sh — Programmatic context extraction for session handoff
#
# Collects structured data (cron status, inbox count, recent files, task count)
# and outputs as YAML. This data is DETERMINISTIC (no LLM needed).
# Used alongside pre-restart-handoff.sh which asks the LLM for intent summary.
#
# Usage:
#   generate-handoff-context.sh <agent>
#   Output: YAML to stdout (redirect to file)
#
# Epic 114 / Story 114.7

set -uo pipefail

AGENT="${1:-${CRM_AGENT_NAME:-prisma}}"
TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID}}"
STATE_DIR="${CRM_ROOT}/state/${AGENT}"
LOG_DIR="${CRM_ROOT}/logs/${AGENT}"

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# --- Cron status ---
CONFIG_FILE="${TEMPLATE_ROOT}/agents/${AGENT}/config.json"
CRON_YAML=""
if [[ -f "${CONFIG_FILE}" ]]; then
    CRON_COUNT=$(jq '.crons | length' "${CONFIG_FILE}" 2>/dev/null || echo "0")
    if [[ ${CRON_COUNT} -gt 0 ]]; then
        CRON_YAML=$(jq -r '.crons[] | "    " + .name + ": {interval: \"" + .interval + "\", isolated: " + (.isolated // false | tostring) + "}"' "${CONFIG_FILE}" 2>/dev/null || echo "    none: {}")
    fi
fi
[[ -z "${CRON_YAML}" ]] && CRON_YAML="    none: {}"

# --- Inbox pending ---
CHANNEL_PENDING=0
AGENT_PENDING=0
[[ -d "${CRM_ROOT}/channel-inbox/${AGENT}" ]] && CHANNEL_PENDING=$(find "${CRM_ROOT}/channel-inbox/${AGENT}" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
[[ -d "${CRM_ROOT}/inbox/${AGENT}" ]] && AGENT_PENDING=$(find "${CRM_ROOT}/inbox/${AGENT}" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')

# --- Recent files (git) ---
RECENT_FILES=""
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    RECENT_FILES=$(git diff --name-only HEAD~5 2>/dev/null | head -20 | sed 's/^/    - /')
fi
[[ -z "${RECENT_FILES}" ]] && RECENT_FILES="    - (no recent git changes)"

# --- Active tasks (from activity log) ---
ACTIVE_TASKS=0
if [[ -f "${LOG_DIR}/activity.log" ]]; then
    ACTIVE_TASKS=$(tail -100 "${LOG_DIR}/activity.log" | grep -c "TaskCreate\|task.*in_progress" 2>/dev/null || echo "0")
fi

# --- Session duration ---
SESSION_START=""
if [[ -f "${LOG_DIR}/activity.log" ]]; then
    SESSION_START=$(head -1 "${LOG_DIR}/activity.log" 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}' || echo "unknown")
fi

# --- Delivery queue ---
QUEUE_PENDING=0
QUEUE_FAILED=0
[[ -d "${CRM_ROOT}/queue/${AGENT}/pending" ]] && QUEUE_PENDING=$(find "${CRM_ROOT}/queue/${AGENT}/pending" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
[[ -d "${CRM_ROOT}/queue/${AGENT}/failed" ]] && QUEUE_FAILED=$(find "${CRM_ROOT}/queue/${AGENT}/failed" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')

# --- Output YAML ---
cat << EOF
# Handoff Context (programmatically generated)
# Generated: ${NOW}
# Agent: ${AGENT}

generated_at: "${NOW}"
agent: "${AGENT}"
session_start: "${SESSION_START}"

cron_status:
${CRON_YAML}

inbox_pending:
    channel: ${CHANNEL_PENDING}
    agent: ${AGENT_PENDING}

delivery_queue:
    pending: ${QUEUE_PENDING}
    failed: ${QUEUE_FAILED}

recent_files:
${RECENT_FILES}

active_tasks_estimate: ${ACTIVE_TASKS}
EOF
