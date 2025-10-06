#!/bin/bash

# Test using the original optimizer with multiple cores

RACKET=/home/allenjin/racket-8.17/bin/racket

echo "Testing original optimizer with custom cost and multiple cores..."

# First test without custom cost to see if it works
echo "1. Test without custom cost (should work):"
timeout 30 $RACKET optimize.rkt --stoch -c 4 -t 10 programs/alternatives/single/add_copy.s

echo ""
echo "2. Test with custom cost using original optimizer:"
# The original optimizer doesn't support custom costs directly
# We need to modify the simulators with cost models

# Alternative: Create a modified version that hardcodes the cost model
cat > temp-test.rkt << 'EOF'
#lang racket
(require "riscv-parser.rkt" "riscv-machine.rkt" "riscv-printer.rkt"
         "riscv-simulator-racket.rkt" "riscv-simulator-rosette.rkt"
         "riscv-validator.rkt" "riscv-stochastic.rkt"
         "../parallel-driver.rkt" "riscv-enumerator.rkt" "riscv-inverse.rkt"
         "riscv-symbolic.rkt" "riscv-forwardbackward.rkt")

;; Load cost model
(define cost-model
  (with-input-from-file "costs/add-expensive.rkt" read))

(define parser (new riscv-parser%))
(define machine (new riscv-machine%))
(define printer (new riscv-printer% [machine machine]))

;; Create simulators with cost model
(define simulator-racket
  (new riscv-simulator-racket% [machine machine] [cost-model cost-model]))
(define simulator-rosette
  (new riscv-simulator-rosette% [machine machine] [cost-model cost-model]))

(define validator (new riscv-validator% [machine machine] [simulator simulator-rosette]))

;; Create search components
(define symbolic (new riscv-symbolic% [machine machine] [printer printer] [parser parser]
                      [validator validator] [simulator simulator-rosette]))
(define stochastic (new riscv-stochastic% [machine machine] [printer printer] [parser parser]
                         [validator validator] [simulator simulator-racket] [syn-mode #f]))
(define forwardbackward (new riscv-forwardbackward%
                              [machine machine] [printer printer] [parser parser]
                              [validator validator] [simulator simulator-racket]
                              [enumerator% riscv-enumerator%] [inverse% riscv-inverse%]))

;; Create parallel driver
(define driver
  (new parallel-driver%
       [isa "riscv"] [parser parser] [machine machine]
       [printer printer] [validator validator]
       [simulator simulator-racket]
       [search-type 'stoch] [mode 'opt]))

;; Load program
(define code (send parser ir-from-file "programs/alternatives/single/add_copy.s"))
(define info (send parser info-from-file "programs/alternatives/single/add_copy.s"))

(pretty-display "Original cost with custom model:")
(pretty-display (send simulator-racket performance-cost (send printer encode code)))

;; Run optimization with multiple cores
(send driver optimize code info
      #:dir "multicore-test"
      #:cores 4
      #:time-limit 30
      #:size #f
      #:input-file #f)
EOF

echo "Running multicore test with custom cost model..."
timeout 60 $RACKET temp-test.rkt

rm -f temp-test.rkt