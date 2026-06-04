#!/usr/bin/env bash
# metrics-collector.sh — Structured metrics recording (JSONL)
#
# Records per-interaction, per-delivery, per-fallback metrics.
# Source this file, then call metrics_* functions.
#
#
# Usage:
#   source metrics-collector.sh
#   metrics_start_timer
#   metrics_record interaction channel=telegram model=opus safety=SAFE
#   metrics_record delivery channel=telegram status=success
#   metrics_summary 24h    # Print summary for last 24 hours
#
# Output: ${CRM_ROOT}/logs/${AGENT}/metrics.jsonl (append-only)
#
# Epic 114 / Story 114.17 Phase 2

_MC_AGENT="${CRM_AGENT_NAME:-prisma}"
_MC_INSTANCE="${CRM_INSTANCE_ID:-default}"
_MC_ROOT="${HOME}/.claude-remote/${_MC_INSTANCE}"
_MC_FILE="${_MC_ROOT}/logs/${_MC_AGENT}/metrics.jsonl"
_MC_START_TS=""

mkdir -p "$(dirname "${_MC_FILE}")" 2>/dev/null || true

# Start timer for duration measurement
metrics_start_timer() {
    # Use perl for millisecond precision (macOS compatible)
    _MC_START_TS=$(perl -e 'use Time::HiRes qw(time); printf "%d\n", time()*1000' 2>/dev/null \
        || python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null \
        || echo "$(($(date +%s) * 1000))")
}

# Record a metrics event
# Args: <event_type> [key=value ...]
# Standard events: interaction, delivery, fallback_attempt, error, compact, cron, safety_block
metrics_record() {
    local event="${1:-unknown}"
    shift

    local now_ms
    now_ms=$(perl -e 'use Time::HiRes qw(time); printf "%d\n", time()*1000' 2>/dev/null \
        || python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null \
        || echo "$(($(date +%s) * 1000))")

    local duration_ms=0
    if [[ -n "${_MC_START_TS}" && "${_MC_START_TS}" != "0" ]]; then
        duration_ms=$((now_ms - _MC_START_TS))
    fi

    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Build JSON with jq
    local json
    json=$(jq -n -c \
        --arg ts "$ts" \
        --arg event "$event" \
        --arg agent "${_MC_AGENT}" \
        --argjson duration_ms "$duration_ms" \
        '{ts:$ts, event:$event, agent:$agent, duration_ms:$duration_ms}')

    # Append extra key=value pairs
    while [[ $# -gt 0 ]]; do
        local kv="$1"; shift
        local key="${kv%%=*}"
        local val="${kv#*=}"
        json=$(echo "$json" | jq -c --arg k "$key" --arg v "$val" '. + {($k): $v}')
    done

    echo "$json" >> "${_MC_FILE}" 2>/dev/null || true
    _MC_START_TS=""  # Reset timer
}

# Summarize metrics for a period
# Args: <period> (1h, 24h, 7d)
# Output: formatted summary text
metrics_summary() {
    local period="${1:-24h}"
    [[ ! -f "${_MC_FILE}" ]] && echo "No metrics data" && return

    local seconds=86400  # default 24h
    case "$period" in
        1h)  seconds=3600 ;;
        24h) seconds=86400 ;;
        7d)  seconds=604800 ;;
    esac

    local cutoff
    cutoff=$(date -u -v-${seconds}S +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || date -u -d "${seconds} seconds ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || echo "2000-01-01T00:00:00Z")

    python3 - "${_MC_FILE}" "${cutoff}" "${period}" <<'PYEOF'
import json, sys
from collections import Counter

metrics_file, cutoff, period = sys.argv[1], sys.argv[2], sys.argv[3]
events = []
try:
    with open(metrics_file) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
                if e.get("ts", "") >= cutoff:
                    events.append(e)
            except json.JSONDecodeError:
                continue
except FileNotFoundError:
    print("No metrics file found")
    sys.exit(0)

if not events:
    print(f"No events in last {period}")
    sys.exit(0)

# Count by event type
by_type = Counter(e.get("event", "unknown") for e in events)
interactions = [e for e in events if e["event"] == "interaction"]
deliveries = [e for e in events if e["event"] == "delivery"]
fallbacks = [e for e in events if e["event"] == "fallback_attempt"]
safety = [e for e in events if e["event"] == "safety_block"]
models = Counter(e.get("model", "unknown") for e in events if e.get("model"))

# Avg duration
avg_dur = 0
if interactions:
    durations = [e.get("duration_ms", 0) for e in interactions if isinstance(e.get("duration_ms"), (int, float))]
    avg_dur = sum(durations) / len(durations) / 1000 if durations else 0

# Delivery success rate
delivery_ok = sum(1 for e in deliveries if e.get("delivery_status") == "success")
delivery_rate = (delivery_ok / len(deliveries) * 100) if deliveries else 100

# Fallback rate
fb_rate = (len(fallbacks) / max(len(interactions), 1) * 100) if fallbacks else 0

lines = [f"Metrics ({period}):"]
lines.append(f"  Interactions: {len(interactions)} (avg {avg_dur:.1f}s)")
lines.append(f"  Fallbacks: {len(fallbacks)} ({fb_rate:.1f}%)")
lines.append(f"  Deliveries: {len(deliveries)} ({delivery_rate:.1f}% success)")
lines.append(f"  Safety blocks: {len(safety)}")
if models:
    model_str = ", ".join(f"{m}={c}" for m, c in models.most_common(5))
    lines.append(f"  Models: {model_str}")
print("\n".join(lines))
PYEOF
}

# Rotate metrics: compress files older than 7 days
metrics_rotate() {
    local log_dir="${_MC_ROOT}/logs/${_MC_AGENT}"
    local current="${_MC_FILE}"
    [[ ! -f "${current}" ]] && return

    # Use date-based rotation marker instead of mtime (QA fix BUG-6 — mtime always recent on active file)
    local rotation_marker="${log_dir}/.metrics-last-rotation"
    local last_rotation=0
    [[ -f "${rotation_marker}" ]] && last_rotation=$(cat "${rotation_marker}" 2>/dev/null || echo "0")
    local now_epoch
    now_epoch=$(date +%s)
    local days_since=$(( (now_epoch - last_rotation) / 86400 ))
    if [[ ${days_since} -ge 7 ]]; then  # 7 days since last rotation
        local archive="${log_dir}/metrics-$(date +%Y%m%d).jsonl"
        mv "${current}" "${archive}" 2>/dev/null || true
        gzip "${archive}" 2>/dev/null || true
        echo "${now_epoch}" > "${rotation_marker}" 2>/dev/null || true
    fi
}
