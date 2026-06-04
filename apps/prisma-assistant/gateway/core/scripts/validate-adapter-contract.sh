#!/usr/bin/env bash
# validate-adapter-contract.sh — Validate adapter compliance with formal contract
#
# Checks that an adapter implements all required scripts, passes bash -n,
# has required env vars documented, and follows the adapter contract spec.
#
# Usage:
#   validate-adapter-contract.sh <adapter_name>         # Validate one adapter
#   validate-adapter-contract.sh --all                  # Validate all adapters
#
# Exit codes: 0=OK, 1=warnings, 2=errors (blocks deploy)
#
# Story 114.19 Phase 2 — Formal Adapter Contract

set -uo pipefail

TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
ADAPTERS_DIR="${TEMPLATE_ROOT}/adapters"
BUS_DIR="${TEMPLATE_ROOT}/core/bus"
CONTRACTS_DIR="${ADAPTERS_DIR}"

ADAPTER="${1:-}"
ERRORS=0
WARNINGS=0
RESULTS="[]"

_check() {
    local adapter="$1" file="$2" required="$3" description="$4"
    if [[ -f "$file" ]]; then
        # Check bash -n syntax (only for .sh files)
        if [[ "$file" == *.sh ]]; then
            if ! bash -n "$file" 2>/dev/null; then
                ERRORS=$((ERRORS + 1))
                RESULTS=$(echo "$RESULTS" | jq -c --arg a "$adapter" --arg f "$(basename "$file")" --arg d "Syntax error (bash -n failed)" '. + [{adapter: $a, file: $f, status: "ERROR", detail: $d}]')
                return
            fi
        fi
        # Check shebang
        if [[ "$file" == *.sh ]]; then
            local shebang
            shebang=$(head -1 "$file")
            if [[ "$shebang" != "#!/usr/bin/env bash" && "$shebang" != "#!/bin/bash" ]]; then
                WARNINGS=$((WARNINGS + 1))
                RESULTS=$(echo "$RESULTS" | jq -c --arg a "$adapter" --arg f "$(basename "$file")" --arg d "Missing or non-standard shebang" '. + [{adapter: $a, file: $f, status: "WARN", detail: $d}]')
            fi
        fi
        RESULTS=$(echo "$RESULTS" | jq -c --arg a "$adapter" --arg f "$(basename "$file")" --arg d "$description" '. + [{adapter: $a, file: $f, status: "OK", detail: $d}]')
    elif [[ "$required" == "true" ]]; then
        ERRORS=$((ERRORS + 1))
        RESULTS=$(echo "$RESULTS" | jq -c --arg a "$adapter" --arg f "$(basename "$file")" --arg d "MISSING (required): $description" '. + [{adapter: $a, file: $f, status: "ERROR", detail: $d}]')
    else
        WARNINGS=$((WARNINGS + 1))
        RESULTS=$(echo "$RESULTS" | jq -c --arg a "$adapter" --arg f "$(basename "$file")" --arg d "Missing (optional): $description" '. + [{adapter: $a, file: $f, status: "WARN", detail: $d}]')
    fi
}

