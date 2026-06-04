#!/usr/bin/env bash
# stop.sh — Stop the web chat adapter
#
# Usage: stop.sh <agent>
#
# Story 114.18 Phase 2

set -uo pipefail

AGENT="${1:-}"
ADAPTER_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="${ADAPTER_DIR}/.pid-${AGENT}"

if [[ -z "${AGENT}" ]]; then
    echo "Usage: stop.sh <agent>" >&2
    exit 1
fi

if [[ ! -f "${PID_FILE}" ]]; then
    echo "Web adapter not running (no PID file)" >&2
    exit 0
fi

PID=$(cat "${PID_FILE}" 2>/dev/null)

if [[ -z "${PID}" ]]; then
    rm -f "${PID_FILE}"
    echo "Web adapter not running (empty PID file)" >&2
    exit 0
fi

if kill -0 "${PID}" 2>/dev/null; then
    kill -TERM "${PID}" 2>/dev/null || true
    ELAPSED=0
    while [[ ${ELAPSED} -lt 5 ]] && kill -0 "${PID}" 2>/dev/null; do
        sleep 1
        ELAPSED=$((ELAPSED + 1))
    done
    if kill -0 "${PID}" 2>/dev/null; then
        kill -9 "${PID}" 2>/dev/null || true
    fi
    echo "Web adapter stopped (PID ${PID})"
else
    echo "Web adapter already stopped (stale PID ${PID})"
fi

rm -f "${PID_FILE}"
