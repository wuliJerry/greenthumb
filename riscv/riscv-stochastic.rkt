#lang racket

(require "../stochastic.rkt"
         "../inst.rkt"
         "../machine.rkt"
         "riscv-machine.rkt")
(provide riscv-stochastic%)

(define riscv-stochastic%
  (class stochastic%
    (super-new)
    (inherit-field machine stat mutate-dist live-in)
    (inherit random-args-from-op mutate pop-count32 pop-count64 correctness-cost-base inst-copy-with-op inst-copy-with-args)
    (override correctness-cost)

    ;; Set mutation distribution - controls how often each mutation type is chosen
    (set! mutate-dist
          #hash((opcode . 2) (operand . 1) (swap . 1) (instruction . 1)))

    (define bit (get-field bitwidth machine))
    (define debug (get-field debug machine))

    ;; Mutate opcode - RISC-V specific implementation
    ;; index: index to be mutated
    ;; entry: instruction at index in p
    ;; p: entire program
    (define/override (mutate-opcode index entry p)
      (define opcode-id (inst-op entry))
      (define opcode-name (send machine get-opcode-name opcode-id))
      (define nop-id (get-field nop-id machine))
      (define op-types
        (filter identity (for/list ([op opcode-id] [index (in-naturals)])
                                   (and (>= op 0) index))))
      (define op-type (if (empty? op-types) 0 (random-from-list op-types)))
      (define checks (remove op-type (range (vector-length opcode-id))))
      (define class
        ;; Filter out nop from the class of possible mutations
        (filter
         (lambda (x)
           (and (not (equal? x nop-id))  ; Exclude nop
                (for/and ([index checks])
                         (= (vector-ref x index) (vector-ref opcode-id index)))))
        (send machine get-class-opcodes opcode-id)))

      (when debug
            (pretty-display (format " >> mutate opcode"))
            (pretty-display (format " --> org = ~a ~a" opcode-name opcode-id))
            (pretty-display (format " --> op-type = ~a" op-type))
            (pretty-display (format " --> class = ~a" class)))
      (cond
       [class
        (define new-opcode-id (random-from-list-ex class opcode-id))
        (define new-p (vector-copy p))
        (when debug
              (pretty-display (format " --> new = ~a ~a"
                                     (send machine get-opcode-name new-opcode-id)
                                     new-opcode-id)))
        (vector-set! new-p index (inst-copy-with-op entry new-opcode-id))
        (send stat inc-propose `opcode)
        new-p]
       [else (mutate p)]))

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
      ;; progstate-regs is a vector. We can use provided method correctness-cost-base
      ;; to compute correctness cost of a vector against another vector.
      ;; This method takes into account of misalignment.
      ;; For example, if r0 of state1 = r1 of state2, the cost will be quite low.
      (define cost-regs
        (correctness-cost-base (progstate-regs state1)
                               (progstate-regs state2)
                               (progstate-regs constraint)
                               diff-cost))

      ;; To calcuate correctness cost of memory object againt another,
      ;; simply call correctness-cost method of the memory object.
      (define cost-mem
        (if (progstate-memory constraint)
             (send (progstate-memory state1) correctness-cost
                   (progstate-memory state2) diff-cost bit)
             0))

      (+ cost-regs cost-mem))

    ))
           

