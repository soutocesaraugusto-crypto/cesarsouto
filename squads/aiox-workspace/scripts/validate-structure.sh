#!/bin/bash
# Workspace Structure Validation Script (BU-Oriented)
# COO runs this before activating governance
#
# Usage: ./squads/aiox-workspace/scripts/validate-structure.sh
# Exit codes: 0 = pass, 1 = fail
#
# Author: @architect (The Architect), @coo
# Updated: 2026-02-24

set -u

WORKSPACE_ROOT="workspace"
BUSINESSES_ROOT="$WORKSPACE_ROOT/businesses"
PASS=0
FAIL=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Workspace Structure Validation (BU-Oriented)"
echo "================================================"
echo ""

run_check() {
    local description="$1"
    shift

    if "$@"; then
        echo -e "${GREEN}✅${NC} $description"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}❌${NC} $description"
        FAIL=$((FAIL + 1))
    fi
}

count_lines() {
    wc -l | tr -d ' '
}

collect_businesses() {
    find "$BUSINESSES_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort
}

# 1. Foundation checks
echo "1. Foundation"
echo "---"
run_check "workspace/ exists" test -d "$WORKSPACE_ROOT"
run_check "businesses/ exists" test -d "$BUSINESSES_ROOT"
run_check "workspace.yaml exists" test -f "$WORKSPACE_ROOT/workspace.yaml"
business_count=$(collect_businesses | count_lines)
run_check "At least one business exists" test "$business_count" -gt 0
echo ""

# 2. BU-oriented structure checks
echo "2. BU Structure (workspace/businesses/*)"
echo "---"
if [ "$business_count" -eq 0 ]; then
    echo -e "${YELLOW}⚠️${NC} No business directories found, skipping BU checks"
else
    while IFS= read -r business_path; do
        [ -z "$business_path" ] && continue
        business_slug="$(basename "$business_path")"
        echo "Business: $business_slug"

        # Required BU folders
        run_check "  $business_slug/company exists" test -d "$business_path/company"
        run_check "  $business_slug/operations exists" test -d "$business_path/operations"
        run_check "  $business_slug/tech exists" test -d "$business_path/tech"
        run_check "  $business_slug/ai exists" test -d "$business_path/ai"
        run_check "  $business_slug/products exists" test -d "$business_path/products"

        # Required profile files
        run_check "  $business_slug/company/company-profile.yaml exists" test -f "$business_path/company/company-profile.yaml"
        run_check "  $business_slug/company/icp.yaml exists" test -f "$business_path/company/icp.yaml"
        run_check "  $business_slug/brand/brandbook.yaml exists" test -f "$business_path/brand/brandbook.yaml"
        run_check "  $business_slug/operations/team-structure.yaml exists" test -f "$business_path/operations/team-structure.yaml"
        run_check "  $business_slug/operations/pricing-strategy.yaml exists" test -f "$business_path/operations/pricing-strategy.yaml"

        if test -f "$business_path/tech/strategy.yaml"; then
            echo -e "${GREEN}✅${NC}   $business_slug/tech/strategy.yaml exists"
            PASS=$((PASS + 1))
        else
            echo -e "${YELLOW}⚠️${NC}   $business_slug/tech/strategy.yaml missing (recommended)"
        fi

        if test -f "$business_path/ai/strategy.yaml"; then
            echo -e "${GREEN}✅${NC}   $business_slug/ai/strategy.yaml exists"
            PASS=$((PASS + 1))
        else
            echo -e "${YELLOW}⚠️${NC}   $business_slug/ai/strategy.yaml missing (recommended)"
        fi
        echo ""
    done < <(collect_businesses)
fi

# 3. YAML syntax validation
echo "3. YAML Syntax"
echo "---"
if command -v yq >/dev/null 2>&1; then
    invalid_yaml_tmp="$(mktemp)"
    yaml_files_checked=0

    while IFS= read -r -d '' yaml_file; do
        yaml_files_checked=$((yaml_files_checked + 1))
        if ! yq e "." "$yaml_file" >/dev/null 2>&1; then
            echo "$yaml_file" >> "$invalid_yaml_tmp"
        fi
    done < <(find "$WORKSPACE_ROOT" -type f \( -name "*.yaml" -o -name "*.yml" \) -print0)

    invalid_yaml_count=$(cat "$invalid_yaml_tmp" | count_lines)

    if [ "$yaml_files_checked" -eq 0 ]; then
        echo -e "${YELLOW}⚠️${NC} No YAML files found under $WORKSPACE_ROOT"
    fi

    run_check "All YAML files parse correctly" test "$invalid_yaml_count" -eq 0

    if [ "$invalid_yaml_count" -gt 0 ]; then
        echo -e "${RED}Invalid YAML files (first 20):${NC}"
        sed -n '1,20p' "$invalid_yaml_tmp"
    fi

    rm -f "$invalid_yaml_tmp"
