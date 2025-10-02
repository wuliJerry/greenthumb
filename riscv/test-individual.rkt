#lang s-exp rosette

(require "riscv-parser.rkt" "riscv-printer.rkt" "riscv-machine.rkt"
         "riscv-simulator-rosette.rkt" "../memory-racket.rkt" "../validator.rkt")

(current-bitwidth 64)

(define parser (new riscv-parser%))
(define machine (new riscv-machine% [config 10]))
(define printer (new riscv-printer% [machine machine]))
(define sim (new riscv-simulator-rosette% [machine machine]))

;; Helper
(define (make-state . reg-values)
  (define regs (make-vector 10 0))
  (for ([val reg-values] [i (length reg-values)])
    (vector-set! regs i val))
  (progstate regs (new memory-racket% [get-fresh-val (get-rand-func 4)])))

;; Test swap_xor.s
(pretty-display "=== Testing swap_xor.s ===")
(define code1 (send parser ir-from-file "programs/swap_xor.s"))
(send printer print-syntax code1)

(define encoded1 (send printer encode code1))
(define input1 (make-state 5 3))  ; x0=5, x1=3
(pretty-display (format "Input:  x0=~a, x1=~a"
                        (vector-ref (progstate-regs input1) 0)
                        (vector-ref (progstate-regs input1) 1)))

(define output1 (send sim interpret encoded1 input1))
(pretty-display (format "Output: x0=~a, x1=~a (expected x0=3, x1=5)"
                        (vector-ref (progstate-regs output1) 0)
                        (vector-ref (progstate-regs output1) 1)))

(newline)

;; Test absolute_diff.s
(pretty-display "=== Testing absolute_diff.s ===")
(define code2 (send parser ir-from-file "programs/absolute_diff.s"))
(send printer print-syntax code2)

(define encoded2 (send printer encode code2))
(define input2 (make-state 0 10 3))  ; x0=0, x1=10, x2=3
(pretty-display (format "Input:  x1=~a, x2=~a"
                        (vector-ref (progstate-regs input2) 1)
                        (vector-ref (progstate-regs input2) 2)))

(define output2 (send sim interpret encoded2 input2))
(pretty-display (format "Output: x0=~a (expected 7 for |10-3|)"
                        (vector-ref (progstate-regs output2) 0)))
(pretty-display (format "All regs: ~a" (progstate-regs output2)))
