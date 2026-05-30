#!/usr/bin/env bash
# =============================================================================
# aiox-ads Bootstrap Script
# =============================================================================
# Validates environment, copies required env vars, and health-checks MCPs.
# Safe to run multiple times (idempotent).
#
# Usage: bash squads/aiox-ads/scripts/bootstrap.sh
# Or:    ./squads/aiox-ads/scripts/bootstrap.sh  (after chmod +x)
#
# Story: SAIOX-ADS-V5-1.4
# Version: 1.0.0
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors & Symbols
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

OK="${GREEN}[OK]${NC}"
FAIL="${RED}[FAIL]${NC}"
WARN="${YELLOW}[WARN]${NC}"
INFO="${CYAN}[INFO]${NC}"

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass()  { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "  ${OK}   $1"; }
fail()  { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "  ${FAIL} $1"; }
warn()  { WARN_COUNT=$((WARN_COUNT + 1)); echo -e "  ${WARN} $1"; }
info()  { echo -e "  ${INFO} $1"; }

separator() {
  echo ""
  echo -e "${BOLD}--- $1 ---${NC}"
  echo ""
}

# ---------------------------------------------------------------------------
# Resolve project root (walk up until we find .env.example or hit /)
# ---------------------------------------------------------------------------
find_project_root() {
  local dir
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.env.example" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  # Fallback: try cwd
  if [[ -f ".env.example" ]]; then
    pwd
    return 0
  fi
  return 1
}

PROJECT_ROOT="$(find_project_root)" || {
  echo -e "${FAIL} Could not find project root (.env.example not found)."
  echo "  Run this script from the project root or from squads/aiox-ads/scripts/"
  exit 1
}

echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  aiox-ads Bootstrap v1.0.0${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
echo -e "  Project root: ${CYAN}${PROJECT_ROOT}${NC}"

# =========================================================================
# CHECK 1: Node.js >= 18
# =========================================================================
separator "Check 1/5: Node.js"

if command -v node &>/dev/null; then
  NODE_VERSION_RAW="$(node --version)"
  NODE_MAJOR="$(echo "$NODE_VERSION_RAW" | sed 's/v//' | cut -d. -f1)"
  if [[ "$NODE_MAJOR" -ge 18 ]]; then
    pass "Node.js ${NODE_VERSION_RAW} (>= 18 required)"
  else
    fail "Node.js ${NODE_VERSION_RAW} is too old. Version >= 18 is required."
    echo "       Fix: Install Node.js 18+ via https://nodejs.org or nvm:"
    echo "            nvm install 18 && nvm use 18"
  fi
else
  fail "Node.js not found."
  echo "       Fix: Install Node.js 18+ via https://nodejs.org or nvm:"
  echo "            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
  echo "            nvm install 18"
fi

# =========================================================================
# CHECK 2: Git installed
# =========================================================================
separator "Check 2/5: Git"

if command -v git &>/dev/null; then
  GIT_VERSION="$(git --version | awk '{print $3}')"
  pass "Git ${GIT_VERSION} installed"
else
  fail "Git not found."
  echo "       Fix: Install Git via https://git-scm.com/downloads"
  echo "            macOS: xcode-select --install"
  echo "            Ubuntu: sudo apt install git"
fi

# =========================================================================
# CHECK 3: .env AIOX-ADS section
# =========================================================================
separator "Check 3/5: .env AIOX-ADS Variables"

ENV_FILE="${PROJECT_ROOT}/.env"
ENV_EXAMPLE="${PROJECT_ROOT}/.env.example"

# The vars we need from Section 10 (AIOX-ADS)
AIOX_ADS_VARS=(
  "META_ADS_ACCESS_TOKEN"
  "META_ADS_ACCOUNT_ID"
  "META_ADS_PIXEL_ID"
  "META_ADS_PAGE_ID"
  "GOOGLE_ADS_DEVELOPER_TOKEN"
  "GOOGLE_ADS_CLIENT_ID"
  "GOOGLE_ADS_CLIENT_SECRET"
  "GOOGLE_ADS_REFRESH_TOKEN"
  "GOOGLE_ADS_CUSTOMER_ID"
  "SLACK_WEBHOOK_URL"
  "SLACK_CHANNEL_ALERTS"
)

# Required vars (must not be empty for minimum viable setup)
REQUIRED_VARS=(
  "META_ADS_ACCESS_TOKEN"
)

if [[ ! -f "$ENV_FILE" ]]; then
  warn ".env file does not exist. Creating from AIOX-ADS section of .env.example..."
  # Extract Section 10 from .env.example and create .env with it
  if [[ -f "$ENV_EXAMPLE" ]]; then
    # Extract lines between "# 10. AIOX-ADS" and the next section header "# ===...==="
    SECTION_FOUND=false
    SECTION_CONTENT=""
    while IFS= read -r line; do
      if [[ "$line" == *"10. AIOX-ADS"* ]]; then
        SECTION_FOUND=true
        SECTION_CONTENT+="$line"$'\n'
        continue
      fi
      if $SECTION_FOUND; then
        # Stop at the next major section (starts with # === and contains a number followed by a dot)
        if [[ "$line" =~ ^#\ =+$ ]] && [[ -n "$SECTION_CONTENT" ]] && echo "$SECTION_CONTENT" | tail -1 | grep -q "^$"; then
          # Check if the NEXT line is a new section number
          break
        fi
        # Also break if we hit a new numbered section header like "# 11."
        if [[ "$line" =~ ^#\ [0-9]+\. ]] && [[ "$line" != *"10."* ]]; then
          break
        fi
        SECTION_CONTENT+="$line"$'\n'
      fi
    done < "$ENV_EXAMPLE"

    if $SECTION_FOUND && [[ -n "$SECTION_CONTENT" ]]; then
      {
        echo "# Auto-generated by aiox-ads bootstrap.sh"
        echo "# Full template: .env.example"
        echo ""
        echo "$SECTION_CONTENT"
      } > "$ENV_FILE"
      info "Created .env with AIOX-ADS section (${#AIOX_ADS_VARS[@]} variables)"
    else
      fail "Could not extract AIOX-ADS section from .env.example"
    fi
  else
    fail ".env.example not found at ${ENV_EXAMPLE}"
    echo "       Fix: Run Story 1.1 first, or copy .env.example from the repository"
  fi
fi

# Now check that each AIOX-ADS var exists in .env
if [[ -f "$ENV_FILE" ]]; then
  VARS_ADDED=0
  for var in "${AIOX_ADS_VARS[@]}"; do
    if grep -q "^${var}=" "$ENV_FILE" 2>/dev/null; then
      : # Variable already present, no action needed
    else
      # Append from .env.example if possible
      if [[ -f "$ENV_EXAMPLE" ]]; then
        EXAMPLE_LINE="$(grep "^${var}=" "$ENV_EXAMPLE" 2>/dev/null || true)"
        if [[ -n "$EXAMPLE_LINE" ]]; then
          echo "$EXAMPLE_LINE" >> "$ENV_FILE"
          VARS_ADDED=$((VARS_ADDED + 1))
        fi
      fi
    fi
  done

  if [[ $VARS_ADDED -gt 0 ]]; then
    info "Appended ${VARS_ADDED} missing AIOX-ADS variable(s) to .env"
  fi

  # Report status of each var
  for var in "${AIOX_ADS_VARS[@]}"; do
    CURRENT_VALUE="$(grep "^${var}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || true)"
    if [[ -z "$CURRENT_VALUE" ]] || [[ "$CURRENT_VALUE" == "your-"* ]] || [[ "$CURRENT_VALUE" == "<"*">" ]] || [[ "$CURRENT_VALUE" == "PLACEHOLDER"* ]]; then
      # Check if it's a required var
      IS_REQUIRED=false
      for req in "${REQUIRED_VARS[@]}"; do
        if [[ "$var" == "$req" ]]; then
          IS_REQUIRED=true
          break
        fi
      done
      if $IS_REQUIRED; then
        fail "${var} is empty or placeholder"
      else
        warn "${var} is empty (optional, fill when needed)"
      fi
    else
      pass "${var} is configured"
    fi
  done
else
  fail ".env file still missing after creation attempt"
fi

# =========================================================================
# CHECK 4: META_ADS_ACCESS_TOKEN validation
# =========================================================================
separator "Check 4/5: Meta Ads Token Validation"

if [[ -f "$ENV_FILE" ]]; then
  META_TOKEN="$(grep "^META_ADS_ACCESS_TOKEN=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || true)"

  if [[ -z "$META_TOKEN" ]]; then
    fail "META_ADS_ACCESS_TOKEN is empty"
    echo "       Fix: Get a long-lived token from https://pipeboard.co/settings/tokens"
    echo "       Guide: squads/aiox-ads/mcp/setup-guide.md (Phase 2A)"
  elif [[ "$META_TOKEN" == "your-"* ]] || [[ "$META_TOKEN" == "<"*">" ]] || [[ "$META_TOKEN" == "PLACEHOLDER"* ]]; then
    fail "META_ADS_ACCESS_TOKEN contains a placeholder value"
    echo "       Fix: Replace the placeholder with your actual token"
    echo "       Guide: squads/aiox-ads/mcp/setup-guide.md (Phase 2A)"
  elif [[ ${#META_TOKEN} -lt 20 ]]; then
    fail "META_ADS_ACCESS_TOKEN looks too short (${#META_TOKEN} chars)"
    echo "       Fix: Meta tokens are typically 150-250 characters long"
    echo "       Guide: squads/aiox-ads/mcp/setup-guide.md (Phase 2A)"
  elif [[ "$META_TOKEN" == EAA* ]]; then
    pass "META_ADS_ACCESS_TOKEN is set (${#META_TOKEN} chars, starts with EAA -- looks like a valid Meta token)"
  else
    warn "META_ADS_ACCESS_TOKEN is set (${#META_TOKEN} chars) but does not start with 'EAA'"
    echo "       Note: Most Meta access tokens start with 'EAA'. Yours may still be valid."
    echo "       If you experience auth errors, regenerate at: https://pipeboard.co/settings/tokens"
  fi
else
  fail "Cannot check META_ADS_ACCESS_TOKEN -- .env file missing"
fi

# =========================================================================
# CHECK 5: MCP Health Check (npx availability)
# =========================================================================
separator "Check 5/5: MCP Server Availability"

if command -v npx &>/dev/null; then
  pass "npx is available ($(npx --version 2>/dev/null || echo 'version unknown'))"
else
  fail "npx not found. Required to run MCP servers."
  echo "       Fix: npx ships with npm (Node.js). Install Node.js 18+."
fi

# Check if MCP packages are resolvable (without actually starting them)
# We use npm view to check if the packages exist and the pinned versions are valid
MCP_SERVERS=(
  "@pipeboard/meta-ads-mcp:1.0.59"
  "@adspirer/ads-mcp:0.3.2"
)

for server_spec in "${MCP_SERVERS[@]}"; do
  PACKAGE="${server_spec%%:*}"
  VERSION="${server_spec##*:}"

  if command -v npx &>/dev/null; then
    # Check if the package exists at the pinned version via npm view
    if npm view "${PACKAGE}@${VERSION}" version &>/dev/null 2>&1; then
      pass "MCP ${PACKAGE}@${VERSION} exists in npm registry"
    else
      warn "MCP ${PACKAGE}@${VERSION} could not be verified in npm registry"
      echo "       This may be a private package or network issue."
      echo "       The MCP will be downloaded on first use by Claude Code."
    fi
  fi
done

# Check .claude/settings.local.json exists (needed for MCP config)
SETTINGS_LOCAL="${PROJECT_ROOT}/.claude/settings.local.json"
SETTINGS_EXAMPLE="${PROJECT_ROOT}/.claude/settings.local.example.json"

if [[ -f "$SETTINGS_LOCAL" ]]; then
  pass ".claude/settings.local.json exists"
  # Quick sanity: does it mention meta-ads-mcp?
  if grep -q "meta-ads-mcp" "$SETTINGS_LOCAL" 2>/dev/null; then
    pass "settings.local.json references meta-ads-mcp"
  else
    warn "settings.local.json does not reference meta-ads-mcp"
    echo "       Fix: Copy MCP config from .claude/settings.local.example.json"
  fi
else
  warn ".claude/settings.local.json does not exist"
  if [[ -f "$SETTINGS_EXAMPLE" ]]; then
    echo "       Fix: cp .claude/settings.local.example.json .claude/settings.local.json"
    echo "            Then fill in your tokens."
  else
    echo "       Fix: Create .claude/settings.local.json with MCP server definitions"
    echo "       Guide: squads/aiox-ads/mcp/setup-guide.md"
  fi
fi

# =========================================================================
# Summary
# =========================================================================
echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  Bootstrap Summary${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
echo -e "  ${GREEN}PASS:${NC} ${PASS_COUNT}"
echo -e "  ${RED}FAIL:${NC} ${FAIL_COUNT}"
echo -e "  ${YELLOW}WARN:${NC} ${WARN_COUNT}"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
  echo -e "  ${GREEN}${BOLD}All critical checks passed.${NC} The aiox-ads squad is ready."
  echo ""
  echo "  Next steps:"
  echo "    1. Restart Claude Code to load MCP servers"
  echo "    2. Activate @ad-midas to start working with ads"
  echo ""
  exit 0
elif [[ $FAIL_COUNT -le 2 ]]; then
  echo -e "  ${YELLOW}${BOLD}Some checks failed.${NC} Fix the FAIL items above before using aiox-ads."
  echo ""
  echo "  Detailed setup guide: squads/aiox-ads/mcp/setup-guide.md"
  echo "  Re-run this script after fixing: ./squads/aiox-ads/scripts/bootstrap.sh"
  echo ""
  exit 1
else
  echo -e "  ${RED}${BOLD}Multiple failures detected.${NC} Environment needs setup."
  echo ""
  echo "  Start here:"
  echo "    1. Install Node.js 18+: https://nodejs.org"
  echo "    2. Install Git: https://git-scm.com"
  echo "    3. Copy .env.example to .env and fill in tokens"
  echo "    4. Follow: squads/aiox-ads/mcp/setup-guide.md"
  echo ""
  exit 1
fi
