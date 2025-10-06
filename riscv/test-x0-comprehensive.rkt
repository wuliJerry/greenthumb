#lang s-exp rosette

(require "riscv-parser.rkt" "riscv-printer.rkt" "riscv-machine.rkt"
         "riscv-simulator-rosette.rkt" "riscv-simulator-racket.rkt"
         "../memory-racket.rkt" "../validator.rkt")

(current-bitwidth 64)

(define parser (new riscv-parser%))
(define machine (new riscv-machine% [config 10]))
(define printer (new riscv-printer% [machine machine]))
(define sim-racket (new riscv-simulator-racket% [machine machine]))

(define code (send parser ir-from-file "programs/test_x0_zero.s"))
(pretty-display "Program:")
(send printer print-syntax code)

(define encoded (send printer encode code))
(define initial (progstate (vector 0 0 0 0 0 0 0 0 0 0)
                           (new memory-racket% [get-fresh-val (get-rand-func 4)])))

(pretty-display "\nInitial state:")
(pretty-display (progstate-regs initial))

(define result (send sim-racket interpret encoded initial))
(pretty-display "\nFinal state:")
(pretty-display (progstate-regs result))

(define regs (progstate-regs result))
(pretty-display "\nVerification:")
(pretty-display (format "x0 = ~a (should be 0)" (vector-ref regs 0)))
(pretty-display (format "x1 = ~a (should be 10)" (vector-ref regs 1)))
(pretty-display (format "x2 = ~a (should be 20)" (vector-ref regs 2)))
(pretty-display (format "x3 = ~a (should be 10)" (vector-ref regs 3)))
(pretty-display (format "x4 = ~a (should be 10)" (vector-ref regs 4)))

(if (and (= (vector-ref regs 0) 0)
         (= (vector-ref regs 1) 10)
         (= (vector-ref regs 2) 20)
         (= (vector-ref regs 3) 10)
         (= (vector-ref regs 4) 10))
    (pretty-display "\n✓ ALL CHECKS PASSED - x0 is correctly hardwired to 0!")
    (pretty-display "\n✗ FAILED - x0 behavior is incorrect"))
