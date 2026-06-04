#!/usr/bin/env bash
# safety-allowlist.sh — Manage safety scanner allowlist
#
# Provides functions for checking and updating the allowlist.
# Scopes: once (not persisted), session (cleared on restart), always (permanent).
#
# Usage:
#   source safety-allowlist.sh
#   safety_is_allowed "rm -rf"          # Returns 0 if allowed
#   safety_add_allowlist "rm -rf" "session" "user123"
#   safety_clear_session                # Clear session-scoped entries
#
# State: ${CRM_ROOT}/state/${AGENT}/safety-allowlist.json
#
# Epic 114 / Story 114.17 Phase 1

_SA_AGENT="${CRM_AGENT_NAME:-prisma}"
_SA_INSTANCE="${CRM_INSTANCE_ID:-default}"
_SA_FILE="${HOME}/.claude-remote/${_SA_INSTANCE}/state/${_SA_AGENT}/safety-allowlist.json"

mkdir -p "$(dirname "${_SA_FILE}")" 2>/dev/null || true

# Initialize empty allowlist if not exists
[[ ! -f "${_SA_FILE}" ]] && echo '[]' > "${_SA_FILE}"

# Check if a pattern is in the allowlist (respecting scope)
# Args: $1=pattern_key
# Returns: 0 if allowed, 1 if not
safety_is_allowed() {
    local pattern="$1"
    [[ ! -f "${_SA_FILE}" ]] && return 1
    local match
    match=$(jq -r --arg p "$pattern" \
        '[.[] | select(.pattern == $p and (.scope == "always" or .scope == "session"))] | length' \
        "${_SA_FILE}" 2>/dev/null || echo "0")
    [[ "${match}" -gt 0 ]] && return 0
    return 1
}

# Add a pattern to the allowlist
# Args: $1=pattern, $2=scope (once|session|always), $3=approved_by
safety_add_allowlist() {
    local pattern="$1"
    local scope="${2:-once}"
    local approved_by="${3:-unknown}"

    # "once" scope is not persisted — just return
    [[ "${scope}" == "once" ]] && return 0

    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local entry
    entry=$(jq -n -c --arg p "$pattern" --arg s "$scope" --arg ab "$approved_by" --arg ts "$now" \
        '{pattern:$p, scope:$s, approved_at:$ts, approved_by:$ab}')

    # Remove existing entry for this pattern (update)
    jq -c --arg p "$pattern" '[.[] | select(.pattern != $p)]' "${_SA_FILE}" > "${_SA_FILE}.tmp" 2>/dev/null \
        && mv "${_SA_FILE}.tmp" "${_SA_FILE}" || true

    # Append new entry
    jq -c --argjson e "${entry}" '. += [$e]' "${_SA_FILE}" > "${_SA_FILE}.tmp" 2>/dev/null \
        && mv "${_SA_FILE}.tmp" "${_SA_FILE}" || true
}

# Clear all session-scoped entries (called on agent restart)
safety_clear_session() {
    [[ ! -f "${_SA_FILE}" ]] && return 0
    jq -c '[.[] | select(.scope != "session")]' "${_SA_FILE}" > "${_SA_FILE}.tmp" 2>/dev/null \
        && mv "${_SA_FILE}.tmp" "${_SA_FILE}" || true
}

# List current allowlist entries
safety_list() {
    [[ -f "${_SA_FILE}" ]] && jq '.' "${_SA_FILE}" 2>/dev/null || echo "[]"
}
