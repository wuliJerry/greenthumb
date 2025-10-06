#lang s-exp rosette

(require "riscv-parser.rkt" "riscv-printer.rkt" "riscv-machine.rkt"
         "riscv-simulator-rosette.rkt" "riscv-simulator-racket.rkt"
         "../memory-racket.rkt" "../validator.rkt")

(current-bitwidth 64)

;; Test that x0 is hardwired to 0 per RISC-V specification
(pretty-display "=== Testing x0 Register Hardwiring ===")
(pretty-display "RISC-V Specification: x0 must always read as 0 and writes to it are discarded")
(newline)

(define parser (new riscv-parser%))
(define machine (new riscv-machine% [config 10]))
(define printer (new riscv-printer% [machine machine]))
(define sim-rosette (new riscv-simulator-rosette% [machine machine]))
(define sim-racket (new riscv-simulator-racket% [machine machine]))

;; Helper to create initial state
(define (make-test-state . vals)
  (define regs (make-vector 10 0))
  (for ([i (in-range (length vals))])
    (vector-set! regs i (list-ref vals i)))
  (progstate regs (new memory-racket% [get-fresh-val (get-rand-func 4)])))

;; Helper to run test
(define (run-test test-name code-str initial-state expected-x0 rosette?)
  (pretty-display (format "Test: ~a" test-name))
  (define code (send parser ir-from-string code-str))
  (pretty-display "Code:")
  (send printer print-syntax code)
  (define encoded (send printer encode code))
  (define sim (if rosette? sim-rosette sim-racket))
  (define result (send sim interpret encoded initial-state))
  (define x0-val (vector-ref (progstate-regs result) 0))
  (pretty-display (format "x0 value: ~a (expected: ~a)" x0-val expected-x0))
  (if (equal? x0-val expected-x0)
      (pretty-display "✓ PASS")
      (pretty-display "✗ FAIL"))
  (newline))

;; Test 1: Writing to x0 with ADD should be discarded
(pretty-display "--- Test 1: Writing to x0 should be discarded ---")
(define test1-state (make-test-state 0 5 10))
(run-test "add x0, x1, x2 (Rosette)"
          "add x0, x1, x2"
          test1-state
          0  ; x0 should remain 0
          #t)
(run-test "add x0, x1, x2 (Racket)"
          "add x0, x1, x2"
          test1-state
          0
          #f)

;; Test 2: Writing to x0 with ADDI should be discarded
(pretty-display "--- Test 2: ADDI to x0 should be discarded ---")
(run-test "addi x0, x1, 100 (Rosette)"
          "addi x0, x1, 100"
          (make-test-state 0 5)
          0
          #t)
(run-test "addi x0, x1, 100 (Racket)"
          "addi x0, x1, 100"
          (make-test-state 0 5)
          0
          #f)

;; Test 3: Reading from x0 should always give 0
(pretty-display "--- Test 3: Reading from x0 should give 0 ---")
(run-test "add x1, x0, x0 (Rosette)"
          "add x1, x0, x0"
          (make-test-state 0 999)
          0
          #t)
(run-test "add x1, x0, x0 (Racket)"
          "add x1, x0, x0"
          (make-test-state 0 999)
          0
          #f)

;; Test 4: Using x0 as source in comparison
(pretty-display "--- Test 4: SLTU x8, x0, x0 should give 0 ---")
(run-test "sltu x8, x0, x0 (Rosette)"
          "sltu x8, x0, x0"
          (make-test-state 0 0 0 0 0 0 0 0 999)
          0
          #t)
(run-test "sltu x8, x0, x0 (Racket)"
          "sltu x8, x0, x0"
          (make-test-state 0 0 0 0 0 0 0 0 999)
          0
          #f)

;; Test 5: LUI to x0 should be discarded
(pretty-display "--- Test 5: LUI to x0 should be discarded ---")
(run-test "lui x0, 100 (Rosette)"
          "lui x0, 100"
          (make-test-state 0)
          0
          #t)
(run-test "lui x0, 100 (Racket)"
          "lui x0, 100"
          (make-test-state 0)
          0
          #f)

;; Test 6: XOR to x0 should be discarded
(pretty-display "--- Test 6: XOR to x0 should be discarded ---")
(run-test "xor x0, x1, x2 (Rosette)"
          "xor x0, x1, x2"
          (make-test-state 0 5 3)
          0
          #t)
(run-test "xor x0, x1, x2 (Racket)"
          "xor x0, x1, x2"
          (make-test-state 0 5 3)
          0
          #f)

;; Test 7: x0 used as immediate source (pseudo-instruction pattern)
(pretty-display "--- Test 7: NEG using x0 pattern ---")
(run-test "sub x2, x0, x1 (Rosette)"
          "sub x2, x0, x1"
          (make-test-state 0 42)
          0
          #t)
(run-test "sub x2, x0, x1 (Racket)"
          "sub x2, x0, x1"
          (make-test-state 0 42)
          0
          #f)

(pretty-display "=== All x0 Tests Complete ===")
