#lang s-exp rosette

(require "riscv-parser.rkt" "riscv-printer.rkt" "riscv-machine.rkt"
         "riscv-validator.rkt" "riscv-symbolic.rkt"
         "../memory-racket.rkt" "../validator.rkt")

(current-bitwidth 64)

(pretty-display "=== Testing Symbolic Validator with x0 Hardwiring ===")
(newline)

(define parser (new riscv-parser%))
(define machine (new riscv-machine% [config 10]))
(define printer (new riscv-printer% [machine machine]))

;; Test 1: Verify that writing to x0 in spec doesn't affect equivalence checking
(pretty-display "Test 1: Programs writing to x0 should be equivalent to NOP")
(define spec1 (send parser ir-from-string "addi x0, x1, 42"))
(define impl1 (send parser ir-from-string "nop"))

(define encoded-spec1 (send printer encode spec1))
(define encoded-impl1 (send printer encode impl1))

(pretty-display "Spec: addi x0, x1, 42")
(pretty-display "Impl: nop")

(define validator (new riscv-validator% [machine machine]))
(define result1 (send validator verify encoded-spec1 encoded-impl1
                     #:live-in '(1)
                     #:live-out '(0)))

(if result1
    (pretty-display "✓ PASS - Both are equivalent (writes to x0 discarded)")
    (pretty-display "✗ FAIL - Should be equivalent"))
(newline)

;; Test 2: Verify that reading from x0 works correctly in symbolic verification
(pretty-display "Test 2: x0 + x1 should equal x1")
(define spec2 (send parser ir-from-string "add x2, x0, x1"))
(define impl2-str "add x2, x1, x1\nsub x2, x2, x1")
(define impl2 (send parser ir-from-string impl2-str))

(define encoded-spec2 (send printer encode spec2))
(define encoded-impl2 (send printer encode impl2))

(pretty-display "Spec: add x2, x0, x1")
(pretty-display "Impl: add x2, x1, x1; sub x2, x2, x1")

(define result2 (send validator verify encoded-spec2 encoded-impl2
                     #:live-in '(1)
                     #:live-out '(2)))

(if result2
    (pretty-display "✓ PASS - Both are equivalent (x0 + x1 = x1)")
    (pretty-display "✗ FAIL - Should be equivalent"))
(newline)

;; Test 3: Verify x0 always reads as 0 even after attempted writes
(pretty-display "Test 3: Multiple writes to x0 should still leave it as 0")
(define spec3 (send parser ir-from-string "add x3, x0, x1"))
(define impl3-str "addi x0, x0, 100\nadd x3, x0, x1")
(define impl3 (send parser ir-from-string impl3-str))

(define encoded-spec3 (send printer encode spec3))
(define encoded-impl3 (send printer encode impl3))

(pretty-display "Spec: add x3, x0, x1")
(pretty-display "Impl: addi x0, x0, 100; add x3, x0, x1")

(define result3 (send validator verify encoded-spec3 encoded-impl3
                     #:live-in '(1)
                     #:live-out '(3)))

(if result3
    (pretty-display "✓ PASS - Both are equivalent (x0 stays 0)")
    (pretty-display "✗ FAIL - Should be equivalent"))
(newline)

(pretty-display "=== Symbolic Validation Tests Complete ===")
