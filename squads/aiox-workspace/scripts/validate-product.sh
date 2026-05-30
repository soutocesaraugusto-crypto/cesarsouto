#!/bin/bash

# ============================================================================
# validate-product.sh
#
# Validates product offerbook completeness across all YAML files
# Reports % complete for each file + overall product
#
# Usage:
#   ./squads/aiox-workspace/scripts/validate-product.sh businesses/academia_lendaria/products/comunidade
#   ./squads/aiox-workspace/scripts/validate-product.sh businesses/your_business/products/your_product
#
# Output:
#   ✅ overview.md exists
#   ✅ icp.yaml: 47/47 fields (100%)
#   ✅ brand.yaml: 42/42 fields (100%)
#   ⚠️  Missing: 5 fields in brand.yaml (fields: field_1, field_2, ...)
#   ❌ offerbook.yaml: NOT FOUND
#
#   Overall: X% complete — Ready for production (or Fix these X issues)
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Config
PRODUCT_PATH="${1:-.}"
OVERVIEW_FILE="$PRODUCT_PATH/overview.md"
ICP_FILE="$PRODUCT_PATH/icp.yaml"
BRAND_FILE="$PRODUCT_PATH/brand.yaml"
OFFERBOOK_FILE="$PRODUCT_PATH/offerbook.yaml"
ANALYTICS_FILE="$PRODUCT_PATH/analytics.yaml"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Product Offerbook Validator${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Validating: $PRODUCT_PATH"
echo ""

TOTAL_REQUIRED=0
TOTAL_COMPLETED=0
TOTAL_ISSUES=0

# ============================================================================
# FUNCTION: Count YAML fields
# ============================================================================

validate_yaml() {
    local file=$1
    local expected_count=$2
    local file_type=$3

    if [ ! -f "$file" ]; then
        echo -e "${RED}❌ $file_type NOT FOUND${NC}"
        return 1
    fi

    # Count "status: COMPLETE" entries
    local complete_count
    local incomplete_count
    local declared_required
    local declared_completed
    complete_count=$(grep -E 'status:[[:space:]]*"?COMPLETE"?' "$file" 2>/dev/null | wc -l | tr -d ' ')
    incomplete_count=$(grep -E 'status:[[:space:]]*"?INCOMPLETE"?' "$file" 2>/dev/null | wc -l | tr -d ' ')

    declared_required=$(grep -E '^[[:space:]]*required_fields:[[:space:]]*[0-9]+' "$file" | head -n 1 | sed -E 's/.*required_fields:[[:space:]]*([0-9]+).*/\1/')
    declared_completed=$(grep -E '^[[:space:]]*completed_fields:[[:space:]]*[0-9]+' "$file" | head -n 1 | sed -E 's/.*completed_fields:[[:space:]]*([0-9]+).*/\1/')

    if [[ "$declared_required" =~ ^[0-9]+$ ]] && [[ "$declared_completed" =~ ^[0-9]+$ ]]; then
        expected_count="$declared_required"
        complete_count="$declared_completed"
        if [ "$complete_count" -gt "$expected_count" ]; then
            complete_count="$expected_count"
        fi
        incomplete_count=$((expected_count - complete_count))
    fi

    local total=$((complete_count + incomplete_count))

    if [ "$total" -eq 0 ]; then
        echo -e "${RED}❌ $file_type: No status fields found${NC}"
        return 1
    fi

    local percentage=$((complete_count * 100 / total))

    TOTAL_REQUIRED=$((TOTAL_REQUIRED + expected_count))
    TOTAL_COMPLETED=$((TOTAL_COMPLETED + complete_count))

    if [ "$complete_count" -eq "$expected_count" ]; then
        echo -e "${GREEN}✅ $file_type: $complete_count/$expected_count fields (100%)${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  $file_type: $complete_count/$expected_count fields ($percentage%)${NC}"

        # Show which ones are incomplete
        local incomplete_fields
        incomplete_fields=$(grep -B1 'status: INCOMPLETE' "$file" | grep -E '^[[:space:]]+[a-z_]+:' | sed -E 's/^[[:space:]]*//; s/:$//' | tr '\n' ',' | sed 's/,$//')

        if [ -n "$incomplete_fields" ]; then
            echo -e "    ${RED}Missing:${NC} $incomplete_fields"
        fi

        TOTAL_ISSUES=$((TOTAL_ISSUES + incomplete_count))
        return 1
    fi
}

# ============================================================================
# VALIDATION CHECKS
# ============================================================================

echo -e "${BLUE}Checking Files:${NC}"
echo ""

# Check overview.md
if [ -f "$OVERVIEW_FILE" ]; then
    echo -e "${GREEN}✅ overview.md exists${NC}"
else
    echo -e "${RED}❌ overview.md NOT FOUND${NC}"
    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
fi

echo ""

# Check ICP (47 fields)
validate_yaml "$ICP_FILE" 47 "icp.yaml"
ICP_VALID=$?

echo ""

# Check Brand (42 fields)
validate_yaml "$BRAND_FILE" 42 "brand.yaml"
BRAND_VALID=$?

echo ""

# Check Offerbook (just existence, structure is complex)
if [ -f "$OFFERBOOK_FILE" ]; then
    echo -e "${GREEN}✅ offerbook.yaml exists${NC}"
else
    echo -e "${RED}❌ offerbook.yaml NOT FOUND${NC}"
    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
fi

echo ""

# Check Analytics
if [ -f "$ANALYTICS_FILE" ]; then
    echo -e "${GREEN}✅ analytics.yaml exists${NC}"
else
    echo -e "${RED}❌ analytics.yaml NOT FOUND${NC}"
    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "$TOTAL_REQUIRED" -gt 0 ]; then
    overall_percentage=$((TOTAL_COMPLETED * 100 / TOTAL_REQUIRED))
    echo "Fields: $TOTAL_COMPLETED/$TOTAL_REQUIRED ($overall_percentage%)"
else
    overall_percentage=0
fi

if [ "$TOTAL_ISSUES" -eq 0 ] && [ -f "$ICP_FILE" ] && [ -f "$BRAND_FILE" ] && [ -f "$OVERVIEW_FILE" ] && [ -f "$OFFERBOOK_FILE" ] && [ -f "$ANALYTICS_FILE" ]; then
    echo -e "${GREEN}✅ Product is 100% complete and ready for production${NC}"
    echo ""
    echo "Next steps:"
    echo "  git add $PRODUCT_PATH/"
    echo "  git commit -m \"feat: add product $PRODUCT_PATH\""
    echo ""
    exit 0
else
    echo -e "${RED}❌ Product has $TOTAL_ISSUES issues to fix${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Fill in all FILL THIS sections"
    echo "  2. Change status: INCOMPLETE → status: COMPLETE"
    echo "  3. Run validation again:"
    echo "     ./squads/aiox-workspace/scripts/validate-product.sh $PRODUCT_PATH"
    echo ""
    exit 1
fi
