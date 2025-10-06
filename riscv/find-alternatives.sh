#!/bin/bash

# Script to find alternative implementations for instructions
# by making the original instructions prohibitively expensive

RACKET=/home/allenjin/racket-8.17/bin/racket
TIME_LIMIT=120
CORES=4
OUTPUT_BASE="alternatives-output"

# Create output directory
mkdir -p "$OUTPUT_BASE"

echo "=== Finding Alternative Implementations ==="
echo "Using optimizer with modified cost models"
echo ""

# Single instruction tests
echo "=== Single Instruction Alternatives ==="

# Test 1: Find alternatives to "add x2, x1, x3"
echo "1. Testing: add x2, x1, x3"
echo "   Making ADD expensive (cost=1000)"
$RACKET optimize-alt.rkt \
    --cost costs/add-expensive.rkt \
    -t $TIME_LIMIT \
    -p $CORES \
    -d "$OUTPUT_BASE/add" \
    programs/alternatives/single/add.s

# Test 2: Find alternatives to "slli x2, x1, 1" (multiply by 2)
echo ""
echo "2. Testing: slli x2, x1, 1 (multiply by 2)"
echo "   Making SLLI expensive (cost=1000)"
$RACKET optimize-alt.rkt \
    --cost costs/slli-expensive.rkt \
    -t $TIME_LIMIT \
    -p $CORES \
    -d "$OUTPUT_BASE/slli_double" \
    programs/alternatives/single/slli_double.s

# Double instruction tests
echo ""
echo "=== Two-Instruction Sequence Alternatives ==="

# Test 3: Find alternatives to multiply by 5
echo "3. Testing: slli x2, x1, 2; add x2, x2, x1 (multiply by 5)"
echo "   Making SLLI and ADD expensive (cost=500 each)"
$RACKET optimize-alt.rkt \
    --cost costs/shift-add-expensive.rkt \
    -t $TIME_LIMIT \
    -p $CORES \
    -d "$OUTPUT_BASE/mul_by_5" \
    programs/alternatives/double/mul_by_5.s

# Test 4: Find alternatives to negate
echo ""
echo "4. Testing: xori x2, x1, -1; addi x2, x2, 1 (negate)"
echo "   Making XORI and ADDI expensive (cost=500 each)"
$RACKET optimize-alt.rkt \
    --cost costs/xor-addi-expensive.rkt \
    -t $TIME_LIMIT \
    -p $CORES \
    -d "$OUTPUT_BASE/negate" \
    programs/alternatives/double/negate.s

echo ""
echo "=== Collecting Results ==="

# Display results
for dir in "$OUTPUT_BASE"/*; do
    if [ -d "$dir" ]; then
        test_name=$(basename "$dir")
        echo ""
        echo "Results for: $test_name"

        # Check if best solution exists
        if [ -f "$dir/0/driver-0.best" ]; then
            echo "  Found alternative:"
            cat "$dir/0/driver-0.best" 2>/dev/null | head -10
        else
            echo "  No alternative found (or still searching)"
        fi
    fi
done

echo ""
echo "=== Summary ==="
echo "Results saved in: $OUTPUT_BASE/"
echo "Check individual directories for detailed logs and optimized code"