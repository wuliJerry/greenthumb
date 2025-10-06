#lang racket

(require "../simulator-racket.rkt" "../ops-racket.rkt" "../inst.rkt" "riscv-machine.rkt")
(provide riscv-simulator-racket%)

(define riscv-simulator-racket%
  (class simulator-racket%
    (super-new)
    (init-field machine)
    (override interpret performance-cost get-constructor)

    (define (get-constructor) riscv-simulator-racket%)

    (define bit (get-field bitwidth machine))
    (define nop-id (get-field nop-id machine))
    (define opcodes (get-field opcodes machine))

    ;;;;;;;;;;;;;;;;;;;;;;;;;;; Helper functions ;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Truncate x to 'bit' bits and convert to signed number.
    ;; For Racket simulator (concrete execution), we use simple arithmetic operations.
    (define-syntax-rule (finitize-bit x) (finitize x bit))
    (define-syntax-rule (bvop op)
      (lambda (x y) (finitize-bit (op x y))))
    (define (shl a b) (<< a b bit))
    (define (ushr a b) (>>> a b bit))

    ;; Multiplication high functions (from ARM implementation)
    (define (mulh-signed x y) (smmul x y bit))
    (define (mulh-unsigned x y) (ummul x y bit))

    ;; MULHSU: signed × unsigned multiplication high
    (define (mulhsu x y)
      ;; Sign extend x to 64 bits, zero extend y to 64 bits
      (define x-64 (if (< x 0)
                       (bitwise-ior x (arithmetic-shift -1 bit))
                       x))
      (define y-64 (bitwise-and y (sub1 (arithmetic-shift 1 bit))))
      (finitize-bit (arithmetic-shift (* x-64 y-64) (- bit))))

    ;; Division with RISC-V special cases
    (define (div-signed x y)
      (cond
        ;; Division by zero: return -1
        [(= y 0) -1]
        ;; Overflow: most negative / -1 = most negative
        [(and (= x (arithmetic-shift -1 (sub1 bit)))
              (= y -1))
         x]
        [else (finitize-bit (quotient x y))]))

    (define (div-unsigned x y)
      (if (= y 0)
          (sub1 (arithmetic-shift 1 bit))  ; All 1s for division by zero
          (let* ([ux (if (< x 0) (+ x (arithmetic-shift 1 bit)) x)]
                 [uy (if (< y 0) (+ y (arithmetic-shift 1 bit)) y)])
            (finitize-bit (quotient ux uy)))))

    ;; Remainder with RISC-V special cases
    (define (rem-signed x y)
      (cond
        ;; Division by zero: return dividend
        [(= y 0) x]
        ;; Overflow case: remainder is 0
        [(and (= x (arithmetic-shift -1 (sub1 bit)))
              (= y -1))
         0]
        [else (finitize-bit (remainder x y))]))

    (define (rem-unsigned x y)
      (if (= y 0)
          x  ; Return dividend for division by zero
          (let* ([ux (if (< x 0) (+ x (arithmetic-shift 1 bit)) x)]
                 [uy (if (< y 0) (+ y (arithmetic-shift 1 bit)) y)])
            (finitize-bit (remainder ux uy)))))

    ;; Binary operations
    (define my-bvadd  (bvop +))
    (define my-bvsub  (bvop -))
    (define my-bvmul  (bvop *))
    (define my-bvand  (bvop bitwise-and))
    (define my-bvor   (bvop bitwise-ior))
    (define my-bvxor  (bvop bitwise-xor))
    (define my-bvshl  (bvop shl))
    (define my-bvshr  (bvop >>))   ;; signed shift right (arithmetic)
    (define my-bvushr (bvop ushr)) ;; unsigned shift right (logical)

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
      ;; Track program counter for AUIPC (each instruction is 4 bytes)
      (define pc 0)

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
          ;; Only set if not x0 (register 0)
          (unless (= d 0) (vector-set! regs-out d val)))

        ;; I-type: rd = rs1 op imm
        (define (rri f)
          (define d (vector-ref args 0))
          (define a (vector-ref args 1))
          (define imm (vector-ref args 2))
          (define val (f (vector-ref regs-out a) imm))
          ;; Only set if not x0 (register 0)
          (unless (= d 0) (vector-set! regs-out d val)))

        ;; RR-type (unary): rd = op(rs)
        (define (rr f)
          (define d (vector-ref args 0))
          (define a (vector-ref args 1))
          (define val (f (vector-ref regs-out a)))
          ;; Only set if not x0 (register 0)
          (unless (= d 0) (vector-set! regs-out d val)))

        ;; RI-type (upper immediate): rd = imm << 12
        (define (ri-upper)
          (define d (vector-ref args 0))
          (define imm (vector-ref args 1))
          (define val (finitize-bit (<< imm 12 bit)))
          ;; Only set if not x0 (register 0)
          (unless (= d 0) (vector-set! regs-out d val)))

        ;; Comparison helper
        (define (slt-signed x y) (if (< x y) 1 0))
        (define (slt-unsigned x y)
          (define ux (if (< x 0) (+ x (arithmetic-shift 1 bit)) x))
          (define uy (if (< y 0) (+ y (arithmetic-shift 1 bit)) y))
          (if (< ux uy) 1 0))

        (cond
         [(equal? op-name 'nop)   (void)]
         ;; Arithmetic R-type
         [(equal? op-name 'add)   (rrr my-bvadd)]
         [(equal? op-name 'sub)   (rrr my-bvsub)]
         [(equal? op-name 'mul)   (rrr my-bvmul)]
         ;; RV32M multiplication high
         [(equal? op-name 'mulh)  (rrr mulh-signed)]
         [(equal? op-name 'mulhu) (rrr mulh-unsigned)]
         [(equal? op-name 'mulhsu)(rrr mulhsu)]
         ;; RV32M division and remainder
         [(equal? op-name 'div)   (rrr div-signed)]
         [(equal? op-name 'divu)  (rrr div-unsigned)]
         [(equal? op-name 'rem)   (rrr rem-signed)]
         [(equal? op-name 'remu)  (rrr rem-unsigned)]
         ;; Shift R-type
         [(equal? op-name 'sll)   (rrr my-bvshl)]
         [(equal? op-name 'srl)   (rrr my-bvushr)]
         [(equal? op-name 'sra)   (rrr my-bvshr)]
         ;; Logical R-type
         [(equal? op-name 'and)   (rrr my-bvand)]
         [(equal? op-name 'or)    (rrr my-bvor)]
         [(equal? op-name 'xor)   (rrr my-bvxor)]
         ;; Comparison R-type
         [(equal? op-name 'slt)   (rrr slt-signed)]
         [(equal? op-name 'sltu)  (rrr slt-unsigned)]
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
         [(equal? op-name 'slti)  (rri slt-signed)]
         [(equal? op-name 'sltiu) (rri slt-unsigned)]
         ;; Upper immediate
         [(equal? op-name 'lui)   (ri-upper)]
         ;; AUIPC - Add Upper Immediate to PC
         [(equal? op-name 'auipc)
          (define d (vector-ref args 0))
          (define imm (vector-ref args 1))
          ;; rd = PC + (imm << 12)
          (define val (finitize-bit (+ pc (<< imm 12 bit))))
          (unless (= d 0) (vector-set! regs-out d val))]
         [else (raise (format "simulator: undefined instruction ~a" op-name))]))
      ;; end interpret-inst

      (for ([x program] [i (in-naturals)])
        (set! pc (* i 4))  ;; Update PC before each instruction (4 bytes per instruction)
        (interpret-inst x))

      ;; Ensure x0 is always 0
      (vector-set! regs-out 0 0)

      ;; If mem = #f (never reference mem), set mem before returning
      (unless mem (set! mem (progstate-memory state)))
      (progstate regs-out mem)
      )

    ;; Estimate performance cost of a given program.
    (define (performance-cost program)
      (define cost 0)
      (for ([x program])
        ;; Count all instructions except nops
        (unless (= (inst-op x) nop-id)
          (set! cost (add1 cost))))
      cost)

    ))
