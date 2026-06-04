#!/usr/bin/env bash
# fallback.sh — Model fallback chain + circuit breaker for the gateway
#
# Provides runtime_print_with_fallback() which tries:
#   primary model → fallback models → fallback runtime
#
# Features:
#   - Fatal error detection (billing/quota/auth)
#   - Circuit breaker state machine (closed→open→half-open)
#   - Per-model cooldown with escalation (30s→60s→5min)
#   - MAX 1 fallback runtime (avoid cascade latency)
#   - Skip-tier via failure history
#
# Usage:
#   source "core/runtimes/fallback.sh"
#   RESULT=$(runtime_print_with_fallback "What is 2+2?")
#
# Config (from config.json):
#   "fallback_models": ["claude-sonnet-4-6", "claude-haiku-4-5"]
#   "fallback_runtime": "api-openrouter"
#   "fallback_api_model": "anthropic/claude-3.5-haiku"
#
# Epic 114 / Story 114.16 Phase 1

_FB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_FB_AGENT="${CRM_AGENT_NAME:-prisma}"
_FB_INSTANCE="${CRM_INSTANCE_ID:-default}"
_FB_STATE_DIR="${HOME}/.claude-remote/${_FB_INSTANCE}/state/${_FB_AGENT}"
_FB_CB_FILE="${_FB_STATE_DIR}/.circuit-breaker.json"
_FB_HISTORY_FILE="${_FB_STATE_DIR}/.model-history.json"

mkdir -p "${_FB_STATE_DIR}" 2>/dev/null || true

# --- Fatal Error Detection ---
# Patterns from runner-lib/runtime.sh is_fatal_error() + gateway-specific
_is_fatal_error() {
    local err="$1"
    [[ "$err" == *"usage limit"* ]] && return 0
    [[ "$err" == *"billing"* ]] && return 0
    [[ "$err" == *"quota exceeded"* ]] && return 0
    [[ "$err" == *"purchase more credits"* ]] && return 0
    [[ "$err" == *"account suspended"* ]] && return 0
    [[ "$err" == *"Unauthorized"* ]] && return 0
    [[ "$err" == *"Forbidden"* ]] && return 0
    [[ "$err" == *"invalid_api_key"* ]] && return 0
    return 1
}

# --- Circuit Breaker ---
# State machine: closed → open → half-open → closed
# closed: normal operation
# open: skip all calls for COOLDOWN seconds
# half-open: try 1 call — success→closed, fail→open
_CB_COOLDOWN=300  # 5 minutes
_CB_THRESHOLD=3   # 3 consecutive failures → open

_cb_read() {
    if [[ -f "${_FB_CB_FILE}" ]]; then
        cat "${_FB_CB_FILE}"
    else
        echo '{"state":"closed","failures":0,"cooldown_until":0}'
    fi
}

_cb_write() {
    echo "$1" > "${_FB_CB_FILE}" 2>/dev/null || true
}

_cb_check() {
    local cb
    cb=$(_cb_read)
    local state failures cooldown_until now
    state=$(echo "$cb" | jq -r '.state' 2>/dev/null || echo "closed")
    failures=$(echo "$cb" | jq -r '.failures' 2>/dev/null || echo "0")
    cooldown_until=$(echo "$cb" | jq -r '.cooldown_until' 2>/dev/null || echo "0")
    now=$(date +%s)

    case "$state" in
        closed)
            echo "allow"
            ;;
        open)
            if [[ ${now} -ge ${cooldown_until} ]]; then
                # Cooldown expired → half-open (try one call)
                _cb_write "{\"state\":\"half-open\",\"failures\":${failures},\"cooldown_until\":0}"
                echo "allow"
            else
                echo "deny"
            fi
            ;;
        half-open)
            echo "allow"  # One attempt allowed
            ;;
    esac
}

_cb_success() {
    _cb_write '{"state":"closed","failures":0,"cooldown_until":0}'
}

