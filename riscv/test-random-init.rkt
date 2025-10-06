#lang racket

(require "riscv-machine.rkt")

(define machine (new riscv-machine%))
(send machine set-config 8)

;; Generate 10 random test inputs
(pretty-display "=== Testing random state initialization ===")
(for ([i 10])
  (pretty-display (format "\nTest input ~a:" i))
  (define state (send machine get-state (lambda (#:min [min #f] #:max [max #f] #:const [const #f])
                                          (random 1000))))
  (send machine display-state state))
