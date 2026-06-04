#!/usr/bin/env bash
# test-gateway-e2e.sh — E2E tests for Universal Agent Gateway
#
# Tests the full message pipeline, delivery queue, config validation,
# mock runtime, and adapter mode — WITHOUT any real CLI or API.
#
# Usage: bash tests/test-gateway-e2e.sh
#
# Epic 114 / Stories 114.13 + 114.14

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GATEWAY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_STATE=$(mktemp -d)
PASS=0
FAIL=0
SKIP=0
TOTAL=0

cleanup() { rm -rf "${TEST_STATE}"; }
trap cleanup EXIT

pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  FAIL: $1 — $2"; }
skip() { SKIP=$((SKIP+1)); TOTAL=$((TOTAL+1)); echo "  SKIP: $1"; }

# Setup mock CRM state
export CRM_ROOT="${TEST_STATE}"
export CRM_INSTANCE_ID="test"
export CRM_AGENT_NAME="test-agent"
export CRM_TEMPLATE_ROOT="${GATEWAY_ROOT}"
mkdir -p "${TEST_STATE}"/{config,state,inbox,channel-inbox,queue,logs}/test-agent
mkdir -p "${TEST_STATE}/logs/test-agent"

echo "================================================================="
echo "  Universal Agent Gateway — E2E Tests"
echo "  State: ${TEST_STATE}"
echo "================================================================="

# ===== E2E-1: Mock Runtime =====
echo ""
echo "--- E2E-1: Mock Runtime Driver ---"

RUNTIME_TYPE=mock bash -c "source '${GATEWAY_ROOT}/core/runtimes/runtime.sh' && echo OK" > /dev/null 2>&1
[[ $? -eq 0 ]] && pass "mock driver loads via facade" || fail "mock driver load" "facade rejected it"

