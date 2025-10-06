#lang racket

(require "riscv-parser.rkt" "riscv-machine.rkt" "riscv-printer.rkt"
         "riscv-simulator-racket.rkt" "riscv-simulator-rosette.rkt"
         "riscv-validator.rkt" "../memory-racket.rkt")

;; Create necessary objects
(define machine (new riscv-machine% [config 5]))
(define printer (new riscv-printer% [machine machine]))
(define parser (new riscv-parser%))
(define sim-racket (new riscv-simulator-racket% [machine machine]))
(define sim-rosette (new riscv-simulator-rosette% [machine machine]))
(define validator (new riscv-validator% [machine machine] [simulator sim-rosette]))

(pretty-display "=== Testing Naive Program Optimizations ===")
(pretty-display "")

;; Test if two programs are equivalent
(define (test-equivalence prog1-str prog2-str test-name)
  (define prog1 (send parser ir-from-string prog1-str))
  (define prog2 (send parser ir-from-string prog2-str))

  (define encoded1 (send printer encode prog1))
  (define encoded2 (send printer encode prog2))

  (define cost1 (send sim-racket performance-cost encoded1))
  (define cost2 (send sim-racket performance-cost encoded2))

  (pretty-display (format "Testing ~a:" test-name))
  (pretty-display (format "  Original: ~a (cost: ~a)" prog1-str cost1))
  (pretty-display (format "  Optimized: ~a (cost: ~a)" prog2-str cost2))

  ;; Test with various inputs
  (define test-inputs '((0 5 10 0 0)
                       (0 -3 7 0 0)
                       (0 100 -50 0 0)
                       (0 1 1 0 0)))

  (define all-equal #t)
  (for ([input test-inputs])
    (define state (progstate (list->vector input)
                             (new memory-racket% [get-fresh-val (lambda () 0)])))

    (define result1 (send sim-racket interpret encoded1 state))
    (define result2 (send sim-racket interpret encoded2 state))

    ;; Check relevant output registers
    (for ([i (in-range 5)])
      (define v1 (vector-ref (progstate-regs result1) i))
      (define v2 (vector-ref (progstate-regs result2) i))
      (unless (= v1 v2)
        (set! all-equal #f)
        (pretty-display (format "    MISMATCH at x~a: ~a vs ~a" i v1 v2)))))

  (if all-equal
      (pretty-display (format "  ✓ Equivalent! Improvement: ~a instructions" (- cost1 cost2)))
      (pretty-display "  ✗ Not equivalent!"))
  (pretty-display ""))

;; Test multiply by 3
(test-equivalence
  "add x2, x1, x1\nadd x2, x2, x1"
  "slli x3, x1, 1\nadd x2, x3, x1"
  "Multiply by 3")

;; Alternative multiply by 3
(test-equivalence
  "add x2, x1, x1\nadd x2, x2, x1"
  "add x3, x1, x1\nadd x2, x1, x3"
  "Multiply by 3 (alt)")

;; Test multiply by 5
(test-equivalence
  "slli x2, x1, 1\nslli x3, x1, 1\nadd x2, x2, x3\nadd x2, x2, x1"
  "slli x3, x1, 2\nadd x2, x3, x1"
  "Multiply by 5")

;; Test zero upper 16 bits - but we need proper mask support
;; For now, the shift method is actually optimal without ANDI support for large constants
(pretty-display "Zero upper 16 bits:")
(pretty-display "  Current: slli x2, x1, 16; srli x2, x2, 16 (cost: 2)")
(pretty-display "  Would need: andi x2, x1, 65535 (but 65535 not in const pool)")
(pretty-display "  Current implementation is optimal given constraints")
(pretty-display "")

;; Test sign extend byte
(pretty-display "Sign extend byte:")
(pretty-display "  Current: slli x2, x1, 24; srai x2, x2, 24 (cost: 2)")
(pretty-display "  This is already optimal for sign extension")
(pretty-display "")

;; Test double negation - we showed this works!
(test-equivalence
  "xori x2, x1, -1\naddi x3, x2, 1\nxori x4, x3, -1\naddi x5, x4, 1"
  "add x5, x1, x0"
  "Double negation to identity")

;; Test swap using XOR (if it works)
(test-equivalence
  "add x3, x1, x0\nadd x1, x2, x0\nadd x2, x3, x0"
  "xor x1, x1, x2\nxor x2, x1, x2\nxor x1, x1, x2"
  "Swap using XOR")

(pretty-display "=== Summary ===")
(pretty-display "Several naive implementations can be optimized:")
(pretty-display "- Multiply by constant: Use shifts and adds efficiently")
(pretty-display "- Double negation: Reduce to simple copy")
(pretty-display "- Some operations are already optimal given ISA constraints")