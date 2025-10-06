#!/bin/bash
# Parallel test script for RISC-V optimizer with both sym and stoch modes
# Tests all programs except mulhu64_soft.s

set -e

# Configuration
TIME_LIMIT=300  # 5 minutes per test
OUTPUT_DIR="test_results_$(date +%Y%m%d_%H%M%S)"
NUM_CORES=1     # Number of cores per search mode

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}RISC-V Optimizer Parallel Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"
echo -e "${GREEN}Created output directory: $OUTPUT_DIR${NC}"
echo ""

# Get all test programs except mulhu64
PROGRAMS=(programs/*.s)
FILTERED_PROGRAMS=()

for prog in "${PROGRAMS[@]}"; do
    if [[ ! "$prog" =~ mulhu64 ]] && [[ ! "$prog" =~ test_x0 ]]; then
        FILTERED_PROGRAMS+=("$prog")
    fi
done

echo -e "${BLUE}Programs to test (${#FILTERED_PROGRAMS[@]} total):${NC}"
for prog in "${FILTERED_PROGRAMS[@]}"; do
    echo "  - $(basename $prog)"
done
echo ""

# Function to run a single test
run_test() {
    local program=$1
    local mode=$2
    local basename=$(basename "$program" .s)
    local logfile="$OUTPUT_DIR/${basename}_${mode}.log"
    local statusfile="$OUTPUT_DIR/${basename}_${mode}.status"

    echo -e "${YELLOW}[START]${NC} Testing $basename with $mode mode..."

    # Run optimizer with timeout
    if timeout $TIME_LIMIT racket optimize.rkt --${mode} -o -c $NUM_CORES "$program" > "$logfile" 2>&1; then
        echo -e "${GREEN}[DONE]${NC} $basename ($mode) - Check $logfile"
        echo "SUCCESS" > "$statusfile"
    else
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 124 ]; then
            echo -e "${YELLOW}[TIMEOUT]${NC} $basename ($mode) - Exceeded ${TIME_LIMIT}s"
            echo "TIMEOUT" > "$statusfile"
        else
            echo -e "${RED}[ERROR]${NC} $basename ($mode) - Exit code: $EXIT_CODE"
            echo "ERROR" > "$statusfile"
        fi
    fi
}

# Export function and variables for parallel execution
export -f run_test
export TIME_LIMIT OUTPUT_DIR NUM_CORES RED GREEN YELLOW BLUE NC

# Create array of all test combinations
TEST_JOBS=()
for prog in "${FILTERED_PROGRAMS[@]}"; do
    TEST_JOBS+=("$prog sym")
    TEST_JOBS+=("$prog stoch")
done

echo -e "${BLUE}Running ${#TEST_JOBS[@]} tests in parallel...${NC}"
echo -e "${BLUE}Time limit per test: ${TIME_LIMIT}s${NC}"
echo ""

# Run all tests in parallel using GNU parallel or xargs
if command -v parallel &> /dev/null; then
    # Use GNU parallel if available (better progress reporting)
    printf '%s\n' "${TEST_JOBS[@]}" | parallel --colsep ' ' --jobs 4 --progress run_test {1} {2}
else
    # Fallback to xargs (standard on most systems)
    echo -e "${YELLOW}Note: Install 'parallel' for better progress tracking${NC}"
    printf '%s\n' "${TEST_JOBS[@]}" | xargs -n 2 -P 4 bash -c 'run_test "$@"' _
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Generate summary
SUCCESS_COUNT=0
TIMEOUT_COUNT=0
ERROR_COUNT=0
IMPROVEMENT_COUNT=0

for prog in "${FILTERED_PROGRAMS[@]}"; do
    basename=$(basename "$prog" .s)
    echo -e "${BLUE}Program: $basename${NC}"

    for mode in sym stoch; do
        statusfile="$OUTPUT_DIR/${basename}_${mode}.status"
        logfile="$OUTPUT_DIR/${basename}_${mode}.log"

        if [ -f "$statusfile" ]; then
            status=$(cat "$statusfile")

            # Check for improvement
            improvement=""
            if [ -f "$logfile" ] && grep -q "IMPROVEMENT FOUND" "$logfile"; then
                improvement=" ${GREEN}[IMPROVEMENT FOUND!]${NC}"
                ((IMPROVEMENT_COUNT++))
            fi

            case $status in
                SUCCESS)
                    echo -e "  ${mode}: ${GREEN}✓ SUCCESS${NC}$improvement"
                    ((SUCCESS_COUNT++))
                    ;;
                TIMEOUT)
                    echo -e "  ${mode}: ${YELLOW}⏱ TIMEOUT${NC}"
                    ((TIMEOUT_COUNT++))
                    ;;
                ERROR)
                    echo -e "  ${mode}: ${RED}✗ ERROR${NC}"
                    ((ERROR_COUNT++))
                    ;;
            esac
        else
            echo -e "  ${mode}: ${RED}✗ NO STATUS${NC}"
            ((ERROR_COUNT++))
        fi
    done
    echo ""
done

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Total SUCCESS: $SUCCESS_COUNT${NC}"
echo -e "${YELLOW}Total TIMEOUT: $TIMEOUT_COUNT${NC}"
echo -e "${RED}Total ERROR: $ERROR_COUNT${NC}"
echo -e "${GREEN}Programs with IMPROVEMENTS: $IMPROVEMENT_COUNT${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${BLUE}Detailed logs available in: $OUTPUT_DIR/${NC}"
echo ""

# Create a summary report file
SUMMARY_FILE="$OUTPUT_DIR/SUMMARY.md"
cat > "$SUMMARY_FILE" << EOF
# RISC-V Optimizer Test Summary

**Date**: $(date)
**Time Limit**: ${TIME_LIMIT}s per test
**Programs Tested**: ${#FILTERED_PROGRAMS[@]}
**Total Tests**: $((${#FILTERED_PROGRAMS[@]} * 2))

## Results

- ✓ Success: $SUCCESS_COUNT
- ⏱ Timeout: $TIMEOUT_COUNT
- ✗ Error: $ERROR_COUNT
- 🎯 Improvements Found: $IMPROVEMENT_COUNT

## Program Details

EOF

for prog in "${FILTERED_PROGRAMS[@]}"; do
    basename=$(basename "$prog" .s)
    echo "### $basename" >> "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"

    for mode in sym stoch; do
        statusfile="$OUTPUT_DIR/${basename}_${mode}.status"
        logfile="$OUTPUT_DIR/${basename}_${mode}.log"

        if [ -f "$statusfile" ]; then
            status=$(cat "$statusfile")

            # Extract key metrics from log
            if [ -f "$logfile" ]; then
                original_cost=$(grep ">>> original cost:" "$logfile" | head -1 | awk '{print $NF}')
                improvement=$(grep "IMPROVEMENT FOUND" "$logfile" -A 3 | grep "Improvement:" | awk '{print $2}')

                echo "**Mode: $mode**" >> "$SUMMARY_FILE"
                echo "- Status: $status" >> "$SUMMARY_FILE"
                [ -n "$original_cost" ] && echo "- Original Cost: $original_cost" >> "$SUMMARY_FILE"
                [ -n "$improvement" ] && echo "- Improvement: $improvement" >> "$SUMMARY_FILE"
                echo "" >> "$SUMMARY_FILE"
            fi
        fi
    done
    echo "" >> "$SUMMARY_FILE"
done

echo -e "${GREEN}Summary report created: $SUMMARY_FILE${NC}"
echo ""

# Exit with error if any tests failed
if [ $ERROR_COUNT -gt 0 ]; then
    exit 1
fi
