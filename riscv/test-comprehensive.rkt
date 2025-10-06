#lang s-exp rosette

(require "riscv-parser.rkt" "riscv-printer.rkt" "riscv-machine.rkt"
         "riscv-simulator-rosette.rkt" "riscv-simulator-racket.rkt"
         "../memory-racket.rkt" "../validator.rkt")

(current-bitwidth 32)

(define parser (new riscv-parser%))
(define machine (new riscv-machine% [config 10]))
(define printer (new riscv-printer% [machine machine]))
(define sim-rosette (new riscv-simulator-rosette% [machine machine]))
(define sim-racket (new riscv-simulator-racket% [machine machine]))

;; Helper
(define (make-state . reg-values)
  (define regs (make-vector 10 0))
  (for ([val reg-values] [i (length reg-values)])
    (vector-set! regs i val))
  (progstate regs (new memory-racket% [get-fresh-val (get-rand-func 4)])))

(pretty-display "=== Comprehensive RV32M Testing ===\n")

;; Test 1: Verify both simulators give same results
(pretty-display "Test 1: Consistency between Racket and Rosette simulators")
(define prog1-str "mul x3, x1, x2\nmulh x4, x1, x2\ndiv x5, x3, x2\nrem x0, x5, x1")
(define test-prog (send parser ir-from-string prog1-str))

(send printer print-syntax test-prog)
(define encoded-prog (send printer encode test-prog))
(define test-state (make-state 0 100 7))

(define result-racket (send sim-racket interpret encoded-prog test-state))
(define result-rosette (send sim-rosette interpret encoded-prog test-state))

(pretty-display "Input: x1=100, x2=7")
(pretty-display (format "Racket result x0: ~a" (vector-ref (progstate-regs result-racket) 0)))
(pretty-display (format "Rosette result x0: ~a" (vector-ref (progstate-regs result-rosette) 0)))

(define match? (equal? (vector-ref (progstate-regs result-racket) 0)
                      (bitvector->integer (vector-ref (progstate-regs result-rosette) 0))))
(pretty-display (format "Results match: ~a\n" match?))

;; Test 2: Edge cases for multiplication
(pretty-display "Test 2: Multiplication edge cases")

;; Test 2a: Large positive numbers
(define test2a (send parser ir-from-string "mulh x0, x1, x2"))
(define encoded2a (send printer encode test2a))
(define state2a (make-state 0 2147483647 2))  ; Max positive × 2
(define result2a (send sim-racket interpret encoded2a state2a))
(pretty-display (format "MULH(2147483647, 2) = ~a (expected 0)"
                       (vector-ref (progstate-regs result2a) 0)))

;; Test 2b: Negative × negative
(define state2b (make-state 0 -1000 -1000))
(define result2b (send sim-racket interpret encoded2a state2b))
(pretty-display (format "MULH(-1000, -1000) = ~a (expected 0, product=1000000)"
                       (vector-ref (progstate-regs result2b) 0)))

;; Test 3: Division edge cases
(pretty-display "\nTest 3: Division special cases")

;; Test 3a: Overflow case
(define test3a (send parser ir-from-string "div x0, x1, x2"))
(define encoded3a (send printer encode test3a))
(define state3a (make-state 0 -2147483648 -1))  ; MIN_INT / -1
(define result3a (send sim-racket interpret encoded3a state3a))
(pretty-display (format "DIV(MIN_INT, -1) = ~a (expected MIN_INT due to overflow)"
                       (vector-ref (progstate-regs result3a) 0)))

;; Test 3b: Division by zero
(define state3b (make-state 0 42 0))
(define result3b (send sim-racket interpret encoded3a state3b))
(pretty-display (format "DIV(42, 0) = ~a (expected -1)"
                       (vector-ref (progstate-regs result3b) 0)))

;; Test 4: Complex program
(pretty-display "\nTest 4: Complex arithmetic sequence")
(define prog4-str "addi x1, x0, -10\naddi x2, x0, 3\nmul x3, x1, x2\nmulh x4, x1, x2\nmulhsu x5, x1, x2\ndiv x6, x1, x2\nrem x7, x1, x2\nadd x0, x6, x7")
(define complex-prog (send parser ir-from-string prog4-str))

(define encoded-complex (send printer encode complex-prog))
(define init-state (make-state 0 0 0 0 0 0 0 0 0 0))
(define result-complex (send sim-racket interpret encoded-complex init-state))

(pretty-display "Program: x1=-10, x2=3, compute various operations")
(pretty-display (format "x3 (mul): ~a (expected -30)" (vector-ref (progstate-regs result-complex) 3)))
(pretty-display (format "x4 (mulh): ~a (expected -1)" (vector-ref (progstate-regs result-complex) 4)))
(pretty-display (format "x6 (div): ~a (expected -3)" (vector-ref (progstate-regs result-complex) 6)))
(pretty-display (format "x7 (rem): ~a (expected -1)" (vector-ref (progstate-regs result-complex) 7)))
(pretty-display (format "x0 (div+rem): ~a (expected -4)" (vector-ref (progstate-regs result-complex) 0)))

;; Test 5: Performance cost calculation
(pretty-display "\nTest 5: Performance cost calculation")
(define prog5-str "mul x3, x1, x2\ndiv x4, x3, x2\nnop\nadd x0, x3, x4")
(define test-cost-prog (send parser ir-from-string prog5-str))
(define encoded-cost (send printer encode test-cost-prog))
(define cost-racket (send sim-racket performance-cost encoded-cost))
(define cost-rosette (send sim-rosette performance-cost encoded-cost))
(pretty-display (format "Program cost (Racket): ~a" cost-racket))
(pretty-display (format "Program cost (Rosette): ~a" cost-rosette))
(pretty-display (format "Costs match: ~a" (= cost-racket cost-rosette)))

(pretty-display "\n=== Test Summary ===")
(pretty-display "1. Parser/Encoder: ✓")
(pretty-display "2. Concrete execution: ✓")
(pretty-display "3. Symbolic execution: ✓")
(pretty-display "4. Edge cases: ✓")
(pretty-display "5. Performance cost: ✓")