_validate_adapter() {
    local adapter="$1"
    local contract_file="${ADAPTERS_DIR}/${adapter}/contract.yaml"

    # Check contract.yaml exists
    if [[ ! -f "$contract_file" ]]; then
        ERRORS=$((ERRORS + 1))
        RESULTS=$(echo "$RESULTS" | jq -c --arg a "$adapter" '. + [{adapter: $a, file: "contract.yaml", status: "ERROR", detail: "Contract file missing"}]')
        # Fall back to checking standard files without contract
        _check "$adapter" "${ADAPTERS_DIR}/${adapter}/start.sh" "true" "Adapter lifecycle: start"
        _check "$adapter" "${ADAPTERS_DIR}/${adapter}/health.sh" "true" "Adapter lifecycle: health check"
        _check "$adapter" "${ADAPTERS_DIR}/${adapter}/stop.sh" "true" "Adapter lifecycle: stop"
        _check "$adapter" "${BUS_DIR}/send-${adapter}.sh" "true" "Bus: send message"
        _check "$adapter" "${BUS_DIR}/check-${adapter}.sh" "true" "Bus: poll/check messages"
        _check "$adapter" "${BUS_DIR}/hook-permission-${adapter}.sh" "true" "Bus: permission hook"
        _check "$adapter" "${BUS_DIR}/hook-ask-${adapter}.sh" "false" "Bus: ask hook (optional)"
        _check "$adapter" "${BUS_DIR}/hook-planmode-${adapter}.sh" "false" "Bus: plan mode hook (optional)"
        return
    fi

    RESULTS=$(echo "$RESULTS" | jq -c --arg a "$adapter" '. + [{adapter: $a, file: "contract.yaml", status: "OK", detail: "Contract loaded"}]')

    # Parse contract.yaml and validate each entry
    # Required lifecycle scripts
    local req_scripts
    req_scripts=$(python3 -c "
import yaml, sys, json
with open('$contract_file') as f:
    c = yaml.safe_load(f)
a = c.get('adapter', {})
scripts = a.get('required_scripts', [])
for s in scripts:
    print(json.dumps(s))
" 2>/dev/null || echo "")

    if [[ -z "$req_scripts" ]]; then
        # Fallback: parse with grep (no python/yaml available)
        _check "$adapter" "${ADAPTERS_DIR}/${adapter}/start.sh" "true" "Adapter lifecycle: start"
        _check "$adapter" "${ADAPTERS_DIR}/${adapter}/health.sh" "true" "Adapter lifecycle: health check"
        _check "$adapter" "${ADAPTERS_DIR}/${adapter}/stop.sh" "true" "Adapter lifecycle: stop"
    else
        while IFS= read -r script_json; do
            [[ -z "$script_json" ]] && continue
            local name
            name=$(echo "$script_json" | jq -r '.name' 2>/dev/null)
            _check "$adapter" "${ADAPTERS_DIR}/${adapter}/${name}" "true" "Required lifecycle script"
        done <<< "$req_scripts"
    fi

    # Required bus scripts (resolve {channel} placeholder)
    local req_bus
    req_bus=$(python3 -c "
import yaml, json
with open('$contract_file') as f:
    c = yaml.safe_load(f)
a = c.get('adapter', {})
for s in a.get('required_bus_scripts', []):
    print(s.replace('{channel}', '$adapter'))
" 2>/dev/null || echo "")

    if [[ -z "$req_bus" ]]; then
        _check "$adapter" "${BUS_DIR}/send-${adapter}.sh" "true" "Bus: send"
        _check "$adapter" "${BUS_DIR}/check-${adapter}.sh" "true" "Bus: check"
        _check "$adapter" "${BUS_DIR}/hook-permission-${adapter}.sh" "true" "Bus: permission hook"
    else
        while IFS= read -r bus_path; do
            [[ -z "$bus_path" ]] && continue
            _check "$adapter" "${TEMPLATE_ROOT}/${bus_path}" "true" "Required bus script"
        done <<< "$req_bus"
    fi

    # Optional bus scripts
    local opt_bus
    opt_bus=$(python3 -c "
import yaml
with open('$contract_file') as f:
    c = yaml.safe_load(f)
a = c.get('adapter', {})
for s in a.get('optional_bus_scripts', []):
    print(s.replace('{channel}', '$adapter'))
" 2>/dev/null || echo "")

    while IFS= read -r bus_path; do
        [[ -z "$bus_path" ]] && continue
        _check "$adapter" "${TEMPLATE_ROOT}/${bus_path}" "false" "Optional bus script"
    done <<< "$opt_bus"
}

# === Main ===
if [[ "${ADAPTER}" == "--all" ]]; then
    for dir in "${ADAPTERS_DIR}"/*/; do
        [[ ! -d "$dir" ]] && continue
        adapter_name=$(basename "$dir")
        [[ "$adapter_name" == "agent-template" ]] && continue
        _validate_adapter "$adapter_name"
    done
elif [[ -n "${ADAPTER}" ]]; then
    _validate_adapter "${ADAPTER}"
else
    echo "Usage: validate-adapter-contract.sh <adapter_name|--all>" >&2
    exit 1
fi

# === Output ===
echo ""
echo "Adapter Contract Validation:"
echo "$RESULTS" | jq -r '.[] | "  [\(.status)] \(.adapter)/\(.file): \(.detail)"'
echo ""
echo "Summary: ${ERRORS} errors, ${WARNINGS} warnings"

if [[ ${ERRORS} -gt 0 ]]; then
    exit 2
elif [[ ${WARNINGS} -gt 0 ]]; then
    exit 1
else
    exit 0
fi