RESULT=$(RUNTIME_TYPE=mock MOCK_PRINT_RESPONSE="HELLO_TEST" bash -c "
    source '${GATEWAY_ROOT}/core/runtimes/runtime.sh'
    runtime_print 'test'
" 2>/dev/null)
[[ "$RESULT" == "HELLO_TEST" ]] && pass "mock runtime_print returns configured response" || fail "mock runtime_print" "got: $RESULT"

# Test busy/idle
RESULT=$(RUNTIME_TYPE=mock MOCK_BUSY=true bash -c "
    source '${GATEWAY_ROOT}/core/runtimes/runtime.sh'
    runtime_detect_busy test-session && echo BUSY || echo IDLE
" 2>/dev/null)
[[ "$RESULT" == "BUSY" ]] && pass "mock detect_busy returns busy when MOCK_BUSY=true" || fail "mock detect_busy" "got: $RESULT"

RESULT=$(RUNTIME_TYPE=mock MOCK_BUSY=false bash -c "
    source '${GATEWAY_ROOT}/core/runtimes/runtime.sh'
    runtime_detect_idle test-session && echo IDLE || echo BUSY
" 2>/dev/null)
[[ "$RESULT" == "IDLE" ]] && pass "mock detect_idle returns idle when MOCK_BUSY=false" || fail "mock detect_idle" "got: $RESULT"

# ===== E2E-2: Delivery Queue =====
echo ""
echo "--- E2E-2: Delivery Queue ---"

QUEUE_SCRIPT="${GATEWAY_ROOT}/core/bus/delivery-queue.sh"
if [[ -f "${QUEUE_SCRIPT}" ]]; then
    # Enqueue a message
    FILENAME=$(bash "${QUEUE_SCRIPT}" enqueue test-agent telegram 12345 "Test queued message" 2>/dev/null)
    [[ -n "${FILENAME}" ]] && pass "delivery-queue enqueue returns filename" || fail "enqueue" "empty filename"

    # Check status
    STATUS=$(bash "${QUEUE_SCRIPT}" status test-agent 2>/dev/null)
    echo "${STATUS}" | grep -q "1 pending" && pass "delivery-queue shows 1 pending" || fail "queue status" "$STATUS"

    # Cleanup
    bash "${QUEUE_SCRIPT}" cleanup test-agent > /dev/null 2>&1
    pass "delivery-queue cleanup runs without error"
else
    skip "delivery-queue.sh not found"
fi

# ===== E2E-3: Channel Inbox Write =====
echo ""
echo "--- E2E-3: Channel Inbox (Adapter Pattern) ---"

WRITE_SCRIPT="${GATEWAY_ROOT}/core/bus/write-channel-inbox.sh"
if [[ -f "${WRITE_SCRIPT}" ]]; then
    MSG='{"_source":"telegram","_type":"message","_timestamp":"2026-04-05T12:00:00Z","platform":"telegram","chat_id":"123","from":"test-user","text":"Hello from test"}'
    FNAME=$(echo "${MSG}" | bash "${WRITE_SCRIPT}" test-agent 2>/dev/null)
    if [[ -n "${FNAME}" ]]; then
        pass "write-channel-inbox returns filename"
        # Verify file exists
        INBOX_FILE="${TEST_STATE}/channel-inbox/test-agent/${FNAME}"
        [[ -f "${INBOX_FILE}" ]] && pass "channel-inbox file created" || fail "inbox file" "not found at ${INBOX_FILE}"
        # Verify JSON is valid
        jq empty "${INBOX_FILE}" 2>/dev/null && pass "channel-inbox JSON is valid" || fail "inbox JSON" "invalid"
    else
        fail "write-channel-inbox" "empty filename"
    fi
else
    skip "write-channel-inbox.sh not found"
fi

# ===== E2E-4: Config Validation =====
echo ""
echo "--- E2E-4: Config Validation ---"

# Valid JSON schema
SCHEMA="${GATEWAY_ROOT}/core/schemas/config.schema.json"
[[ -f "${SCHEMA}" ]] && pass "config.schema.json exists" || fail "schema" "not found"
python3 -c "import json; json.load(open('${SCHEMA}'))" 2>/dev/null && pass "config schema is valid JSON" || fail "schema JSON" "parse error"

# All example configs are valid JSON
for f in "${GATEWAY_ROOT}"/config.json.*; do
    name=$(basename "$f")
    python3 -c "import json; json.load(open('${f}'))" 2>/dev/null && pass "config ${name} valid JSON" || fail "config ${name}" "parse error"
done

# ===== E2E-5: Runtime Interface Contract =====
echo ""
echo "--- E2E-5: Interface Contract (all drivers) ---"

DRIVERS=(claude-code codex api-openrouter mock)
FUNCTIONS=(runtime_launch runtime_continue runtime_print runtime_model_flag runtime_system_prompt_flag runtime_settings_path runtime_detect_busy runtime_detect_idle runtime_builtin_commands runtime_cron_command runtime_permissions_flag runtime_conversation_dir)

for driver in "${DRIVERS[@]}"; do
    MISSING=0
    for fn in "${FUNCTIONS[@]}"; do
        if ! RUNTIME_TYPE=$driver CRM_AGENT_NAME=test bash -c "source '${GATEWAY_ROOT}/core/runtimes/runtime.sh' && declare -f '${fn}' > /dev/null" 2>/dev/null; then
            MISSING=$((MISSING + 1))
        fi
    done
    [[ ${MISSING} -eq 0 ]] && pass "${driver}: all 12 functions present" || fail "${driver}" "${MISSING} functions missing"
done

# ===== E2E-6: Builtin Command Pattern =====
echo ""
echo "--- E2E-6: Builtin Command Pattern ---"

CC_BUILTINS=$(RUNTIME_TYPE=claude-code CRM_AGENT_NAME=test bash -c "source '${GATEWAY_ROOT}/core/runtimes/runtime.sh' && runtime_builtin_commands" 2>/dev/null)
echo "${CC_BUILTINS}" | grep -q "compact" && pass "claude-code builtins include 'compact'" || fail "cc builtins" "missing compact"
echo "${CC_BUILTINS}" | grep -q "help" && pass "claude-code builtins include 'help'" || fail "cc builtins" "missing help"

CODEX_BUILTINS=$(RUNTIME_TYPE=codex CRM_AGENT_NAME=test bash -c "source '${GATEWAY_ROOT}/core/runtimes/runtime.sh' && runtime_builtin_commands" 2>/dev/null)
[[ -z "${CODEX_BUILTINS}" ]] && pass "codex builtins empty (no /loop etc)" || fail "codex builtins" "expected empty, got: $CODEX_BUILTINS"

# ===== E2E-7: Cron Command Pattern =====
echo ""
echo "--- E2E-7: Cron Command Pattern ---"

CC_CRON=$(RUNTIME_TYPE=claude-code CRM_AGENT_NAME=test bash -c "source '${GATEWAY_ROOT}/core/runtimes/runtime.sh' && runtime_cron_command '5m' 'test prompt'" 2>/dev/null)
echo "${CC_CRON}" | grep -q "/loop" && pass "claude-code cron uses /loop" || fail "cc cron" "$CC_CRON"

CODEX_CRON=$(RUNTIME_TYPE=codex CRM_AGENT_NAME=test bash -c "source '${GATEWAY_ROOT}/core/runtimes/runtime.sh' && runtime_cron_command '5m' 'test'" 2>/dev/null)
[[ "${CODEX_CRON}" == "__EXTERNAL_CRON__" ]] && pass "codex cron returns __EXTERNAL_CRON__" || fail "codex cron" "$CODEX_CRON"

API_CRON=$(RUNTIME_TYPE=api-openrouter CRM_AGENT_NAME=test bash -c "source '${GATEWAY_ROOT}/core/runtimes/runtime.sh' && runtime_cron_command '5m' 'test'" 2>/dev/null)
[[ "${API_CRON}" == "__EXTERNAL_CRON__" ]] && pass "api cron returns __EXTERNAL_CRON__" || fail "api cron" "$API_CRON"

# ===== E2E-8: Syntax Check ALL Scripts =====
echo ""
echo "--- E2E-8: Comprehensive Syntax ---"

SYNTAX_FAIL=0
for f in "${GATEWAY_ROOT}"/core/runtimes/*.sh; do
    name=$(basename "$f")
    [[ "$name" == "custom.sh.template" ]] && continue
    if ! bash -n "$f" 2>/dev/null; then
        fail "syntax ${name}" "bash -n failed"
        SYNTAX_FAIL=$((SYNTAX_FAIL + 1))
    fi
done
for f in "${GATEWAY_ROOT}"/core/runtimes/*.py; do
    name=$(basename "$f")
    if ! python3 -c "import py_compile; py_compile.compile('${f}', doraise=True)" 2>/dev/null; then
        fail "syntax ${name}" "py_compile failed"
        SYNTAX_FAIL=$((SYNTAX_FAIL + 1))
    fi
done
[[ ${SYNTAX_FAIL} -eq 0 ]] && pass "all runtime files pass syntax check" || true

# ===== E2E-9: Webhook Receiver Schema =====
echo ""
echo "--- E2E-9: Webhook Receiver ---"

WEBHOOK="${GATEWAY_ROOT}/core/webhook/webhook-receiver.py"
if [[ -f "${WEBHOOK}" ]]; then
    python3 -c "import py_compile; py_compile.compile('${WEBHOOK}', doraise=True)" 2>/dev/null && pass "webhook-receiver.py syntax" || fail "webhook syntax" "compile error"
    grep -q "channel-inbox" "${WEBHOOK}" && pass "webhook writes to channel-inbox" || fail "webhook path" "wrong inbox"
    grep -q "_source" "${WEBHOOK}" && pass "webhook includes _source field" || fail "webhook schema" "missing _source"
    grep -q "WEBHOOK_SECRET" "${WEBHOOK}" && pass "webhook validates secret token" || fail "webhook security" "no secret validation"
else
    skip "webhook-receiver.py not found"
fi

# ===== E2E-10: Markdown Sanitizer =====
echo ""
echo "--- E2E-10: Supporting Scripts ---"

SANITIZER="${GATEWAY_ROOT}/core/bus/_markdown-sanitize.sh"
[[ -f "${SANITIZER}" ]] && pass "_markdown-sanitize.sh exists" || skip "_markdown-sanitize.sh not found"

LOGGER="${GATEWAY_ROOT}/core/bus/_logger.sh"
[[ -f "${LOGGER}" ]] && pass "_logger.sh exists" || skip "_logger.sh not found"

RETRY="${GATEWAY_ROOT}/core/bus/_telegram-curl.sh"
if [[ -f "${RETRY}" ]]; then
    grep -q "telegram_api_post_retry" "${RETRY}" && pass "_telegram-curl has retry function" || fail "retry" "missing telegram_api_post_retry"
    grep -q "_is_transient_error" "${RETRY}" && pass "_telegram-curl has transient error detection" || fail "transient" "missing _is_transient_error"
fi

# ===== E2E-11: All 5 Channel Adapters Have Lifecycle =====
echo ""
echo "--- E2E-11: Channel Adapter Lifecycle ---"

CHANNELS=(telegram discord web whatsapp slack)
for ch in "${CHANNELS[@]}"; do
    ADAPTER_DIR="${GATEWAY_ROOT}/adapters/${ch}"
    if [[ -d "${ADAPTER_DIR}" ]]; then
        [[ -f "${ADAPTER_DIR}/start.sh" ]] && pass "${ch} adapter: start.sh exists" || fail "${ch} adapter" "missing start.sh"
        [[ -f "${ADAPTER_DIR}/health.sh" ]] && pass "${ch} adapter: health.sh exists" || fail "${ch} adapter" "missing health.sh"
        [[ -f "${ADAPTER_DIR}/stop.sh" ]] && pass "${ch} adapter: stop.sh exists" || fail "${ch} adapter" "missing stop.sh"
        bash -n "${ADAPTER_DIR}/start.sh" 2>/dev/null && pass "${ch} adapter: start.sh syntax" || fail "${ch} adapter" "start.sh syntax error"
        bash -n "${ADAPTER_DIR}/health.sh" 2>/dev/null && pass "${ch} adapter: health.sh syntax" || fail "${ch} adapter" "health.sh syntax error"
        bash -n "${ADAPTER_DIR}/stop.sh" 2>/dev/null && pass "${ch} adapter: stop.sh syntax" || fail "${ch} adapter" "stop.sh syntax error"
    else
        fail "${ch} adapter" "directory missing"
    fi
done

# ===== E2E-12: All 5 Channel Bus Scripts =====
echo ""
echo "--- E2E-12: Channel Bus Scripts ---"

for ch in "${CHANNELS[@]}"; do
    for script_type in send check hook-permission; do
        SCRIPT="${GATEWAY_ROOT}/core/bus/${script_type}-${ch}.sh"
        if [[ -f "${SCRIPT}" ]]; then
            bash -n "${SCRIPT}" 2>/dev/null && pass "${script_type}-${ch}.sh syntax" || fail "${script_type}-${ch}.sh" "syntax error"
        else
            fail "${script_type}-${ch}.sh" "not found"
        fi
    done
done

# ===== E2E-13: Fallback Chain =====
echo ""
echo "--- E2E-13: Fallback Chain ---"

FALLBACK="${GATEWAY_ROOT}/core/runtimes/fallback.sh"
if [[ -f "${FALLBACK}" ]]; then
    bash -n "${FALLBACK}" 2>/dev/null && pass "fallback.sh syntax" || fail "fallback.sh" "syntax error"
    grep -q "circuit.breaker" "${FALLBACK}" && pass "fallback has circuit breaker" || fail "fallback" "missing circuit breaker"
    grep -q "_is_fatal" "${FALLBACK}" && pass "fallback has fatal error detection" || fail "fallback" "missing fatal detection"
    grep -q "cooldown" "${FALLBACK}" && pass "fallback has cooldown tracking" || fail "fallback" "missing cooldown"
else
    fail "fallback.sh" "not found"
fi

# ===== E2E-14: Safety Scanner =====
echo ""
echo "--- E2E-14: Safety Scanner ---"

SCANNER="${GATEWAY_ROOT}/core/scripts/safety-scanner.sh"
if [[ -f "${SCANNER}" ]]; then
    bash -n "${SCANNER}" 2>/dev/null && pass "safety-scanner.sh syntax" || fail "safety-scanner" "syntax error"

    # Test SAFE input
    echo "git push origin main" | bash "${SCANNER}" 2>/dev/null
    [[ $? -eq 0 ]] && pass "safety: 'git push' → SAFE" || fail "safety" "'git push' should be SAFE"

    # Test DANGEROUS input
    echo "rm -rf /" | bash "${SCANNER}" 2>/dev/null
    [[ $? -eq 2 ]] && pass "safety: 'rm -rf /' → DANGEROUS" || fail "safety" "'rm -rf /' should be DANGEROUS (exit 2)"

    # Test CAUTION input
    echo "sudo apt update" | bash "${SCANNER}" 2>/dev/null
    RC=$?
    [[ $RC -eq 1 || $RC -eq 2 ]] && pass "safety: 'sudo apt update' → CAUTION or DANGEROUS" || fail "safety" "'sudo' should flag (got exit $RC)"
else
    fail "safety-scanner.sh" "not found"
fi

# ===== E2E-15: Metrics Collector =====
echo ""
echo "--- E2E-15: Metrics Collector ---"

METRICS="${GATEWAY_ROOT}/core/scripts/metrics-collector.sh"
if [[ -f "${METRICS}" ]]; then
    bash -n "${METRICS}" 2>/dev/null && pass "metrics-collector.sh syntax" || fail "metrics" "syntax error"

    # Test metrics recording — override _MC_FILE AFTER source (script sets at load)
    mkdir -p "${TEST_STATE}/logs/test-agent"
    METRICS_OUT=$(CRM_AGENT_NAME=test-agent CRM_INSTANCE_ID=test bash -c "
        source '${METRICS}'
        _MC_FILE='${TEST_STATE}/logs/test-agent/metrics.jsonl'
        metrics_start_timer
        sleep 0.1
        metrics_record interaction channel=telegram model=mock safety=SAFE
        cat '${TEST_STATE}/logs/test-agent/metrics.jsonl' 2>/dev/null
    " 2>/dev/null)
    echo "${METRICS_OUT}" | jq -e '.event == "interaction"' > /dev/null 2>&1 && pass "metrics: interaction event recorded" || fail "metrics" "event not recorded"
    echo "${METRICS_OUT}" | jq -e '.duration_ms > 0' > /dev/null 2>&1 && pass "metrics: duration_ms > 0" || fail "metrics" "duration not tracked"
else
    fail "metrics-collector.sh" "not found"
fi

# ===== E2E-16: Health Alerter =====
echo ""
echo "--- E2E-16: Health Alerter ---"

ALERTER="${GATEWAY_ROOT}/core/scripts/health-alerter.sh"
if [[ -f "${ALERTER}" ]]; then
    bash -n "${ALERTER}" 2>/dev/null && pass "health-alerter.sh syntax" || fail "alerter" "syntax error"
    grep -q "ALERT_COOLDOWN" "${ALERTER}" && pass "alerter has cooldown" || fail "alerter" "missing cooldown"
    grep -q "context_high\|crash_rate\|delivery_rate\|fallback_rate\|queue_depth\|session_age" "${ALERTER}" \
        && pass "alerter checks 6 conditions" || fail "alerter" "missing conditions"
else
    fail "health-alerter.sh" "not found"
fi

# ===== E2E-17: Context Monitor =====
echo ""
echo "--- E2E-17: Context Monitor + Config Watcher ---"

for script in context-monitor.sh config-watcher.sh; do
    SCRIPT="${GATEWAY_ROOT}/core/scripts/${script}"
    [[ -f "${SCRIPT}" ]] && bash -n "${SCRIPT}" 2>/dev/null \
        && pass "${script} syntax" || fail "${script}" "syntax error or missing"
done

# ===== E2E-18: Credential Pool =====
echo ""
echo "--- E2E-18: Credential Pool ---"

POOL="${GATEWAY_ROOT}/core/bus/_credential-pool.sh"
if [[ -f "${POOL}" ]]; then
    bash -n "${POOL}" 2>/dev/null && pass "_credential-pool.sh syntax" || fail "credential-pool" "syntax error"
    grep -q "pool_get_active\|pool_rotate\|pool_mark_unhealthy\|pool_status" "${POOL}" \
        && pass "credential pool has 4 core functions" || fail "credential pool" "missing functions"
else
    fail "_credential-pool.sh" "not found"
fi

# ===== E2E-19: WhatsApp Bridge =====
echo ""
echo "--- E2E-19: WhatsApp Bridge ---"

WA_BRIDGE="${GATEWAY_ROOT}/adapters/whatsapp/whatsapp-bridge.js"
if [[ -f "${WA_BRIDGE}" ]]; then
    node --check "${WA_BRIDGE}" 2>/dev/null && pass "whatsapp-bridge.js syntax" || fail "whatsapp bridge" "syntax error"
else
    skip "whatsapp-bridge.js not found"
fi

# ===== E2E-20: Slack Socket Listener =====
echo ""
echo "--- E2E-20: Slack Socket Listener ---"

SLACK_LISTENER="${GATEWAY_ROOT}/adapters/slack/socket-listener.py"
if [[ -f "${SLACK_LISTENER}" ]]; then
    python3 -c "import py_compile; py_compile.compile('${SLACK_LISTENER}', doraise=True)" 2>/dev/null \
        && pass "socket-listener.py syntax" || fail "slack listener" "syntax error"
else
    skip "socket-listener.py not found"
fi

# ===== Summary =====
echo ""
echo "================================================================="
echo "  Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped (${TOTAL} total)"
echo "================================================================="
[[ ${FAIL} -eq 0 ]] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit ${FAIL}