_cb_failure() {
    local cb
    cb=$(_cb_read)
    local state failures now
    state=$(echo "$cb" | jq -r '.state' 2>/dev/null || echo "closed")
    failures=$(echo "$cb" | jq -r '.failures' 2>/dev/null || echo "0")
    failures=$((failures + 1))
    now=$(date +%s)

    if [[ "$state" == "half-open" || ${failures} -ge ${_CB_THRESHOLD} ]]; then
        local cooldown_until=$((now + _CB_COOLDOWN))
        _cb_write "{\"state\":\"open\",\"failures\":${failures},\"cooldown_until\":${cooldown_until}}"
    else
        _cb_write "{\"state\":\"closed\",\"failures\":${failures},\"cooldown_until\":0}"
    fi
}

# --- Model History + Per-Model Cooldown (skip-tier + cooldown escalation) ---
# Pattern: OpenClaw cooldown escalation (30s → 60s → 5min)
_FB_COOLDOWN_FILE="${_FB_STATE_DIR}/.model-cooldown.json"

_record_attempt() {
    local model="$1" success="$2"
    local now
    now=$(date +%s)
    local entry
    entry=$(jq -n -c --arg m "$model" --argjson s "$success" --argjson ts "$now" \
        '{model:$m, success:$s, ts:$ts}')
    # Append to history, keep last 50 entries
    if [[ -f "${_FB_HISTORY_FILE}" ]]; then
        jq -c --argjson e "${entry}" '. += [$e] | .[-50:]' "${_FB_HISTORY_FILE}" > "${_FB_HISTORY_FILE}.tmp" 2>/dev/null \
            && mv "${_FB_HISTORY_FILE}.tmp" "${_FB_HISTORY_FILE}" \
            || echo "[${entry}]" > "${_FB_HISTORY_FILE}"
    else
        echo "[${entry}]" > "${_FB_HISTORY_FILE}"
    fi

    # Update per-model cooldown on failure
    if [[ "$success" -eq 0 ]]; then
        _set_model_cooldown "$model"
    else
        _clear_model_cooldown "$model"
    fi
}

_set_model_cooldown() {
    local model="$1"
    local now
    now=$(date +%s)
    local cooldown_data="{}"
    [[ -f "${_FB_COOLDOWN_FILE}" ]] && cooldown_data=$(cat "${_FB_COOLDOWN_FILE}" 2>/dev/null || echo "{}")

    local error_count
    error_count=$(echo "$cooldown_data" | jq -r --arg m "$model" '.[$m].error_count // 0' 2>/dev/null || echo "0")
    error_count=$((error_count + 1))

    # Cooldown escalation: ≤1 → 30s, ≤2 → 60s, >2 → 300s (5min)
    local cooldown_secs=30
    [[ ${error_count} -ge 2 ]] && cooldown_secs=60
    [[ ${error_count} -ge 3 ]] && cooldown_secs=300

    local cooldown_until=$((now + cooldown_secs))
    echo "$cooldown_data" | jq -c --arg m "$model" --argjson ec "$error_count" --argjson cu "$cooldown_until" \
        '.[$m] = {error_count: $ec, cooldown_until: $cu}' > "${_FB_COOLDOWN_FILE}.tmp" 2>/dev/null \
        && mv "${_FB_COOLDOWN_FILE}.tmp" "${_FB_COOLDOWN_FILE}" || true
}

_clear_model_cooldown() {
    local model="$1"
    [[ ! -f "${_FB_COOLDOWN_FILE}" ]] && return
    jq -c --arg m "$model" 'del(.[$m])' "${_FB_COOLDOWN_FILE}" > "${_FB_COOLDOWN_FILE}.tmp" 2>/dev/null \
        && mv "${_FB_COOLDOWN_FILE}.tmp" "${_FB_COOLDOWN_FILE}" || true
}

_is_model_in_cooldown() {
    local model="$1"
    [[ ! -f "${_FB_COOLDOWN_FILE}" ]] && return 1
    local now
    now=$(date +%s)
    local cooldown_until
    cooldown_until=$(jq -r --arg m "$model" '.[$m].cooldown_until // 0' "${_FB_COOLDOWN_FILE}" 2>/dev/null || echo "0")
    [[ ${now} -lt ${cooldown_until} ]] && return 0
    return 1
}

