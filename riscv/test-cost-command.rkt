#lang racket

(require "riscv-parser.rkt" "riscv-machine.rkt" "riscv-printer.rkt"
         "riscv-simulator-racket.rkt")

(define parser (new riscv-parser%))
(define machine (new riscv-machine%))
(define printer (new riscv-printer% [machine machine]))

;; Load cost model
(define cost-model
  (with-input-from-file "costs/add-expensive.rkt" read))

(pretty-display "Cost model loaded:")
(pretty-display cost-model)

;; Create simulator with cost model
(define sim (new riscv-simulator-racket%
                 [machine machine]
                 [cost-model cost-model]))

;; Test program
(define prog (send parser ir-from-string "add x2, x1, x0"))
(define encoded (send printer encode prog))

(define cost (send sim performance-cost encoded))
(pretty-display (format "Cost of 'add x2, x1, x0': ~a (should be 1000)" cost))