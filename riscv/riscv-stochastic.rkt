#lang racket

(require "../stochastic.rkt" "riscv-machine.rkt")
(provide riscv-stochastic%)

(define riscv-stochastic%
  (class stochastic%
    (super-new)
    (inherit-field machine)
    (inherit pop-count32 pop-count64 correctness-cost-base)
    (override correctness-cost)

    (define bit (get-field bitwidth machine))

    ;; Count number of bits difference between x and y.
    (define (diff-cost x y)
      (pop-count32 (bitwise-xor (bitwise-and x #xffffffff) 
                                (bitwise-and y #xffffffff))))
    
    ;; Compute correctness cost.
    ;; state1: expected state
    ;; state2: actual state
    ;; constraint/live-out: program state that contains predicate
    ;;                      #t if the entry matters, #f otherwise.
    (define (correctness-cost state1 state2 constraint)
      ;; RISC-V only has registers and memory, no flags

      ;; Calculate register cost using correctness-cost-base
      ;; This method accounts for misalignment (e.g., if x1 of state1 = x2 of state2)
      (define cost-regs
        (correctness-cost-base (progstate-regs state1)
                               (progstate-regs state2)
                               (progstate-regs constraint)
                               diff-cost))

      ;; Calculate memory cost if memory is live
      (define cost-mem
        (if (progstate-memory constraint)
            (send (progstate-memory state1) correctness-cost
                  (progstate-memory state2) diff-cost bit)
            0))

      ;; Return total cost
      (+ cost-regs cost-mem))

    ))
           

