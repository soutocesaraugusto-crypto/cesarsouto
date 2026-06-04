#!/usr/bin/env bash
# config-watcher.sh — Detect config changes and hot-reload safe fields
#
# Called from agent-wrapper.sh watchdog loop every 30s.
# Compares md5 of config.json with last known hash.
# Hot-reloads: crons, smart_routing, channel enable/disable.
# Warns: runtime, model, working_directory (require restart).
#
#
# Usage: config-watcher.sh <agent> <tmux_session> <agent_dir> <template_root>
#
# Epic 114 / Story 114.16 Phase 3

set -uo pipefail

AGENT="${1:-}"
TMUX_SESSION="${2:-}"
AGENT_DIR="${3:-}"
TEMPLATE_ROOT="${4:-}"
CRM_INSTANCE_ID="${CRM_INSTANCE_ID:-default}"
CRM_ROOT="${HOME}/.claude-remote/${CRM_INSTANCE_ID}"
LOG_FILE="${CRM_ROOT}/logs/${AGENT}/activity.log"
CONFIG_FILE="${AGENT_DIR}/config.json"
HASH_FILE="${CRM_ROOT}/state/${AGENT}/.config-hash"

[[ -z "${AGENT}" || ! -f "${CONFIG_FILE}" ]] && exit 0

_log() {
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [config-watcher/${AGENT}] $1" >> "${LOG_FILE}" 2>/dev/null
}

# Compute config hash (md5, ignoring whitespace changes)
_config_hash() {
    jq -cS '.' "${CONFIG_FILE}" 2>/dev/null | md5 -q 2>/dev/null || md5sum "${CONFIG_FILE}" 2>/dev/null | cut -d' ' -f1 || echo "unknown"
}

CURRENT_HASH=$(_config_hash)

# First run: save hash and exit
if [[ ! -f "${HASH_FILE}" ]]; then
    echo "${CURRENT_HASH}" > "${HASH_FILE}"
    exit 0
fi

LAST_HASH=$(cat "${HASH_FILE}" 2>/dev/null || echo "")

# No change
[[ "${CURRENT_HASH}" == "${LAST_HASH}" ]] && exit 0

# Config changed!
_log "Config change detected (${LAST_HASH:0:8}→${CURRENT_HASH:0:8})"
echo "${CURRENT_HASH}" > "${HASH_FILE}"

# Detect what changed by comparing fields
OLD_CONFIG="${CRM_ROOT}/state/${AGENT}/.config-prev.json"
if [[ -f "${OLD_CONFIG}" ]]; then
    # Check restart-required fields
    for field in runtime model working_directory max_session_seconds; do
        OLD_VAL=$(jq -r ".${field} // empty" "${OLD_CONFIG}" 2>/dev/null)
        NEW_VAL=$(jq -r ".${field} // empty" "${CONFIG_FILE}" 2>/dev/null)
        if [[ "${OLD_VAL}" != "${NEW_VAL}" && -n "${NEW_VAL}" ]]; then
            _log "WARNING: '${field}' changed (${OLD_VAL}→${NEW_VAL}). Requires restart to take effect."
            # Notify via Telegram if possible
            source "${AGENT_DIR}/.env" 2>/dev/null || true
            if [[ -n "${BOT_TOKEN:-}" && -n "${CHAT_ID:-}" ]]; then
                bash "${TEMPLATE_ROOT}/core/bus/send-telegram.sh" "${CHAT_ID}" \
                    "Config change: \`${field}\` updated to \`${NEW_VAL}\`. Restart needed: \`/restart\`" \
                    --topic alerts 2>/dev/null || true
            fi
        fi
    done

    # Hot-reload: crons
    OLD_CRONS=$(jq -cS '.crons // []' "${OLD_CONFIG}" 2>/dev/null || echo "[]")
    NEW_CRONS=$(jq -cS '.crons // []' "${CONFIG_FILE}" 2>/dev/null || echo "[]")
    if [[ "${OLD_CRONS}" != "${NEW_CRONS}" ]]; then
        _log "Crons changed — injecting re-setup command"
        # Check if agent is idle before injecting
        source "${TEMPLATE_ROOT}/core/runtimes/runtime.sh" 2>/dev/null || true
        if declare -f runtime_detect_idle >/dev/null 2>&1 && runtime_detect_idle "${TMUX_SESSION}" 2>/dev/null; then
            tmux send-keys -t "${TMUX_SESSION}:0.0" \
                "Re-read config.json and re-setup crons (config changed)." Enter
            _log "Injected cron re-setup command"
        else
            _log "Agent busy, deferring cron reload to next cycle"
            # Revert hash so we retry next cycle
            echo "${LAST_HASH}" > "${HASH_FILE}"
            exit 0
        fi
    fi
fi

# Save current config as prev for next comparison
cp "${CONFIG_FILE}" "${OLD_CONFIG}" 2>/dev/null || true
