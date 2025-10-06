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
      ;; FIXED: Do NOT allow register misalignment for RISC-V.
      ;; The output must be in the exact register specified by live-out.
      ;; Previous implementation used correctness-cost-base which allowed
      ;; misalignment, causing incorrect optimizations to be accepted.
      (define regs1 (progstate-regs state1))
      (define regs2 (progstate-regs state2))
      (define regs-constraint (progstate-regs constraint))
      (define n (vector-length regs1))

      (define cost-regs
        (for/sum ([i (in-range n)])
          (define v (vector-ref regs-constraint i))
          (if v
              ;; Only compare the exact same register index - no misalignment!
              (diff-cost (vector-ref regs1 i) (vector-ref regs2 i))
              0)))

      ;; To calcuate correctness cost of memory object againt another,
      ;; simply call correctness-cost method of the memory object.
      (define cost-mem
        (if (progstate-memory constraint)
             (send (progstate-memory state1) correctness-cost
                   (progstate-memory state2) diff-cost bit)
             0))

      (+ cost-regs cost-mem))

    ))
           

