#lang s-exp rosette

(require "riscv-parser.rkt" "riscv-printer.rkt" "riscv-machine.rkt"
         "riscv-simulator-racket.rkt")

(define parser (new riscv-parser%))
(define machine (new riscv-machine% [config 4]))
(define printer (new riscv-printer% [machine machine]))
(define sim (new riscv-simulator-racket% [machine machine]))

(pretty-display "=== Testing Performance Cost Model ===")
(pretty-display "")

(define (test-cost prog-str expected-cost)
  (define prog (send parser ir-from-string prog-str))
  (define encoded (send printer encode prog))
  (define cost (send sim performance-cost encoded))

  (pretty-display (format "Program: ~a" prog-str))
  (pretty-display (format "  Cost: ~a (expected: ~a) ~a"
                         cost expected-cost
                         (if (= cost expected-cost) "✓" "✗")))
  (pretty-display ""))

;; Test basic instructions (1 cycle each)
(test-cost "add x2, x1, x1" 1)
(test-cost "slli x2, x1, 3" 1)
(test-cost "xori x2, x1, -1" 1)

;; Test multiply instructions (4 cycles each)
(test-cost "mul x2, x1, x1" 4)
(test-cost "mulh x2, x1, x1" 4)
(test-cost "mulhu x2, x1, x1" 4)
(test-cost "mulhsu x2, x1, x1" 4)

;; Test divide instructions (32 cycles each)
(test-cost "div x2, x1, x3" 32)
(test-cost "divu x2, x1, x3" 32)
(test-cost "rem x2, x1, x3" 32)
(test-cost "remu x2, x1, x3" 32)

;; Test combined programs
(pretty-display "--- Combined Programs ---")

;; Multiply by 8 using MUL (5 cycles: addi + mul)
(define prog1 (send parser ir-from-string "addi x3, x0, 8"))
(define prog2 (send parser ir-from-string "mul x2, x1, x3"))
(define prog-mul (vector-append prog1 prog2))
(define cost-mul (send sim performance-cost (send printer encode prog-mul)))
(pretty-display (format "Multiply by 8 using MUL: cost = ~a (1 + 4)" cost-mul))

;; Multiply by 8 using shift (1 cycle)
(define prog-shift (send parser ir-from-string "slli x2, x1, 3"))
(define cost-shift (send sim performance-cost (send printer encode prog-shift)))
(pretty-display (format "Multiply by 8 using shift: cost = ~a" cost-shift))

(pretty-display "")
(pretty-display (format "Shift is ~ax faster than MUL for multiply by 8!"
                       (/ cost-mul cost-shift)))

;; Test our naive programs
(pretty-display "")
(pretty-display "--- Naive Program Costs ---")

;; multiply_by_5: 4 instructions, all adds/shifts
(define prog-m5-1 (send parser ir-from-string "slli x2, x1, 1"))
(define prog-m5-2 (send parser ir-from-string "slli x3, x1, 1"))
(define prog-m5-3 (send parser ir-from-string "add x2, x2, x3"))
(define prog-m5-4 (send parser ir-from-string "add x2, x2, x1"))
(define prog-m5 (vector-append prog-m5-1 prog-m5-2 prog-m5-3 prog-m5-4))
(define cost-m5 (send sim performance-cost (send printer encode prog-m5)))
(pretty-display (format "multiply_by_5 (naive): cost = ~a" cost-m5))

;; Optimized multiply_by_5
(define prog-m5-opt1 (send parser ir-from-string "slli x3, x1, 2"))
(define prog-m5-opt2 (send parser ir-from-string "add x2, x3, x1"))
(define prog-m5-opt (vector-append prog-m5-opt1 prog-m5-opt2))
(define cost-m5-opt (send sim performance-cost (send printer encode prog-m5-opt)))
(pretty-display (format "multiply_by_5 (optimal): cost = ~a" cost-m5-opt))
(pretty-display (format "Improvement: ~a cycles saved" (- cost-m5 cost-m5-opt)))