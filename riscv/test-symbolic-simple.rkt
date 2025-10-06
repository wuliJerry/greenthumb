#lang s-exp rosette

(require "riscv-parser.rkt" "riscv-printer.rkt" "riscv-machine.rkt"
         "riscv-validator.rkt" "riscv-symbolic.rkt" "riscv-simulator-rosette.rkt"
         "../memory-racket.rkt" "../validator.rkt")

(current-bitwidth 64)

(pretty-display "=== Testing Symbolic Validator with x0 Hardwiring ===")
(newline)

(define parser (new riscv-parser%))
(define machine (new riscv-machine% [config 10]))
(define printer (new riscv-printer% [machine machine]))
(define simulator-rosette (new riscv-simulator-rosette% [machine machine]))
(define validator (new riscv-validator% [machine machine] [simulator simulator-rosette]))

;; Test 1: x0 + x1 should equal x1
(pretty-display "Test 1: add x2, x0, x1 should be equivalent to add x2, x1, x1; sub x2, x2, x1")
(define spec1 (send parser ir-from-string "add x2, x0, x1"))
(define impl1-str "add x2, x1, x1\nsub x2, x2, x1")
(define impl1 (send parser ir-from-string impl1-str))

(define encoded-spec1 (send printer encode spec1))
(define encoded-impl1 (send printer encode impl1))

(define result1 (send validator verify encoded-spec1 encoded-impl1
                     #:live-in '(1)
                     #:live-out '(2)))

(if result1
    (pretty-display "✓ PASS - x0 + x1 = x1 (x0 correctly reads as 0)")
    (pretty-display "✗ FAIL - Should be equivalent"))
(newline)

;; Test 2: Writes to x0 are discarded
(pretty-display "Test 2: Writing to x0 then reading should still give 0")
(define spec2-str "add x3, x0, x1")
(define impl2-str "addi x0, x0, 100\nadd x3, x0, x1")

(define spec2 (send parser ir-from-string spec2-str))
(define impl2 (send parser ir-from-string impl2-str))

(define encoded-spec2 (send printer encode spec2))
(define encoded-impl2 (send printer encode impl2))

(define result2 (send validator verify encoded-spec2 encoded-impl2
                     #:live-in '(1)
                     #:live-out '(3)))

(if result2
    (pretty-display "✓ PASS - Writes to x0 are discarded")
    (pretty-display "✗ FAIL - Should be equivalent"))
(newline)

;; Test 3: x0 can be used as constant zero source
(pretty-display "Test 3: sub x4, x1, x0 should equal x1")
(define spec3-str "add x4, x1, x1\nsub x4, x4, x1")
(define impl3-str "sub x4, x1, x0")

(define spec3 (send parser ir-from-string spec3-str))
(define impl3 (send parser ir-from-string impl3-str))

(define encoded-spec3 (send printer encode spec3))
(define encoded-impl3 (send printer encode impl3))

(define result3 (send validator verify encoded-spec3 encoded-impl3
                     #:live-in '(1)
                     #:live-out '(4)))

(if result3
    (pretty-display "✓ PASS - x1 - 0 = x1 (x0 correctly reads as 0)")
    (pretty-display "✗ FAIL - Should be equivalent"))
(newline)

(pretty-display "=== Symbolic Validation Tests Complete ===")
(if (and result1 result2 result3)
    (pretty-display "✓ ALL TESTS PASSED - x0 hardwiring works correctly in symbolic engine!")
    (pretty-display "✗ SOME TESTS FAILED"))
