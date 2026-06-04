#!/usr/bin/env bash
# register-telegram-commands.sh - Register skills/commands as Telegram bot / autocomplete
#
# Scans directories for Claude Code skills and commands, parses their YAML
# frontmatter, and registers user-invocable ones via Telegram's setMyCommands API.
#
# Strategy: Only registers "chief" / entry-point skills (no "--" in name).
# Sub-agent skills (e.g. brand--aaker, domain-decoder--eric-evans) are routed
# through their chief and excluded from Telegram autocomplete to stay within
# the 100-command limit. This keeps the menu clean and discoverable.
#
# Usage: register-telegram-commands.sh <bot_token> <scan_dir> [<scan_dir2> ...]
#
# Scanned locations (per directory):
#   .claude/commands/*.md     - Claude Code slash commands
#   .claude/skills/*/SKILL.md - Claude Code skills
#   skills/*/SKILL.md         - Legacy/custom skills
#
# Frontmatter fields used:
#   name              - becomes the /command name (required or derived from filename)
#   description       - shown in Telegram autocomplete (max 256 chars)
#   user-invocable    - when "false", skill is excluded from registration
#
# Filtering:
#   - Skills with "--" in their name are sub-agents → excluded
#   - Telegram limit: 100 commands max via setMyCommands

set -euo pipefail

BOT_TOKEN="$1"
shift
SCAN_DIRS=("$@")

if [[ -z "${BOT_TOKEN}" ]]; then
    echo "ERROR: BOT_TOKEN required" >&2
    exit 1
fi

# --- Frontmatter parser ---
# Reads YAML frontmatter from a markdown file. Handles single-line values,
# quoted strings, and YAML multi-line indicators (>-, >, |-, |).
# Output: name|description|user-invocable (pipe-delimited)
parse_frontmatter() {
    local file="$1"
    local in_frontmatter=false
    local name="" description="" user_invocable="true"
    local reading_multiline="" multiline_value=""

    while IFS= read -r line; do
        # Detect frontmatter boundaries
        if [[ "${line}" == "---" ]]; then
            if [[ "${in_frontmatter}" == "true" ]]; then
                break
            fi
            in_frontmatter=true
            continue
        fi
        [[ "${in_frontmatter}" == "true" ]] || continue

        # Multi-line continuation: indented lines belong to the previous field
        if [[ -n "${reading_multiline}" && "${line}" =~ ^[[:space:]] ]]; then
            local trimmed
            trimmed=$(echo "${line}" | sed 's/^[[:space:]]*//')
            multiline_value="${multiline_value} ${trimmed}"
            continue
        elif [[ -n "${reading_multiline}" ]]; then
            # Assign without eval to avoid injection risk
            case "${reading_multiline}" in
                description) description="${multiline_value}" ;;
                name) name="${multiline_value}" ;;
            esac
            reading_multiline=""
            multiline_value=""
        fi

        # Parse known fields
        case "${line}" in
            name:*)
                name=$(echo "${line#name:}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')
                ;;
            description:*)
                local val
                val=$(echo "${line#description:}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')
                if [[ "${val}" =~ ^[\>\|]-?$ ]]; then
                    reading_multiline="description"
                    multiline_value=""
                else
                    description="${val}"
                fi
                ;;
            user-invocable:*)
                user_invocable=$(echo "${line#user-invocable:}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                ;;
        esac
    done < "$file"

    # Flush remaining multi-line value
    if [[ -n "${reading_multiline}" ]]; then
        # Assign without eval to avoid injection risk
        case "${reading_multiline}" in
            description) description="${multiline_value}" ;;
            name) name="${multiline_value}" ;;
        esac
    fi

    description=$(echo "${description}" | sed 's/^[[:space:]]*//')
    echo "${name}|${description}|${user_invocable}"
}

# --- Collect skill files from all scan directories ---
collect_skill_files() {
    local dir="$1"
    local paths=(
        "${dir}/.claude/commands/*.md"
        "${dir}/.claude/skills/*/SKILL.md"
        "${dir}/skills/*/SKILL.md"
    )
    for pattern in "${paths[@]}"; do
        for file in ${pattern}; do
            [[ -f "${file}" ]] && echo "${file}"
        done
    done
}

# --- Derive command name from file path ---
# SKILL.md -> use parent directory name; *.md -> use filename without extension
derive_name() {
    local file="$1"
    if [[ "$(basename "${file}")" == "SKILL.md" ]]; then
        basename "$(dirname "${file}")"
    else
        basename "${file}" .md
    fi
}

# --- Sanitize name for Telegram ---
# Telegram commands: lowercase, a-z 0-9 underscore only, max 32 chars
sanitize_command() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr '-' '_' | sed 's/[^a-z0-9_]//g' | cut -c1-32
}

