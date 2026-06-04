#!/usr/bin/env bash
# stop.sh — Stop the Telegram polling adapter
#
# Usage: stop.sh <agent>
#
# Epic 110 / Story 110.27 Phase 3

set -uo pipefail

AGENT="${1:-}"
ADAPTER_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="${ADAPTER_DIR}/.pid-${AGENT}"

if [[ -z "${AGENT}" ]]; then
    echo "Usage: stop.sh <agent>" >&2
    exit 1
fi

if [[ ! -f "${PID_FILE}" ]]; then
    echo "Telegram adapter not running (no PID file)" >&2
    exit 0
fi

PID=$(cat "${PID_FILE}" 2>/dev/null)

if [[ -z "${PID}" ]]; then
    rm -f "${PID_FILE}"
    echo "Telegram adapter not running (empty PID file)" >&2
    exit 0
fi

# Graceful shutdown via SIGTERM
if kill -0 "${PID}" 2>/dev/null; then
    kill -TERM "${PID}" 2>/dev/null || true
    # Wait up to 5 seconds for graceful shutdown
    ELAPSED=0
    while [[ ${ELAPSED} -lt 5 ]] && kill -0 "${PID}" 2>/dev/null; do
        sleep 1
        ELAPSED=$((ELAPSED + 1))
    done
    # Force kill if still alive
    if kill -0 "${PID}" 2>/dev/null; then
        kill -9 "${PID}" 2>/dev/null || true
    fi
    echo "Telegram adapter stopped (PID ${PID})"
else
    echo "Telegram adapter already stopped (stale PID ${PID})"
fi

rm -f "${PID_FILE}"
