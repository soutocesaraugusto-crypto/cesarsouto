#!/usr/bin/env bash
# test-runtime-compat.sh — Smoke tests for runtime driver compatibility
# Validates that all 3 runtimes load, validate interface, and handle config correctly.
#
# Usage: bash tests/test-runtime-compat.sh
#
# Epic 114 / Story 114.4

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GATEWAY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUNTIME_SH="${GATEWAY_ROOT}/core/runtimes/runtime.sh"

PASS=0
FAIL=0
TOTAL=0

test_case() {
    TOTAL=$((TOTAL + 1))
    local name="$1"
    local result="$2"
    local expected="${3:-0}"
    if [[ "${result}" -eq "${expected}" ]]; then
        echo "  PASS: ${name}"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: ${name} (got ${result}, expected ${expected})"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Runtime Compatibility Smoke Tests ==="
echo ""

# --- Test 1: Claude Code driver loads ---
echo "[1] Claude Code driver"
RUNTIME_TYPE=claude-code CRM_AGENT_NAME=test-agent bash -c "source '${RUNTIME_SH}' && echo OK" > /dev/null 2>&1
test_case "claude-code driver loads" $? 0

# --- Test 2: Codex driver loads ---
echo "[2] Codex driver"
RUNTIME_TYPE=codex CRM_AGENT_NAME=test-agent bash -c "source '${RUNTIME_SH}' && echo OK" > /dev/null 2>&1
test_case "codex driver loads" $? 0

# --- Test 3: API-OpenRouter driver loads ---
echo "[3] API-OpenRouter driver"
RUNTIME_TYPE=api-openrouter CRM_AGENT_NAME=test-agent bash -c "source '${RUNTIME_SH}' && echo OK" > /dev/null 2>&1
test_case "api-openrouter driver loads" $? 0

# --- Test 4: Invalid driver fails with clear error ---
echo "[4] Invalid driver detection"
ERR=$(RUNTIME_TYPE=nonexistent CRM_AGENT_NAME=test-agent bash -c "source '${RUNTIME_SH}'" 2>&1 || true)
echo "${ERR}" | grep -q "FATAL: Runtime driver not found"
test_case "invalid driver shows FATAL error" $? 0

echo "${ERR}" | grep -q "Available drivers"
test_case "invalid driver lists available drivers" $? 0

# --- Test 5: Default runtime (no RUNTIME_TYPE env) resolves to claude-code ---
echo "[5] Default runtime resolution"
RESULT=$(CRM_AGENT_NAME=test-agent bash -c "source '${RUNTIME_SH}' && echo \${RUNTIME_TYPE}" 2>/dev/null || echo "error")
[[ "${RESULT}" == "claude-code" ]]
test_case "default runtime is claude-code" $? 0

# --- Test 6: Interface contract validation ---
echo "[6] Interface contract"
FUNCTIONS=(runtime_launch runtime_continue runtime_print runtime_model_flag runtime_system_prompt_flag runtime_settings_path runtime_detect_busy runtime_detect_idle runtime_builtin_commands runtime_cron_command runtime_permissions_flag runtime_conversation_dir)

for driver in claude-code codex api-openrouter; do
    for fn in "${FUNCTIONS[@]}"; do
        RUNTIME_TYPE=$driver CRM_AGENT_NAME=test-agent bash -c "source '${RUNTIME_SH}' && declare -f '${fn}' > /dev/null" 2>/dev/null
        test_case "${driver}::${fn} exists" $? 0
    done
done

# --- Test 7: runtime_print (one-shot) works for Claude Code ---
echo "[7] runtime_print (claude-code)"
if command -v claude &>/dev/null; then
    RESULT=$(RUNTIME_TYPE=claude-code CRM_AGENT_NAME=test-agent bash -c "source '${RUNTIME_SH}' && runtime_print 'Say exactly: SMOKE_TEST_OK'" 2>/dev/null || echo "")
    echo "${RESULT}" | grep -qi "SMOKE_TEST_OK"
    test_case "claude-code runtime_print returns response" $? 0
else
    echo "  SKIP: claude CLI not found (runtime_print test)"
fi

# --- Test 8: runtime_print (api-openrouter, if key available) ---
echo "[8] runtime_print (api-openrouter)"
if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    RESULT=$(RUNTIME_TYPE=api-openrouter CRM_AGENT_NAME=test-agent OPENROUTER_MODEL=anthropic/claude-3.5-haiku bash -c "source '${RUNTIME_SH}' && runtime_print 'Say exactly: SMOKE_TEST_OK'" 2>/dev/null || echo "")
    echo "${RESULT}" | grep -qi "SMOKE_TEST_OK"
    test_case "api-openrouter runtime_print returns response" $? 0
else
    echo "  SKIP: OPENROUTER_API_KEY not set (runtime_print test)"
fi

# --- Test 9: Syntax check all driver files ---
echo "[9] Syntax validation"
for f in "${GATEWAY_ROOT}"/core/runtimes/*.sh; do
    [[ "$(basename "$f")" == "custom.sh.template" ]] && continue
    bash -n "$f" 2>/dev/null
    test_case "bash -n $(basename "$f")" $? 0
done
python3 -c "import py_compile; py_compile.compile('${GATEWAY_ROOT}/core/runtimes/api-client.py', doraise=True)" 2>/dev/null
test_case "python3 syntax api-client.py" $? 0

# --- Test 10: Config JSON validity ---
echo "[10] Config templates"
for f in "${GATEWAY_ROOT}"/config.json.*; do
    python3 -c "import json; json.load(open('${f}'))" 2>/dev/null
    test_case "JSON valid: $(basename "$f")" $? 0
done

# --- Summary ---
echo ""
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
[[ ${FAIL} -eq 0 ]] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit ${FAIL}