# --- Built-in session management commands (registered first, appear at top) ---
# These map to Claude Code CLI commands or CRM-specific actions.
# Inspired by Hermes Agent's session commands (/new, /retry, /compress, etc.)
BUILTIN_COMMANDS='[
  {"command":"new",      "description":"Start a fresh session (clears context)"},
  {"command":"compact",  "description":"Compress conversation context"},
  {"command":"status",   "description":"Show agent status and session info"},
  {"command":"cost",     "description":"Show token usage and cost for this session"},
  {"command":"restart",  "description":"Soft restart (preserves conversation history)"},
  {"command":"hardreset","description":"Hard restart (fresh session, loses history)"},
  {"command":"logs",     "description":"Show recent agent activity logs"},
  {"command":"help",     "description":"Show available commands and usage"},
  {"command":"fast",     "description":"Switch to fast output mode"},
  {"command":"slow",     "description":"Switch to standard output mode"},
  {"command":"review",   "description":"Review recent changes"},
  {"command":"update",   "description":"Re-sync Telegram commands with available skills"}
]'

# --- Build commands JSON array (builtins first, then skills) ---
COMMANDS_JSON="${BUILTIN_COMMANDS}"
SEEN=""
SKIPPED_SUB=0

# Mark builtins as seen to prevent skill duplicates
while IFS= read -r bcmd; do
    SEEN="${SEEN}${bcmd}"$'\n'
done < <(echo "${BUILTIN_COMMANDS}" | jq -r '.[].command')

for dir in "${SCAN_DIRS[@]}"; do
    [[ -d "${dir}" ]] || continue

    while IFS= read -r file; do
        IFS='|' read -r name desc invocable <<< "$(parse_frontmatter "${file}")"

        [[ -z "${name}" ]] && name=$(derive_name "${file}")
        [[ -z "${desc}" ]] && desc="Skill: ${name}"
        [[ "${invocable}" == "false" ]] && continue

        # Skip sub-agent skills (contain "--") — they are routed via their chief
        if [[ "${name}" == *"--"* ]]; then
            SKIPPED_SUB=$((SKIPPED_SUB + 1))
            continue
        fi

        cmd=$(sanitize_command "${name}")
        [[ -z "${cmd}" ]] && continue

        # Deduplicate (first occurrence wins)
        echo "${SEEN}" | grep -q "^${cmd}$" && continue
        SEEN="${SEEN}${cmd}"$'\n'

        # jq handles all JSON escaping; truncate description to 50 chars.
        # Telegram has an undocumented total payload size limit (~11KB) for
        # setMyCommands. With 90+ commands (builtins + skills), keep short.
        COMMANDS_JSON=$(echo "${COMMANDS_JSON}" | jq \
            --arg cmd "${cmd}" \
            --arg desc "$(echo "${desc}" | cut -c1-50)" \
            '. + [{"command": $cmd, "description": $desc}]')
    done <<< "$(collect_skill_files "${dir}")"
done

# --- Override: Register ONLY gateway commands + curated skills ---
# Claude Code internal commands (compact, cost, fast, etc.) are NOT useful in Telegram.
# Skills work even without autocomplete — the fast-checker injects any /command.
# Keep the Telegram menu clean: only commands users need to discover.
GATEWAY_COMMANDS='[
  {"command": "help", "description": "Show all available commands"},
  {"command": "model", "description": "Show or switch model (haiku/sonnet/opus)"},
  {"command": "status", "description": "Show agent status"},
  {"command": "new", "description": "Clear conversation (keep session)"},
  {"command": "restart", "description": "Soft restart (preserve history)"},
  {"command": "hardreset", "description": "Fresh session (lose context)"},
  {"command": "logs", "description": "Show recent activity logs"},
  {"command": "update", "description": "Re-sync Telegram bot commands"}
]'
COMMANDS_JSON="${GATEWAY_COMMANDS}"

# --- Register with Telegram ---
COUNT=$(echo "${COMMANDS_JSON}" | jq 'length')

if [[ "${COUNT}" -eq 0 ]]; then
    echo "No commands found to register"
    exit 0
fi

PAYLOAD=$(jq -n --argjson cmds "${COMMANDS_JSON}" '{"commands": $cmds}')
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setMyCommands" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}")

if echo "${RESPONSE}" | jq -e '.ok == true' > /dev/null 2>&1; then
    echo "Registered ${COUNT} Telegram commands (skipped ${SKIPPED_SUB} sub-agent skills)"
else
    echo "WARNING: Failed to register Telegram commands: ${RESPONSE}" >&2
fi
