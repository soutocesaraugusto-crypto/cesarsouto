#!/usr/bin/env bash
# _credential-pool.sh — Credential pool with rotation for API keys and bot tokens
# Hermes reference: agent/credential_pool.py — PooledCredential with least_used strategy.
#
# Supports multiple keys per type with automatic rotation on failure.
# Backward compat: single KEY (no _1/_2 suffix) works as pool of 1.
#
# Usage: source this file, then call:
#   pool_get_active BOT_TOKEN        → returns current active token
#   pool_rotate BOT_TOKEN            → switch to next healthy token
#   pool_mark_unhealthy BOT_TOKEN 1  → blacklist index for 5min
#   pool_status BOT_TOKEN            → JSON status
#
# Env format:
#   BOT_TOKEN_1=xxx BOT_TOKEN_2=yyy  (pool mode)
#   BOT_TOKEN=xxx                     (single mode, backward compat)
#
# Epic 114 / Story 114.11

_POOL_AGENT="${CRM_AGENT_NAME:-$(basename "$(pwd)")}"
_POOL_ROOT="${CRM_ROOT:-${HOME}/.claude-remote/${CRM_INSTANCE_ID:-default}}"
_POOL_STATE="${_POOL_ROOT}/state/${_POOL_AGENT}/credential-pool.json"

mkdir -p "$(dirname "${_POOL_STATE}")" 2>/dev/null || true

# Initialize state file if missing
[[ ! -f "${_POOL_STATE}" ]] && echo '{}' > "${_POOL_STATE}" 2>/dev/null

# Discover all credentials for a type (BOT_TOKEN → BOT_TOKEN_1, BOT_TOKEN_2, ...)
_pool_discover() {
    local type="$1"
    local keys=()

    # Check numbered variants first
    for i in 1 2 3 4 5; do
        local var="${type}_${i}"
        local val="${!var:-}"
        [[ -n "$val" ]] && keys+=("$val")
    done

    # Fallback: single key (no suffix)
    if [[ ${#keys[@]} -eq 0 ]]; then
        local val="${!type:-}"
        [[ -n "$val" ]] && keys+=("$val")
    fi

    printf '%s\n' "${keys[@]}"
}

# Get the active (current) credential for a type
pool_get_active() {
    local type="$1"
    local keys
    local keys=()
    while IFS= read -r _k; do [[ -n "$_k" ]] && keys+=("$_k"); done < <(_pool_discover "$type")

    [[ ${#keys[@]} -eq 0 ]] && return 1

    # Read active index from state
    local active_idx
    active_idx=$(jq -r ".\"${type}\".active_index // 0" "${_POOL_STATE}" 2>/dev/null || echo "0")

    # Check if current index is healthy
    local unhealthy_until
    unhealthy_until=$(jq -r ".\"${type}\".unhealthy[\"${active_idx}\"] // 0" "${_POOL_STATE}" 2>/dev/null || echo "0")
    local now
    now=$(date +%s)

    if [[ ${unhealthy_until} -gt ${now} ]]; then
        # Current is unhealthy — find next healthy
        for ((i=0; i<${#keys[@]}; i++)); do
            local idx=$(( (active_idx + i + 1) % ${#keys[@]} ))
            unhealthy_until=$(jq -r ".\"${type}\".unhealthy[\"${idx}\"] // 0" "${_POOL_STATE}" 2>/dev/null || echo "0")
            if [[ ${unhealthy_until} -le ${now} ]]; then
                active_idx=$idx
                # Update state
                jq --arg t "$type" --argjson idx "$active_idx" '.[$t].active_index = $idx' "${_POOL_STATE}" > "${_POOL_STATE}.tmp" 2>/dev/null && mv "${_POOL_STATE}.tmp" "${_POOL_STATE}"
                break
            fi
        done
    fi

    # Bounds check
    [[ ${active_idx} -ge ${#keys[@]} ]] && active_idx=0

    # Warn if all credentials are unhealthy (QA fix 114.11)
    unhealthy_until=$(jq -r ".\"${type}\".unhealthy[\"${active_idx}\"] // 0" "${_POOL_STATE}" 2>/dev/null || echo "0")
    if [[ ${unhealthy_until} -gt $(date +%s) ]]; then
        if type crm_log &>/dev/null; then
            crm_log "credential_exhausted" "All ${type} credentials unhealthy — using least-bad" "type=${type}"
        fi
    fi

    echo "${keys[$active_idx]}"
}

# Rotate to next credential (called on 429/401)
pool_rotate() {
    local type="$1"
    local keys
    local keys=()
    while IFS= read -r _k; do [[ -n "$_k" ]] && keys+=("$_k"); done < <(_pool_discover "$type")

    [[ ${#keys[@]} -le 1 ]] && return 0  # Nothing to rotate with single key

    local active_idx
    active_idx=$(jq -r ".\"${type}\".active_index // 0" "${_POOL_STATE}" 2>/dev/null || echo "0")
    local next_idx=$(( (active_idx + 1) % ${#keys[@]} ))

    jq --arg t "$type" --argjson idx "$next_idx" '.[$t].active_index = $idx' "${_POOL_STATE}" > "${_POOL_STATE}.tmp" 2>/dev/null && mv "${_POOL_STATE}.tmp" "${_POOL_STATE}"

    # Log rotation
    if type crm_log &>/dev/null; then
        crm_log "credential_rotate" "Rotated ${type} from index ${active_idx} to ${next_idx}" "type=${type}" "from=${active_idx}" "to=${next_idx}"
    fi
}

# Mark a credential as unhealthy (cooldown period)
pool_mark_unhealthy() {
    local type="$1"
    local index="${2:-0}"
    local cooldown="${3:-300}"  # Default 5 min
    local until=$(( $(date +%s) + cooldown ))

    jq --arg t "$type" --arg idx "$index" --argjson until "$until" \
        '.[$t].unhealthy[$idx] = $until' "${_POOL_STATE}" > "${_POOL_STATE}.tmp" 2>/dev/null && mv "${_POOL_STATE}.tmp" "${_POOL_STATE}"
}

# Get pool status as JSON
pool_status() {
    local type="$1"
    local keys
    local keys=()
    while IFS= read -r _k; do [[ -n "$_k" ]] && keys+=("$_k"); done < <(_pool_discover "$type")
    local count=${#keys[@]}
    local active_idx
    active_idx=$(jq -r ".\"${type}\".active_index // 0" "${_POOL_STATE}" 2>/dev/null || echo "0")

    echo "{\"type\":\"${type}\",\"count\":${count},\"active_index\":${active_idx}}"
}
