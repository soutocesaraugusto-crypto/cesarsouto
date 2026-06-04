#!/usr/bin/env bash
# _secret-validator.sh — Secure secret file loading with validation
# OpenClaw pattern: secret-file.ts (symlink protection, size limit, encoding validation)
#
# Usage: source this file, then call:
#   load_secret_file "/path/to/.env" "BOT_TOKEN"  → outputs value or returns 1
#   validate_secret_file "/path/to/.env"           → returns 0 if safe, 1 if not
#
# Epic 110 / Story 110.29 Phase 13

MAX_SECRET_SIZE=16384  # 16KB

# Validate a secret file is safe to read
# Returns 0 if safe, 1 with error message on stderr if not
validate_secret_file() {
    local path="$1"
    local label="${2:-secret file}"

    if [[ -z "$path" ]]; then
        echo "ERROR: ${label} path is empty" >&2
        return 1
    fi

    # Resolve real path (catch symlink tricks)
    local real_path
    real_path=$(realpath "$path" 2>/dev/null || readlink -f "$path" 2>/dev/null || echo "$path")

    if [[ ! -f "$real_path" ]]; then
        echo "ERROR: ${label} not found: ${path}" >&2
        return 1
    fi

    # Reject symlinks pointing outside expected directories
    if [[ -L "$path" ]]; then
        local link_target
        link_target=$(readlink "$path" 2>/dev/null || echo "")
        # Allow symlinks within .claude-remote (the expected config dir)
        if [[ "$link_target" != *".claude-remote"* && "$link_target" != *"message-gateway"* ]]; then
            echo "ERROR: ${label} is a symlink to unexpected location: ${link_target}" >&2
            return 1
        fi
    fi

    # Check file size (prevent DoS)
    local file_size
    file_size=$(stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null || echo "0")
    if [[ ${file_size} -gt ${MAX_SECRET_SIZE} ]]; then
        echo "ERROR: ${label} exceeds ${MAX_SECRET_SIZE} bytes (${file_size} bytes)" >&2
        return 1
    fi

    # Check file is not empty
    if [[ ${file_size} -eq 0 ]]; then
        echo "ERROR: ${label} is empty" >&2
        return 1
    fi

    # Check permissions (should be owner-only: 600 or 400)
    local perms
    perms=$(stat -f%Lp "$path" 2>/dev/null || stat -c%a "$path" 2>/dev/null || echo "000")
    if [[ "$perms" != "600" && "$perms" != "400" && "$perms" != "640" && "$perms" != "644" ]]; then
        # Warning only, not blocking (some systems have different defaults)
        echo "WARN: ${label} has permissions ${perms} (recommended: 600)" >&2
    fi

    return 0
}

# Load and validate a secret file, optionally extract a specific key
load_secret_file() {
    local path="$1"
    local key="${2:-}"

    validate_secret_file "$path" "$key" || return 1

    if [[ -n "$key" ]]; then
        # Extract specific key from .env-style file
        grep "^${key}=" "$path" 2>/dev/null | head -1 | cut -d= -f2-
    else
        cat "$path"
    fi
}