_should_skip_model() {
    local model="$1"
    # Skip if in per-model cooldown
    _is_model_in_cooldown "$model" && return 0
    # Skip if last 5 attempts all failed
    [[ ! -f "${_FB_HISTORY_FILE}" ]] && return 1
    local success_rate
    success_rate=$(jq -r --arg m "$model" \
        '[.[] | select(.model == $m)] | .[-5:] | if length >= 5 then (map(select(.success == 1)) | length) else 5 end' \
        "${_FB_HISTORY_FILE}" 2>/dev/null || echo "5")
    [[ "${success_rate}" == "0" ]] && return 0
    return 1
}

# --- Main: runtime_print_with_fallback ---
# Tries: primary model → fallback models → fallback runtime
# Args: <prompt> [--model <override>]
# Returns: response text to stdout
runtime_print_with_fallback() {
    local prompt="$1"; shift
    local model_override=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --model) model_override="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    # Check circuit breaker
    if [[ "$(_cb_check)" == "deny" ]]; then
        echo "Service temporarily unavailable (circuit breaker open). Please try again in a few minutes."
        return 1
    fi

    local primary_model="${model_override:-${RUNTIME_MODEL:-}}"
    local config_file="${_FB_DIR}/../../agents/${_FB_AGENT}/config.json"

    # Load fallback config
    local fallback_models fallback_runtime fallback_api_model
    if [[ -f "${config_file}" ]]; then
        fallback_models=$(jq -r '.fallback_models // [] | .[]' "${config_file}" 2>/dev/null || echo "")
        fallback_runtime=$(jq -r '.fallback_runtime // empty' "${config_file}" 2>/dev/null || echo "")
        fallback_api_model=$(jq -r '.fallback_api_model // empty' "${config_file}" 2>/dev/null || echo "")
    fi

    # Build model chain: primary → fallback_models → fallback_runtime
    local models=()
    [[ -n "${primary_model}" ]] && models+=("${primary_model}")
    for m in ${fallback_models}; do
        models+=("$m")
    done

    # Try each model with the current runtime
    for model in "${models[@]}"; do
        # Skip-tier check
        if _should_skip_model "$model"; then
            continue
        fi

        local result exit_code=0
        result=$(RUNTIME_MODEL="${model}" runtime_print "${prompt}" 2>/dev/null) || exit_code=$?

        if [[ ${exit_code} -eq 0 && -n "${result}" ]]; then
            _cb_success
            _record_attempt "$model" 1
            echo "${result}"
            return 0
        fi

        # Check if fatal
        if _is_fatal_error "${result}"; then
            _record_attempt "$model" 0
            continue  # Skip to next model (don't retry)
        fi

        _record_attempt "$model" 0
    done

    # All models in current runtime failed — try fallback runtime (MAX 1)
    if [[ -n "${fallback_runtime}" && -n "${fallback_api_model}" ]]; then
        local fb_driver="${_FB_DIR}/${fallback_runtime}.sh"
        if [[ -f "${fb_driver}" ]]; then
            # Temporarily switch runtime
            # Pass prompt via env var to avoid shell injection (QA fix BUG-1)
            local result exit_code=0
            result=$(RUNTIME_TYPE="${fallback_runtime}" RUNTIME_MODEL="${fallback_api_model}" \
                _FB_PROMPT="${prompt}" \
                bash -c 'source "'"${_FB_DIR}"'/runtime.sh" && runtime_print "${_FB_PROMPT}"' 2>/dev/null) || exit_code=$?

            if [[ ${exit_code} -eq 0 && -n "${result}" ]]; then
                _cb_success
                _record_attempt "${fallback_runtime}:${fallback_api_model}" 1
                echo "${result}"
                return 0
            fi
            _record_attempt "${fallback_runtime}:${fallback_api_model}" 0
        fi
    fi

    # All failed
    _cb_failure
    echo "All models and runtimes exhausted. Please check API status and credentials."
    return 1
}