else
    echo -e "${YELLOW}⚠️${NC} yq not found - YAML syntax check skipped"
    run_check "yq available for YAML validation" false
fi
echo ""

# 4. Forbidden patterns
echo "4. Forbidden Patterns"
echo "---"
forbidden_count=$(
    find "$WORKSPACE_ROOT" -type f \
        \( -name "*_backup" -o -name "*_old" -o -name "*_v2" -o -name "*_v3" -o -name "test_*" -o -name "temp_*" -o -name "TODO_*" -o -name "*~" \) \
        2>/dev/null | count_lines
)
run_check "No forbidden file patterns found" test "$forbidden_count" -eq 0
echo ""

# 5. Orphaned files in workspace root
echo "5. Orphaned Files (workspace root)"
echo "---"
allowed_root_files=(
    "config.yaml"
    "config.md"
    "structure.yaml"
    "relationships.yaml"
    "synapse-integration.yaml"
    "index.json"
    "user.md"
    "PRODUCT_OFFERBOOK_SYSTEM.md"
)

orphaned=0
while IFS= read -r file_path; do
    file_name="$(basename "$file_path")"
    allowed=false
    for allowed_file in "${allowed_root_files[@]}"; do
        if [ "$file_name" = "$allowed_file" ]; then
            allowed=true
            break
        fi
    done
    if [ "$allowed" = false ]; then
        orphaned=$((orphaned + 1))
        echo -e "${YELLOW}⚠️${NC} Potential orphaned file: $file_name"
    fi
done < <(find "$WORKSPACE_ROOT" -maxdepth 1 -type f ! -name ".*" 2>/dev/null)

run_check "No orphaned files in workspace root" test "$orphaned" -eq 0
echo ""

# 6. Product naming checks (root + businesses)
echo "6. Product Naming (snake_case)"
echo "---"
product_count=0
bad_products=0

while IFS= read -r product_path; do
    [ -z "$product_path" ] && continue
    product_name="$(basename "$product_path")"
    product_count=$((product_count + 1))

    if [[ ! "$product_name" =~ ^[a-z0-9]+(_[a-z0-9]+)*$ ]]; then
        echo -e "${RED}❌${NC} Product not snake_case: $product_name ($product_path)"
        bad_products=$((bad_products + 1))
    fi
done < <(
    {
        find "$WORKSPACE_ROOT/products" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
        find "$BUSINESSES_ROOT" -mindepth 3 -maxdepth 3 -type d -path "$BUSINESSES_ROOT/*/products/*" 2>/dev/null
    } | sort
)

if [ "$product_count" -eq 0 ]; then
    echo -e "${GREEN}✅${NC} No products yet (OK)"
    PASS=$((PASS + 1))
else
    run_check "All $product_count products are snake_case" test "$bad_products" -eq 0
fi
echo ""

# 7. Core workspace docs
echo "7. Core Workspace Docs"
echo "---"
run_check "config.md exists" test -f "$WORKSPACE_ROOT/config.md"
run_check "user.md exists" test -f "$WORKSPACE_ROOT/user.md"
run_check "_templates/ exists (canonical BU templates)" test -d "$WORKSPACE_ROOT/_templates"
run_check "_templates/README.md exists" test -f "$WORKSPACE_ROOT/_templates/README.md"
run_check "_templates/TEMPLATE_SYSTEM.md exists" test -f "$WORKSPACE_ROOT/_templates/TEMPLATE_SYSTEM.md"
if [ -d "$WORKSPACE_ROOT/templates" ]; then
    echo -e "${YELLOW}⚠️${NC} workspace/templates/ should not exist. All templates live in workspace/_templates/"
fi
echo ""

# Summary
echo "================================================"
echo -e "Summary:"
echo -e "  ${GREEN}Passed: $PASS${NC}"
if [ "$FAIL" -gt 0 ]; then
    echo -e "  ${RED}Failed: $FAIL${NC}"
fi
echo ""

# Final result
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✅ Workspace structure is valid and ready for governance activation${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Please fix the errors above before activating governance${NC}"
    echo ""
    echo "For help, see: workspace/_templates/TEMPLATE_SYSTEM.md"
    echo ""
    exit 1
fi
