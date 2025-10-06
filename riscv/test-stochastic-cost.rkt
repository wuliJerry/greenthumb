#lang racket

(require "riscv-parser.rkt"
         "riscv-machine.rkt"
         "riscv-printer.rkt"
         "riscv-simulator-racket.rkt"
         "riscv-stochastic.rkt")

;; Test the stochastic cost function

(define parser (new riscv-parser%))
(define machine (new riscv-machine%))
(send machine set-config 8)

(define printer (new riscv-printer% [machine machine]))
(define simulator (new riscv-simulator-racket% [machine machine]))

;; Original program: x7 = x1
(define original-code (send parser ir-from-file "programs/complex_identity.s"))
(define encoded-original (send printer encode original-code))

;; Buggy program: x5 = x1 (wrong register!)
(define buggy-file "programs/test_buggy.s")
(define buggy-code (send parser ir-from-file buggy-file))
(define encoded-buggy (send printer encode buggy-code))

;; Constraint: only x7 matters
(define live-out (list 7))
(define constraint (send printer encode-live live-out))

(pretty-display "=== Testing Stochastic Cost Function ===")
(pretty-display "Constraint (only x7):")
(send machine display-state constraint)

;; Create stochastic search instance
(define stoch (new riscv-stochastic%
                   [machine machine]
                   [printer printer]
                   [validator #f]  ;; Not needed for this test
                   [simulator simulator]
                   [syn-mode #f]))

;; Generate random input
(define input (send machine get-state (lambda (#:min [min #f] #:max [max #f] #:const [const #f])
                                        (random 1000))))

(pretty-display "\nRandom input state:")
(send machine display-state input)

;; Run both programs
(define expected-output (send simulator interpret encoded-original input))
(define actual-output (send simulator interpret encoded-buggy input))

(pretty-display "\nExpected output (from original program):")
(send machine display-state expected-output)

(pretty-display "\nActual output (from buggy program):")
(send machine display-state actual-output)

;; Compute cost
(define cost (send stoch correctness-cost expected-output actual-output constraint))

(pretty-display (format "\nCorrectness cost: ~a" cost))

(if (= cost 0)
    (pretty-display "✗ BUG: Cost is 0, meaning stochastic search would accept this buggy program!")
    (pretty-display "✓ GOOD: Cost is non-zero, stochastic search would reject this program."))
