#!/usr/bin/env bash
# mock.sh — Mock runtime driver for testing
#
# All functions are no-ops or return predictable values.
# Used by test harness to validate gateway behavior without a real CLI.
#
# Set MOCK_* env vars to control behavior:
#   MOCK_BUSY=true      — runtime_detect_busy returns 0 (busy)
#   MOCK_PRINT_RESPONSE — text returned by runtime_print
#   MOCK_LAUNCH_EXIT    — exit code for runtime_launch (default: 0)
#
# Epic 114 / Story 114.13

MOCK_PRINT_RESPONSE="${MOCK_PRINT_RESPONSE:-Mock response from test runtime}"
MOCK_LAUNCH_EXIT="${MOCK_LAUNCH_EXIT:-0}"

runtime_launch() {
    echo "MOCK_LAUNCH: $1" >> "${MOCK_LOG:-/dev/null}"
    return "${MOCK_LAUNCH_EXIT}"
}

runtime_continue() {
    echo "MOCK_CONTINUE: $1" >> "${MOCK_LOG:-/dev/null}"
    return 0
}

runtime_print() {
    echo "${MOCK_PRINT_RESPONSE}"
}

runtime_model_flag() {
    [[ -n "${RUNTIME_MODEL:-}" ]] && echo "--model ${RUNTIME_MODEL}"
}

runtime_system_prompt_flag() {
    echo ""
}

runtime_settings_path() {
    echo ""
}

runtime_detect_busy() {
    [[ "${MOCK_BUSY:-false}" == "true" ]] && return 0
    return 1
}

runtime_detect_idle() {
    [[ "${MOCK_BUSY:-false}" == "true" ]] && return 1
    return 0
}

runtime_builtin_commands() {
    echo "help status"
}

runtime_cron_command() {
    echo "__EXTERNAL_CRON__"
}

runtime_permissions_flag() {
    echo "--mock-permissions"
}

runtime_conversation_dir() {
    echo "/tmp/mock-conversations"
}
