#!/bin/bash

# Comprehensive parallel script to find alternatives for ALL RV32IM instructions

RACKET=/home/allenjin/racket-8.17/bin/racket
TIME_LIMIT=30000
CORES_PER_JOB=64
MAX_PARALLEL=31  # Number of parallel jobs to run simultaneously
OUTPUT_BASE="alternatives-all"

# Create output and log directories
mkdir -p "$OUTPUT_BASE"
mkdir -p "$OUTPUT_BASE/logs"

echo "=== Comprehensive Alternative Implementation Finder ==="
echo "Configuration:"
echo "  - Time limit: ${TIME_LIMIT}s per test"
echo "  - Cores per job: $CORES_PER_JOB"
echo "  - Max parallel jobs: $MAX_PARALLEL"
echo ""

# Function to run a single optimization job
run_optimization() {
    local prog_file=$1
    local cost_file=$2
    local output_dir=$3
    local test_name=$4

    echo "[$(date +%H:%M:%S)] Starting: $test_name"

    $RACKET optimize-alt.rkt \
        --cost "$cost_file" \
        -t $TIME_LIMIT \
        -p $CORES_PER_JOB \
        -d "$output_dir" \
        "$prog_file" \
        > "$OUTPUT_BASE/logs/${test_name}.log" 2>&1

    if [ $? -eq 0 ]; then
        echo "[$(date +%H:%M:%S)] Completed: $test_name"
    else
        echo "[$(date +%H:%M:%S)] Failed: $test_name"
    fi
}

# Export function for parallel execution
export -f run_optimization
export RACKET OUTPUT_BASE TIME_LIMIT CORES_PER_JOB

# Create job list for all single instructions
cat > "$OUTPUT_BASE/jobs.txt" << EOF
programs/alternatives/single/add.s costs/add-expensive.rkt $OUTPUT_BASE/add add
programs/alternatives/single/sub.s costs/sub-expensive.rkt $OUTPUT_BASE/sub sub
programs/alternatives/single/sll.s costs/sll-expensive.rkt $OUTPUT_BASE/sll sll
programs/alternatives/single/slt.s costs/slt-expensive.rkt $OUTPUT_BASE/slt slt
programs/alternatives/single/sltu.s costs/sltu-expensive.rkt $OUTPUT_BASE/sltu sltu
programs/alternatives/single/xor.s costs/xor-expensive.rkt $OUTPUT_BASE/xor xor
programs/alternatives/single/srl.s costs/srl-expensive.rkt $OUTPUT_BASE/srl srl
programs/alternatives/single/sra.s costs/sra-expensive.rkt $OUTPUT_BASE/sra sra
programs/alternatives/single/or.s costs/or-expensive.rkt $OUTPUT_BASE/or or
programs/alternatives/single/and.s costs/and-expensive.rkt $OUTPUT_BASE/and and
programs/alternatives/single/addi.s costs/addi-expensive.rkt $OUTPUT_BASE/addi addi
programs/alternatives/single/slti.s costs/slti-expensive.rkt $OUTPUT_BASE/slti slti
programs/alternatives/single/sltiu.s costs/sltiu-expensive.rkt $OUTPUT_BASE/sltiu sltiu
programs/alternatives/single/xori.s costs/xori-expensive.rkt $OUTPUT_BASE/xori xori
programs/alternatives/single/ori.s costs/ori-expensive.rkt $OUTPUT_BASE/ori ori
programs/alternatives/single/andi.s costs/andi-expensive.rkt $OUTPUT_BASE/andi andi
programs/alternatives/single/slli_double.s costs/slli-expensive.rkt $OUTPUT_BASE/slli slli
programs/alternatives/single/srli.s costs/srli-expensive.rkt $OUTPUT_BASE/srli srli
programs/alternatives/single/srai.s costs/srai-expensive.rkt $OUTPUT_BASE/srai srai
programs/alternatives/single/lui.s costs/lui-expensive.rkt $OUTPUT_BASE/lui lui
programs/alternatives/single/auipc.s costs/auipc-expensive.rkt $OUTPUT_BASE/auipc auipc
programs/alternatives/single/mul.s costs/mul-expensive.rkt $OUTPUT_BASE/mul mul
programs/alternatives/single/mulh.s costs/mulh-expensive.rkt $OUTPUT_BASE/mulh mulh
programs/alternatives/single/mulhsu.s costs/mulhsu-expensive.rkt $OUTPUT_BASE/mulhsu mulhsu
programs/alternatives/single/mulhu.s costs/mulhu-expensive.rkt $OUTPUT_BASE/mulhu mulhu
programs/alternatives/single/div.s costs/div-expensive.rkt $OUTPUT_BASE/div div
programs/alternatives/single/divu.s costs/divu-expensive.rkt $OUTPUT_BASE/divu divu
programs/alternatives/single/rem.s costs/rem-expensive.rkt $OUTPUT_BASE/rem rem
programs/alternatives/single/remu.s costs/remu-expensive.rkt $OUTPUT_BASE/remu remu
EOF

# Add double instruction tests if they exist
if [ -d "programs/alternatives/double" ]; then
    cat >> "$OUTPUT_BASE/jobs.txt" << EOF
programs/alternatives/double/mul_by_5.s costs/shift-add-expensive.rkt $OUTPUT_BASE/mul_by_5 mul_by_5
programs/alternatives/double/negate.s costs/xor-addi-expensive.rkt $OUTPUT_BASE/negate negate
EOF
fi

echo "Starting parallel execution of $(wc -l < "$OUTPUT_BASE/jobs.txt") tests..."
echo ""

# Run jobs in parallel using xargs
cat "$OUTPUT_BASE/jobs.txt" | xargs -P $MAX_PARALLEL -L 1 bash -c 'run_optimization "$@"' _

echo ""
echo "=== All Jobs Complete ==="
echo ""

# Collect and display results
echo "=== Results Summary ==="

for dir in "$OUTPUT_BASE"/*; do
    if [ -d "$dir" ] && [ "$dir" != "$OUTPUT_BASE/logs" ]; then
        test_name=$(basename "$dir")

        # Find best solution
        best_file=$(find "$dir" -name "*.best" 2>/dev/null | head -1)
        if [ -n "$best_file" ] && [ -f "$best_file" ]; then
            echo ""
            echo "$test_name: Alternative found"
            # Show first few lines of the alternative
            head -3 "$best_file" | sed 's/^/  /'
        fi
    fi
done

echo ""
echo "=== Statistics ==="
total_tests=$(wc -l < "$OUTPUT_BASE/jobs.txt")
alternatives_found=$(find "$OUTPUT_BASE" -name "*.best" 2>/dev/null | wc -l)
echo "Total tests: $total_tests"
echo "Alternatives found: $alternatives_found"

echo ""
echo "=== Logs ==="
echo "Detailed logs saved in: $OUTPUT_BASE/logs/"
echo ""
echo "To view a specific result:"
echo "  cat $OUTPUT_BASE/<instruction>/0/driver-0.best"
echo ""
echo "To monitor progress in real-time:"
echo "  tail -f $OUTPUT_BASE/logs/*.log"
