#lang s-exp rosette

(require "riscv-parser.rkt" "riscv-printer.rkt" "riscv-machine.rkt"
         "riscv-simulator-rosette.rkt" "riscv-simulator-racket.rkt"
         "../memory-racket.rkt")

(current-bitwidth 32)

(define parser (new riscv-parser%))
(define machine (new riscv-machine% [config 4]))  ; Use 4 registers
(define printer (new riscv-printer% [machine machine]))
(define sim-rosette (new riscv-simulator-rosette% [machine machine]))
(define sim-racket (new riscv-simulator-racket% [machine machine]))

;; Test if add x0, x1, x1 is equivalent to slli x0, x1, 1

(define prog1 (send parser ir-from-string "add x0, x1, x1"))
(define prog2 (send parser ir-from-string "slli x0, x1, 1"))

(pretty-display "Program 1: add x0, x1, x1")
(pretty-display "Program 2: slli x0, x1, 1")
(pretty-display "")

(define encoded1 (send printer encode prog1))
(define encoded2 (send printer encode prog2))

;; Test with various inputs
(define test-values '(0 1 -1 42 -42 1000000 -1000000 2147483647 -2147483648))

(define all-equal #t)
(for ([val test-values])
  (define state (progstate (vector 0 val 0 0)
                           (new memory-racket% [get-fresh-val (lambda () 0)])))

  (define result1 (send sim-racket interpret encoded1 state))
  (define result2 (send sim-racket interpret encoded2 state))

  (define out1 (vector-ref (progstate-regs result1) 0))
  (define out2 (vector-ref (progstate-regs result2) 0))

  (define equal? (= out1 out2))
  (unless equal? (set! all-equal #f))

  (pretty-display (format "Input x1=~a: add result=~a, slli result=~a, equal=~a"
                         val out1 out2 equal?)))

(pretty-display "")
(pretty-display (format "All results equal: ~a" all-equal))

;; Now test costs
(define cost1 (send sim-racket performance-cost encoded1))
(define cost2 (send sim-racket performance-cost encoded2))

(pretty-display (format "\nPerformance cost - add: ~a, slli: ~a" cost1 cost2))
(pretty-display (format "Both have same cost: ~a" (= cost1 cost2)))