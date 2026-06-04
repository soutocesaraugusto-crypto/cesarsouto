#!/usr/bin/env bash
# classify-turn.sh — Classify message complexity for smart model routing
#
# Determines whether a message should go to a cheap model (quick),
# default model (standard), or premium model (deep).
#
# Usage:
#   classify-turn.sh "<message>"
#   echo "<message>" | classify-turn.sh
#
# Output: "quick", "standard", or "deep"
# Latency: <50ms (regex only, no LLM call)
#
# Epic 114 / Story 114.5

set -uo pipefail

TEXT="${1:-}"
[[ -z "$TEXT" ]] && TEXT=$(cat)
[[ -z "$TEXT" ]] && { echo "standard"; exit 0; }

# Count words
WORD_COUNT=$(echo "$TEXT" | wc -w | tr -d ' ')

# Check for code blocks
HAS_CODE_BLOCKS=false
echo "$TEXT" | grep -q '```' && HAS_CODE_BLOCKS=true

# Check for URLs
HAS_URLS=false
echo "$TEXT" | grep -qE 'https?://' && HAS_URLS=true

# --- QUICK tier ---
# Short, simple messages: greetings, confirmations, status requests
if [[ ${WORD_COUNT} -lt 20 ]] && ! $HAS_CODE_BLOCKS && ! $HAS_URLS; then
    # Pattern match against known quick patterns (case-insensitive)
    QUICK_PATTERNS="^(oi|ola|hi|hello|hey|ok|sim|nao|yes|no|thanks|obrigado|valeu|beleza|blz|status|help|ajuda|got it|entendi|perfeito|show|massa|top|done|feito|pronto|confirmed|bom dia|boa tarde|boa noite|good morning|good night|tudo bem|como vai)$"
    NORMALIZED=$(echo "$TEXT" | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]*$//' | sed 's/^[[:space:]]*//' | sed 's/[!?.,:;]//g')

    if echo "$NORMALIZED" | grep -qiE "$QUICK_PATTERNS"; then
        echo "quick"
        exit 0
    fi

    # Short question without technical content → still quick
    if [[ ${WORD_COUNT} -lt 8 ]] && ! echo "$TEXT" | grep -qiE 'implement|create|build|design|architect|refactor|migrate|deploy|debug|fix|analyze|review'; then
        echo "quick"
        exit 0
    fi
fi

# --- DEEP tier ---
# Complex architecture, multi-file refactoring, research tasks
DEEP_PATTERNS="(architect|refactor|redesign|migration|security.audit|system.design|infrastructure|performance.optimization|create.*architecture|full.stack|database.schema|api.design)"
if echo "$TEXT" | grep -qiE "$DEEP_PATTERNS"; then
    echo "deep"
    exit 0
fi

# Very long messages → deep
if [[ ${WORD_COUNT} -gt 500 ]]; then
    echo "deep"
    exit 0
fi

# Multiple code blocks → deep (complex code task)
CODE_BLOCK_COUNT=$(echo "$TEXT" | grep -c '```' || true)
if [[ ${CODE_BLOCK_COUNT} -gt 4 ]]; then
    echo "deep"
    exit 0
fi

# --- STANDARD tier (default) ---
echo "standard"
