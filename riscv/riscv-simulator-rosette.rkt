#lang s-exp rosette

(require "../simulator-rosette.rkt" "../ops-rosette.rkt" "../inst.rkt" "riscv-machine.rkt")
(provide riscv-simulator-rosette%)

(define riscv-simulator-rosette%
  (class simulator-rosette%
    (super-new)
    (init-field machine)
    (override interpret performance-cost get-constructor)

    (define (get-constructor) riscv-simulator-rosette%)

    (define bit (get-field bitwidth machine))
    (define nop-id (get-field nop-id machine))
    (define opcodes (get-field opcodes machine))

    ;;;;;;;;;;;;;;;;;;;;;;;;;;; Helper functions ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; In Rosette 4.1, bvadd/bvsub/bvmul/bvand/bvor/bvxor are built-in for bitvectors.
    ;; They require bitvector arguments, so we wrap them to convert integer immediates.

    ;; Helper to ensure value is a bitvector
    (define (ensure-bv x)
      (if (bv? x) x (bv x bit)))

    ;; Wrapper for bitvector binary operations that may receive integer immediates
    (define-syntax-rule (bv-binop rosette-op)
      (lambda (x y) (rosette-op (ensure-bv x) (ensure-bv y))))

    ;; Shift operations use different built-ins
    (define (bv-shl x y) (bvshl (ensure-bv x) (ensure-bv y)))
    (define (bv-ashr x y) (bvashr (ensure-bv x) (ensure-bv y)))
    (define (bv-lshr x y) (bvlshr (ensure-bv x) (ensure-bv y)))

    ;; Binary operations - use Rosette's built-in bitvector operations
    ;; Note: We don't redefine bvadd/bvsub etc. - we use them directly via wrappers
    (define my-bvadd  (bv-binop bvadd))
    (define my-bvsub  (bv-binop bvsub))
    (define my-bvmul  (bv-binop bvmul))
    (define my-bvand  (bv-binop bvand))
    (define my-bvor   (bv-binop bvor))
    (define my-bvxor  (bv-binop bvxor))
    (define my-bvshl  bv-shl)
    (define my-bvshr  bv-ashr)   ;; signed shift right (arithmetic)
    (define my-bvushr bv-lshr)   ;; unsigned shift right (logical)
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;; Required methods ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Interpret a given program from a given state.
    ;; 'program' is a vector of 'inst' struct.
    ;; 'ref' is optional. When given, it is an output program state returned from spec.
    ;; We can assert something from ref to terminate interpret early.
    ;; This can help prune the search space.
    (define (interpret program state [ref #f])
      ;; Copy vector before modifying it because vector is mutable
      (define regs-out (vector-copy (progstate-regs state)))
      ;; Set mem = #f for now (we don't have load/store in this subset)
      (define mem #f)

      ;; Call this function when we want to reference mem
      (define (prepare-mem)
        (unless mem
          (set! mem (send* (progstate-memory state) clone (and ref (progstate-memory ref))))))

      (define (interpret-inst my-inst)
        (define op (inst-op my-inst))
        (define op-name (vector-ref opcodes op))
        (define args (inst-args my-inst))

        ;; R-type: rd = rs1 op rs2
        (define (rrr f)
          (define d (vector-ref args 0))
          (define a (vector-ref args 1))
          (define b (vector-ref args 2))
          (define val (f (vector-ref regs-out a) (vector-ref regs-out b)))
          (vector-set! regs-out d val))

        ;; I-type: rd = rs1 op imm
        (define (rri f)
          (define d (vector-ref args 0))
          (define a (vector-ref args 1))
          (define imm (vector-ref args 2))
          (define val (f (vector-ref regs-out a) imm))
          (vector-set! regs-out d val))

        ;; RR-type (unary): rd = op(rs)
        (define (rr f)
          (define d (vector-ref args 0))
          (define a (vector-ref args 1))
          (define val (f (vector-ref regs-out a)))
          (vector-set! regs-out d val))

        ;; RI-type (upper immediate): rd = imm << 12
        (define (ri-upper)
          (define d (vector-ref args 0))
          (define imm (vector-ref args 1))
          (define val (bvshl (ensure-bv imm) (ensure-bv 12)))
          (vector-set! regs-out d val))

        (cond
         [(equal? op-name 'nop)   (void)]
         ;; Arithmetic R-type
         [(equal? op-name 'add)   (rrr my-bvadd)]
         [(equal? op-name 'sub)   (rrr my-bvsub)]
         [(equal? op-name 'mul)   (rrr my-bvmul)]
         ;; Shift R-type
         [(equal? op-name 'sll)   (rrr my-bvshl)]
         [(equal? op-name 'srl)   (rrr my-bvushr)]
         [(equal? op-name 'sra)   (rrr my-bvshr)]
         ;; Logical R-type
         [(equal? op-name 'and)   (rrr my-bvand)]
         [(equal? op-name 'or)    (rrr my-bvor)]
         [(equal? op-name 'xor)   (rrr my-bvxor)]
         ;; Comparison R-type
         [(equal? op-name 'slt)   (rrr (lambda (x y) (if (bvslt (ensure-bv x) (ensure-bv y)) (bv 1 bit) (bv 0 bit))))]
         [(equal? op-name 'sltu)  (rrr (lambda (x y) (if (bvult (ensure-bv x) (ensure-bv y)) (bv 1 bit) (bv 0 bit))))]
         ;; Arithmetic I-type
         [(equal? op-name 'addi)  (rri my-bvadd)]
         ;; Shift I-type
         [(equal? op-name 'slli)  (rri my-bvshl)]
         [(equal? op-name 'srli)  (rri my-bvushr)]
         [(equal? op-name 'srai)  (rri my-bvshr)]
         ;; Logical I-type
         [(equal? op-name 'andi)  (rri my-bvand)]
         [(equal? op-name 'ori)   (rri my-bvor)]
         [(equal? op-name 'xori)  (rri my-bvxor)]
         ;; Comparison I-type
         [(equal? op-name 'slti)  (rri (lambda (x y) (if (bvslt (ensure-bv x) (ensure-bv y)) (bv 1 bit) (bv 0 bit))))]
         [(equal? op-name 'sltiu) (rri (lambda (x y) (if (bvult (ensure-bv x) (ensure-bv y)) (bv 1 bit) (bv 0 bit))))]
         ;; Unary pseudo-instructions
         [(equal? op-name 'neg)   (rr (lambda (x) (bvneg (ensure-bv x))))]
         [(equal? op-name 'not)   (rr (lambda (x) (bvnot (ensure-bv x))))]
         [(equal? op-name 'seqz)  (rr (lambda (x) (if (bveq (ensure-bv x) (bv 0 bit)) (bv 1 bit) (bv 0 bit))))]
         [(equal? op-name 'snez)  (rr (lambda (x) (if (bveq (ensure-bv x) (bv 0 bit)) (bv 0 bit) (bv 1 bit))))]
         ;; Upper immediate
         [(equal? op-name 'lui)   (ri-upper)]
         [else (assert #f (format "simulator: undefined instruction ~a" op-name))]))
      ;; end interpret-inst

      (for ([x program]) (interpret-inst x))

      ;; If mem = #f (never reference mem), set mem before returning
      (unless mem (set! mem (progstate-memory state)))
      (progstate regs-out mem)
      )

    ;; Estimate performance cost of a given program.
    ;; Uses realistic latency-based cost model for RISC-V:
    ;; - Simple ALU (add/sub/logic/comp/imm/lui): 1 cycle
    ;; - Shifts (imm): 1 cycle
    ;; - Shifts (reg): 1 cycle (conservative, can be 1-2)
    ;; - mul: 4 cycles
    (define (performance-cost program)
      (define cost 0)
      (for ([x program])
        (define op (inst-op x))
        (unless (= op nop-id)
          (define op-name (vector-ref opcodes op))
          (define inst-cost
            (cond
             ;; Multiply: 4 cycles
             [(equal? op-name 'mul) 4]
             ;; All other instructions: 1 cycle
             ;; This includes: add, sub, and, or, xor, slt, sltu,
             ;;                addi, andi, ori, xori, slti, sltiu,
             ;;                sll, srl, sra, slli, srli, srai,
             ;;                neg, not, seqz, snez, lui
             [else 1]))
          (set! cost (+ cost inst-cost))))
      cost)

    ))

