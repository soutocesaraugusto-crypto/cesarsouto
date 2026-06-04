#!/usr/bin/env bash
# adapter-integrity.sh — SHA-256 integrity verification for adapters
# OpenClaw pattern: plugin integrity checking with baseline hashing
#
# Usage:
#   adapter-integrity.sh baseline <adapter>   # Generate SHA-256 baseline
#   adapter-integrity.sh verify <adapter>     # Verify against baseline
#   adapter-integrity.sh verify-all           # Verify all adapters
#
# Baseline stored at: adapters/<name>/.integrity.json
#
# Epic 110 / Story 110.29 Phase 14

set -uo pipefail

ACTION="${1:-verify-all}"
ADAPTER="${2:-}"
TEMPLATE_ROOT="${CRM_TEMPLATE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
ADAPTERS_DIR="${TEMPLATE_ROOT}/adapters"

sha256_file() {
    shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1 || sha256sum "$1" 2>/dev/null | cut -d' ' -f1
}

generate_baseline() {
    local adapter="$1"
    local dir="${ADAPTERS_DIR}/${adapter}"
    [[ ! -d "$dir" ]] && { echo "Adapter not found: ${adapter}"; exit 1; }

    local result='{"adapter":"'"${adapter}"'","generated":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","files":{}}'

    for script in "${dir}"/*.sh; do
        [[ ! -f "$script" ]] && continue
        local name
        name=$(basename "$script")
        local hash
        hash=$(sha256_file "$script")
        result=$(echo "$result" | jq -c --arg f "$name" --arg h "$hash" '.files[$f] = $h')
    done

    echo "$result" | jq . > "${dir}/.integrity.json"
    echo "Baseline generated for ${adapter}: ${dir}/.integrity.json"
}

verify_adapter() {
    local adapter="$1"
    local dir="${ADAPTERS_DIR}/${adapter}"
    local baseline="${dir}/.integrity.json"

    if [[ ! -f "$baseline" ]]; then
        echo "SKIP: No baseline for ${adapter} (run: adapter-integrity.sh baseline ${adapter})"
        return 0
    fi

    local ok=true
    while IFS= read -r entry; do
        local name hash_expected hash_actual
        name=$(echo "$entry" | jq -r '.key')
        hash_expected=$(echo "$entry" | jq -r '.value')
        local file="${dir}/${name}"

        if [[ ! -f "$file" ]]; then
            echo "FAIL: ${adapter}/${name} — file missing"
            ok=false
            continue
        fi

        hash_actual=$(sha256_file "$file")
        if [[ "$hash_expected" != "$hash_actual" ]]; then
            echo "FAIL: ${adapter}/${name} — hash mismatch (expected ${hash_expected:0:12}..., got ${hash_actual:0:12}...)"
            ok=false
        fi
    done < <(jq -c '.files | to_entries[]' "$baseline" 2>/dev/null)

    $ok && echo "OK: ${adapter} — all files match baseline"
    $ok && return 0 || return 1
}

case "${ACTION}" in
    baseline)
        [[ -z "$ADAPTER" ]] && { echo "Usage: adapter-integrity.sh baseline <adapter>"; exit 1; }
        generate_baseline "$ADAPTER"
        ;;
    verify)
        [[ -z "$ADAPTER" ]] && { echo "Usage: adapter-integrity.sh verify <adapter>"; exit 1; }
        verify_adapter "$ADAPTER"
        ;;
    verify-all)
        ALL_OK=true
        for dir in "${ADAPTERS_DIR}"/*/; do
            [[ ! -d "$dir" ]] && continue
            adapter=$(basename "$dir")
            verify_adapter "$adapter" || ALL_OK=false
        done
        $ALL_OK && exit 0 || exit 1
        ;;
    *)
        echo "Usage: adapter-integrity.sh {baseline|verify|verify-all} [adapter]" >&2
        exit 1
        ;;
esac
