#!/bin/bash

echo "Testing RISC-V Superoptimizer"
echo "=============================="
echo

# Test 1: Stochastic search on test_add.s
echo "Test 1: Stochastic search on test_add.s (5 seconds)"
racket optimize.rkt --stoch -o -c 2 -t 5 -d output-test1 programs/test_add.s
echo "Output:"
cat output-test1/best.s 2>/dev/null || echo "No output file generated"
echo
echo "---"
echo

# Test 2: Symbolic search on multiply_by_3.s
echo "Test 2: Symbolic search on multiply_by_3.s (10 seconds)"
racket optimize.rkt --sym -p -c 1 -t 10 -d output-test2 programs/multiply_by_3.s
echo "Output:"
cat output-test2/best.s 2>/dev/null || echo "No output file generated"
echo
echo "---"
echo

# Test 3: Cooperative search on negate.s
echo "Test 3: Cooperative/hybrid search on negate.s (10 seconds)"
racket optimize.rkt --hybrid -p -c 2 -t 10 -d output-test3 programs/negate.s
echo "Output:"
cat output-test3/best.s 2>/dev/null || echo "No output file generated"
echo
echo "---"
echo

echo "Tests complete!"
echo
echo "Cleanup: rm -rf output-test*"
