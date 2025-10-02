#lang s-exp rosette
(require "../validator.rkt")
(provide riscv-validator%)

(define riscv-validator%
  (class validator%
    (super-new)
    (override get-constructor)

    (define (get-constructor) riscv-validator%)

    ))

