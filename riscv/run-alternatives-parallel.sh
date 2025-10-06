#!/bin/bash

# Parallel batch script to find alternative implementations
# Launches multiple optimizer instances simultaneously

RACKET=/home/allenjin/racket-8.17/bin/racket
TIME_LIMIT=120
CORES_PER_JOB=64
MAX_PARALLEL=4  # Number of parallel jobs
OUTPUT_BASE="alternatives-parallel"

# Create output and log directories
mkdir -p "$OUTPUT_BASE"
mkdir -p "$OUTPUT_BASE/logs"

echo "=== Parallel Alternative Implementation Finder ==="
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
    local search_mode=$5

    echo "[$(date +%H:%M:%S)] Starting: $test_name"

    $RACKET optimize-with-cost.rkt \
        --cost "$cost_file" \
        --$search_mode \
        -c $CORES_PER_JOB \
        -t $TIME_LIMIT \
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
export RACKET OUTPUT_BASE CORES_PER_JOB TIME_LIMIT

# Create job list
cat > "$OUTPUT_BASE/jobs.txt" << EOF
programs/alternatives/single/add_copy.s costs/add-expensive.rkt $OUTPUT_BASE/add_copy add_copy stoch
programs/alternatives/single/slli_double.s costs/slli-expensive.rkt $OUTPUT_BASE/slli_double slli_double stoch
programs/alternatives/double/mul_by_5.s costs/shift-add-expensive.rkt $OUTPUT_BASE/mul_by_5 mul_by_5 hybrid
programs/alternatives/double/negate.s costs/xor-addi-expensive.rkt $OUTPUT_BASE/negate negate hybrid
EOF

echo "Starting parallel execution..."
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
        echo ""
        echo "$test_name:"

        # Find best solution
        best_file=$(find "$dir" -name "*.best" 2>/dev/null | head -1)
        if [ -n "$best_file" ] && [ -f "$best_file" ]; then
            echo "  Alternative found:"
            cat "$best_file" | sed 's/^/    /' | head -10
        else
            # Check if still running or no solution
            log_file="$OUTPUT_BASE/logs/${test_name}.log"
            if [ -f "$log_file" ]; then
                if grep -q "OUTPUT" "$log_file"; then
                    echo "  Original program (no better alternative found)"
                else
                    echo "  Still searching or error (check logs)"
                fi
            else
                echo "  No results yet"
            fi
        fi
    fi
done

echo ""
echo "=== Logs ==="
echo "Detailed logs saved in: $OUTPUT_BASE/logs/"
echo ""
echo "To monitor progress in real-time, use:"
echo "  tail -f $OUTPUT_BASE/logs/*.log"