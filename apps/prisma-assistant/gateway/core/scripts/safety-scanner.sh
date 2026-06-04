#!/usr/bin/env bash
# safety-scanner.sh — Pre-filter for dangerous commands
#
# Scans user messages for dangerous patterns BEFORE they reach the runtime.
# Returns: SAFE (exit 0), CAUTION (exit 1), DANGEROUS (exit 2)
#
# ~30 regex patterns in 6 categories, <10ms latency
# Implementation: ~30 regex patterns in 6 categories, <10ms latency
#
# Usage:
#   echo "rm -rf /" | safety-scanner.sh
#   RESULT=$(echo "$TEXT" | safety-scanner.sh)
#   # Exit codes: 0=SAFE, 1=CAUTION, 2=DANGEROUS
#
# Epic 114 / Story 114.17 Phase 1

set -uo pipefail

INPUT=$(cat)

# Quick exit for empty input
[[ -z "${INPUT}" ]] && echo "SAFE" && exit 0

# --- Category 1: Destructive (exit 2) ---
DESTRUCTIVE=(
    'rm\s+(-[rRf]+\s+)*/([^t]|$)'      # rm -rf / or rm -rf /anything (except /tmp)
    'rm\s+(-[rRf]+\s+)*~/'             # rm -rf ~/
    'rm\s+-[rRf]*\s+\.'                # rm -rf .  (current dir)
    'mkfs\.'                            # mkfs.ext4 etc
    'dd\s+if=.*of=/dev/'               # dd to block device
    'shred\s+'                          # shred files
)

# --- Category 2: Privilege Escalation (exit 2) ---
PRIVILEGE=(
    'sudo\s+'                           # sudo — broad match, safe variants excluded below
    'chmod\s+[ugo]*\+s'                # SUID bit
    '=\s*NOPASSWD'                      # sudoers NOPASSWD (require = prefix to avoid false pos in questions)
    'pkexec\s+'                         # polkit exec
)
# Post-filter: sudo -v and sudo --validate are safe (QA fix BUG-3)
PRIVILEGE_SAFE_PATTERNS='sudo\s+(-v|--validate)\b'

# --- Category 3: Persistence (exit 1: CAUTION) ---
PERSISTENCE=(
    'crontab\s+-[er]'                   # crontab edit/remove
    'authorized_keys'                   # SSH key injection
    'systemctl\s+(enable|mask)'         # systemd persistence
    'launchctl\s+load'                  # launchd load — crm- exclusion handled in post-filter
    '/etc/sudoers'                      # sudoers modification
)

# --- Category 4: Exfiltration (exit 2) ---
EXFILTRATION=(
    'curl.*\$\{?(TOKEN|SECRET|KEY|API|PASSWORD|CREDENTIAL)' # exfil secrets via curl
    'bash\s+-i\s+>.*\/dev\/tcp'         # reverse shell
    'nc\s+(-[a-z]+\s+)*-e'             # nc reverse shell
    '/etc/shadow'                       # password file read
    '/etc/passwd.*>>?\s'                # passwd write
)

# --- Category 5: Database (exit 1: CAUTION) ---
DATABASE=(
    'DROP\s+(TABLE|DATABASE)'           # drop table/db
    'DELETE\s+FROM\s+\w+\s*;'          # DELETE without WHERE
    'TRUNCATE\s+'                       # truncate table
)

# --- Category 6: Self-harm (exit 2) ---
SELFHARM=(
    'pkill.*(claude|codex|agent-wrapper|fast-checker)'  # kill our processes
    'killall.*(claude|codex|agent-wrapper)'             # killall our processes
    'kill\s+-9\s+-1'                    # kill all user processes
    'tmux\s+kill-session.*crm-'        # kill agent session directly
)

# --- Scan ---
VERDICT="SAFE"
PATTERN_KEY=""
DESCRIPTION=""

scan_patterns() {
    local category="$1" severity="$2"
    shift 2
    local patterns=("$@")
    for pattern in "${patterns[@]}"; do
        if echo "${INPUT}" | grep -qEi "${pattern}" 2>/dev/null; then
            PATTERN_KEY="${pattern}"
            DESCRIPTION="${category}"
            if [[ "${severity}" == "DANGEROUS" || ("${severity}" == "CAUTION" && "${VERDICT}" == "SAFE") ]]; then
                VERDICT="${severity}"
            fi
            return 0
        fi
    done
    return 1
}

# Scan in priority order (DANGEROUS first)
scan_patterns "destructive"   "DANGEROUS" "${DESTRUCTIVE[@]}" || true
scan_patterns "privilege"     "DANGEROUS" "${PRIVILEGE[@]}" || true
scan_patterns "exfiltration"  "DANGEROUS" "${EXFILTRATION[@]}" || true
scan_patterns "self-harm"     "DANGEROUS" "${SELFHARM[@]}" || true
scan_patterns "persistence"   "CAUTION"   "${PERSISTENCE[@]}" || true
scan_patterns "database"      "CAUTION"   "${DATABASE[@]}" || true

# Post-filter: exclude known-safe variants (QA fix BUG-3)
# sudo -v / sudo --validate are safe credential checks
if [[ "${DESCRIPTION}" == "privilege" && -n "${PRIVILEGE_SAFE_PATTERNS:-}" ]]; then
    if echo "${INPUT}" | grep -qEi "${PRIVILEGE_SAFE_PATTERNS}" 2>/dev/null; then
        # The ONLY sudo in the input is a safe variant
        SAFE_SUDO_COUNT=$(echo "${INPUT}" | grep -oEi 'sudo\s+' 2>/dev/null | wc -l | tr -d ' ')
        SAFE_VARIANT_COUNT=$(echo "${INPUT}" | grep -oEi "${PRIVILEGE_SAFE_PATTERNS}" 2>/dev/null | wc -l | tr -d ' ')
        if [[ "${SAFE_SUDO_COUNT}" -le "${SAFE_VARIANT_COUNT}" ]]; then
            VERDICT="SAFE"
            PATTERN_KEY=""
            DESCRIPTION=""
        fi
    fi
fi
# launchctl load crm- is our own agent management — safe
if [[ "${DESCRIPTION}" == "persistence" && "${PATTERN_KEY}" == *"launchctl"* ]]; then
    if echo "${INPUT}" | grep -qEi 'launchctl\s+load.*crm-' 2>/dev/null; then
        VERDICT="SAFE"
        PATTERN_KEY=""
        DESCRIPTION=""
    fi
fi
# systemctl --user for crm- services is our own agent management — safe (Story 114.24)
if [[ "${DESCRIPTION}" == "persistence" && "${PATTERN_KEY}" == *"systemctl"* ]]; then
    if echo "${INPUT}" | grep -qEi 'systemctl\s+--user\s+(enable|start|stop|restart|daemon-reload|disable|is-active|status)\s*(crm-|$)' 2>/dev/null; then
        VERDICT="SAFE"
        PATTERN_KEY=""
        DESCRIPTION=""
    fi
fi

# Output
case "${VERDICT}" in
    SAFE)
        echo "SAFE"
        exit 0
        ;;
    CAUTION)
        echo "CAUTION:${DESCRIPTION}:${PATTERN_KEY}"
        exit 1
        ;;
    DANGEROUS)
        echo "DANGEROUS:${DESCRIPTION}:${PATTERN_KEY}"
        exit 2
        ;;
esac
