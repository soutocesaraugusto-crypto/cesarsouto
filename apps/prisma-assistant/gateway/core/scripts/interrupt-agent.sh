#!/usr/bin/env bash
# interrupt-agent.sh — Send interrupt signal to a running Claude Code agent
# Hermes pattern: _active_sessions + asyncio.Event for message interruption
#
# When user sends a new message while agent is processing, this script:
# 1. Sends Escape key to cancel current tool execution
# 2. Waits for idle state
# 3. Returns so fast-checker can inject the new message
#
# Usage:
#   interrupt-agent.sh <tmux_session>
#   Returns 0 if agent is now idle, 1 if still busy after timeout
#
# Epic 110 / Story 110.29 Phase 7

set -uo pipefail

TMUX_SESSION="${1:-}"

if [[ -z "${TMUX_SESSION}" ]]; then
    echo "Usage: interrupt-agent.sh <tmux_session>" >&2
    exit 1
fi

if ! tmux has-session -t "${TMUX_SESSION}" 2>/dev/null; then
    exit 1
fi

# Send Escape key to attempt cancellation of current operation
# Claude Code responds to Escape by cancelling the current tool use
tmux send-keys -t "${TMUX_SESSION}:0.0" Escape
sleep 0.5

# Wait up to 10 seconds for agent to become idle
ELAPSED=0
MAX_WAIT=10
while [[ ${ELAPSED} -lt ${MAX_WAIT} ]]; do
    PANE=$(tmux capture-pane -t "${TMUX_SESSION}:0.0" -p 2>/dev/null | tail -3)
    # Check for idle indicators (prompt visible, no spinner)
    if echo "$PANE" | grep -qE '^\s*>|permissions'; then
        exit 0  # Agent is idle, ready for new input
    fi
    # Check for spinner = still busy
    if echo "$PANE" | grep -qE '[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]'; then
        # Send another Escape if still processing
        tmux send-keys -t "${TMUX_SESSION}:0.0" Escape
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

# Timeout — agent didn't respond to interrupt
exit 1
