#lang racket

(require "../machine.rkt" "../special.rkt")

(provide riscv-machine%  (all-defined-out))

;;;;;;;;;;;;;;;;;;;;; program state macro ;;;;;;;;;;;;;;;;;;;;;;;;
;; This is just for convenience.
(define-syntax-rule
  (progstate regs memory)
  (vector regs memory))

(define-syntax-rule (progstate-regs x) (vector-ref x 0))
(define-syntax-rule (progstate-memory x) (vector-ref x 1))

(define-syntax-rule (set-progstate-regs! x v) (vector-set! x 0 v))
(define-syntax-rule (set-progstate-memory! x v) (vector-set! x 1 v))

(define riscv-machine%
  (class machine%
    (super-new)
    (inherit-field bitwidth random-input-bits config)
    (inherit init-machine-description define-instruction-class finalize-machine-description
             define-progstate-type define-arg-type
             update-progstate-ins kill-outs)
    (override get-constructor progstate-structure)
    (public uses-memory?)

    (define (get-constructor) riscv-machine%)

    ;; Check if an instruction uses memory (load/store)
    ;; Our RISC-V subset has no memory operations, so always return #f
    (define (uses-memory? inst) #f)

    ;; RISC-V RV32I uses 32-bit registers
    (unless bitwidth (set! bitwidth 32))
    (set! random-input-bits bitwidth)

    ;;;;;;;;;;;;;;;;;;;;; program state ;;;;;;;;;;;;;;;;;;;;;;;;

    (define (progstate-structure)
      ;; RISC-V program state has registers and memory
      ;; config = number of registers
      (progstate (for/vector ([i config]) 'reg)
                 (get-memory-type)))

    (define-progstate-type
      'reg
      #:get (lambda (state arg) (vector-ref (progstate-regs state) arg))
      #:set (lambda (state arg val) (vector-set! (progstate-regs state) arg val)))

    (define-progstate-type
      (get-memory-type)
      #:get (lambda (state) (progstate-memory state))
      #:set (lambda (state val) (set-progstate-memory! state val)))

    ;;;;;;;;;;;;;;;;;;;;; instruction classes ;;;;;;;;;;;;;;;;;;;;;;;;
    (define-arg-type 'reg (lambda (config) (range config)))
    (define-arg-type 'const (lambda (config) '(0 1 -1 -2 -8)))
    ;; For RV32: shift amount should be in range 0-31, using a few key values to reduce search space
    (define-arg-type 'shamt (lambda (config) '(1 8 16 31)))

    ;; Inform GreenThumb how many opcodes there are in one instruction.
    (init-machine-description 1)

    (define-instruction-class 'nop '(nop))

    ;; R-type instructions with commutative operations
    ;; ADD rd, rs1, rs2 - rd = rs1 + rs2
    ;; MUL rd, rs1, rs2 - rd = (rs1 * rs2)[31:0]
    ;; MULH rd, rs1, rs2 - rd = (rs1 * rs2)[63:32] (signed × signed)
    ;; MULHU rd, rs1, rs2 - rd = (rs1 * rs2)[63:32] (unsigned × unsigned)
    (define-instruction-class 'rrr-commute '(add mul mulh mulhu)
      #:args '(reg reg reg) #:ins '(1 2) #:outs '(0) #:commute '(1 . 2))

    ;; R-type non-commutative instructions
    ;; SUB rd, rs1, rs2 - rd = rs1 - rs2
    ;; MULHSU rd, rs1, rs2 - rd = (rs1 * rs2)[63:32] (signed × unsigned)
    ;; DIV rd, rs1, rs2 - rd = rs1 / rs2 (signed division)
    ;; DIVU rd, rs1, rs2 - rd = rs1 / rs2 (unsigned division)
    ;; REM rd, rs1, rs2 - rd = rs1 % rs2 (signed remainder)
    ;; REMU rd, rs1, rs2 - rd = rs1 % rs2 (unsigned remainder)
    (define-instruction-class 'rrr '(sub mulhsu div divu rem remu)
      #:args '(reg reg reg) #:ins '(1 2) #:outs '(0))

    ;; R-type shift instructions with register shift amount
    ;; SLL rd, rs1, rs2 - rd = rs1 << rs2[4:0]
    ;; SRL rd, rs1, rs2 - rd = rs1 >> rs2[4:0] (logical)
    ;; SRA rd, rs1, rs2 - rd = rs1 >> rs2[4:0] (arithmetic)
    (define-instruction-class 'rrr-shift '(sll srl sra)
      #:args '(reg reg reg) #:ins '(1 2) #:outs '(0))

    ;; I-type arithmetic instructions with immediate
    ;; ADDI rd, rs1, imm - rd = rs1 + imm
    (define-instruction-class 'rri '(addi)
      #:args '(reg reg const) #:ins '(1) #:outs '(0))

    ;; I-type shift instructions with immediate shift amount
    ;; SLLI rd, rs1, shamt - rd = rs1 << shamt
    ;; SRLI rd, rs1, shamt - rd = rs1 >> shamt (logical)
    ;; SRAI rd, rs1, shamt - rd = rs1 >> shamt (arithmetic)
    (define-instruction-class 'rri-shift '(slli srli srai)
      #:args '(reg reg shamt) #:ins '(1) #:outs '(0))

    ;; I-type logical instructions with commutative operations
    ;; ANDI rd, rs1, imm - rd = rs1 & imm
    ;; ORI rd, rs1, imm - rd = rs1 | imm
    ;; XORI rd, rs1, imm - rd = rs1 ^ imm
    (define-instruction-class 'rri-logic '(andi ori xori)
      #:args '(reg reg const) #:ins '(1) #:outs '(0))

    ;; R-type logical instructions with commutative operations
    ;; AND rd, rs1, rs2 - rd = rs1 & rs2
    ;; OR rd, rs1, rs2 - rd = rs1 | rs2
    ;; XOR rd, rs1, rs2 - rd = rs1 ^ rs2
    (define-instruction-class 'rrr-logic '(and or xor)
      #:args '(reg reg reg) #:ins '(1 2) #:outs '(0) #:commute '(1 . 2))

    ;; R-type comparison instructions
    ;; SLT rd, rs1, rs2 - rd = (rs1 < rs2) ? 1 : 0 (signed)
    ;; SLTU rd, rs1, rs2 - rd = (rs1 < rs2) ? 1 : 0 (unsigned)
    (define-instruction-class 'rrr-compare '(slt sltu)
      #:args '(reg reg reg) #:ins '(1 2) #:outs '(0))

    ;; I-type comparison instructions
    ;; SLTI rd, rs1, imm - rd = (rs1 < imm) ? 1 : 0 (signed)
    ;; SLTIU rd, rs1, imm - rd = (rs1 < imm) ? 1 : 0 (unsigned)
    (define-instruction-class 'rri-compare '(slti sltiu)
      #:args '(reg reg const) #:ins '(1) #:outs '(0))

    ;; U-type instruction for large immediates
    ;; LUI rd, imm - rd = imm << 12 (load upper immediate)
    (define-instruction-class 'ri-upper '(lui)
      #:args '(reg const) #:ins '() #:outs '(0))

    (finalize-machine-description)

    ;; No load/store instructions in this subset, so we don't need to override
    ;; update-progstate-ins-load and update-progstate-ins-store

    ))
      

