#lang s-exp rosette

(require "riscv-parser.rkt" "riscv-printer.rkt" "riscv-machine.rkt"
         "riscv-simulator-rosette.rkt" "riscv-simulator-racket.rkt"
         "../memory-racket.rkt")

(current-bitwidth 32)

(define parser (new riscv-parser%))
(define machine (new riscv-machine% [config 10]))  ; Use 10 registers
(define printer (new riscv-printer% [machine machine]))
(define sim-rosette (new riscv-simulator-rosette% [machine machine]))
(define sim-racket (new riscv-simulator-racket% [machine machine]))

;; Test comprehensive RV32I instruction set

(pretty-display "=== Testing Complete RV32I Instructions ===")
(pretty-display "")

;; Helper function to test an instruction
(define (test-instruction name code-str inputs expected-outputs)
  (define prog (send parser ir-from-string code-str))
  (define encoded (send printer encode prog))

  (pretty-display (format "Testing ~a: ~a" name code-str))

  (define all-pass #t)
  (for ([input inputs]
        [expected expected-outputs])
    (define state (progstate (list->vector input)
                             (new memory-racket% [get-fresh-val (lambda () 0)])))

    (define result-racket (send sim-racket interpret encoded state))
    (define result-rosette (send sim-rosette interpret encoded state))

    (define out-racket (vector-ref (progstate-regs result-racket)
                                   (caar expected)))  ;; Register index
    (define out-rosette (vector-ref (progstate-regs result-rosette)
                                    (caar expected)))
    (define expected-val (cdar expected))  ;; Expected value

    (define pass-racket (= out-racket expected-val))
    (define pass-rosette (or (equal? out-rosette expected-val)
                             (and (bv? out-rosette)
                                  (= (bitvector->integer out-rosette) expected-val))))

    (unless (and pass-racket pass-rosette)
      (set! all-pass #f)
      (pretty-display (format "  FAIL: input=~a, expected x~a=~a, got racket=~a rosette=~a"
                             input (caar expected) expected-val out-racket out-rosette))))

  (when all-pass
    (pretty-display "  PASS"))
  (pretty-display ""))

;; Test shift instructions
(pretty-display "--- Shift Instructions ---")

;; SRL - Shift Right Logical
(test-instruction "SRL"
  "srl x3, x1, x2"
  ;; Initial states: x0=0, x1=value, x2=shift
  '((0 -2147483648 4 0 0 0 0 0 0 0)    ; x1=0x80000000, x2=4
    (0 255 8 0 0 0 0 0 0 0)            ; x1=255, x2=8
    (0 -1 16 0 0 0 0 0 0 0))           ; x1=-1 (0xFFFFFFFF), x2=16
  ;; Expected: x3 = result
  '(((3 . 134217728))    ; 0x80000000 >>> 4 = 0x08000000
    ((3 . 0))            ; 255 >>> 8 = 0
    ((3 . 65535))))      ; 0xFFFFFFFF >>> 16 = 0x0000FFFF

;; SRA - Shift Right Arithmetic
(test-instruction "SRA"
  "sra x3, x1, x2"
  '((0 -2147483648 4 0 0 0 0 0 0 0)    ; x1=0x80000000, x2=4
    (0 255 8 0 0 0 0 0 0 0)            ; x1=255, x2=8
    (0 -256 4 0 0 0 0 0 0 0))          ; x1=-256, x2=4
  '(((3 . -134217728))   ; 0x80000000 >> 4 (arithmetic) = 0xF8000000
    ((3 . 0))            ; 255 >> 8 = 0
    ((3 . -16))))        ; -256 >> 4 = -16

;; SRLI - Shift Right Logical Immediate
(test-instruction "SRLI"
  "srli x3, x1, 8"
  '((0 -1 0 0 0 0 0 0 0 0)             ; x1=-1 (0xFFFFFFFF)
    (0 65280 0 0 0 0 0 0 0 0))         ; x1=0xFF00
  '(((3 . 16777215))     ; 0xFFFFFFFF >>> 8 = 0x00FFFFFF
    ((3 . 255))))        ; 0xFF00 >>> 8 = 0xFF

;; SRAI - Shift Right Arithmetic Immediate
(test-instruction "SRAI"
  "srai x3, x1, 8"
  '((0 -65536 0 0 0 0 0 0 0 0)         ; x1=-65536 (0xFFFF0000)
    (0 65280 0 0 0 0 0 0 0 0))         ; x1=0xFF00
  '(((3 . -256))         ; -65536 >> 8 = -256
    ((3 . 255))))        ; 0xFF00 >> 8 = 0xFF

;; Comparison instructions
(pretty-display "--- Comparison Instructions ---")

;; SLT - Set Less Than (signed)
(test-instruction "SLT"
  "slt x3, x1, x2"
  '((0 5 10 0 0 0 0 0 0 0)             ; 5 < 10
    (0 10 5 0 0 0 0 0 0 0)             ; 10 < 5
    (0 -5 5 0 0 0 0 0 0 0)             ; -5 < 5
    (0 5 -5 0 0 0 0 0 0 0))            ; 5 < -5
  '(((3 . 1))            ; true
    ((3 . 0))            ; false
    ((3 . 1))            ; true
    ((3 . 0))))          ; false

;; SLTU - Set Less Than Unsigned
(test-instruction "SLTU"
  "sltu x3, x1, x2"
  '((0 5 10 0 0 0 0 0 0 0)             ; 5 < 10
    (0 -1 5 0 0 0 0 0 0 0))            ; 0xFFFFFFFF < 5 (unsigned)
  '(((3 . 1))            ; true
    ((3 . 0))))          ; false (0xFFFFFFFF > 5 unsigned)

;; SLTI - Set Less Than Immediate (signed)
(test-instruction "SLTI"
  "slti x3, x1, -1"
  '((0 -5 0 0 0 0 0 0 0 0)             ; -5 < -1
    (0 0 0 0 0 0 0 0 0)                ; 0 < -1
    (0 5 0 0 0 0 0 0 0 0))             ; 5 < -1
  '(((3 . 1))            ; true
    ((3 . 0))            ; false
    ((3 . 0))))          ; false

;; SLTIU - Set Less Than Immediate Unsigned
(test-instruction "SLTIU"
  "sltiu x3, x1, 1"
  '((0 0 0 0 0 0 0 0 0 0)              ; 0 < 1
    (0 1 0 0 0 0 0 0 0 0)              ; 1 < 1
    (0 -1 0 0 0 0 0 0 0 0))            ; 0xFFFFFFFF < 1 (unsigned)
  '(((3 . 1))            ; true
    ((3 . 0))            ; false
    ((3 . 0))))          ; false

;; AUIPC - Add Upper Immediate to PC
(pretty-display "--- AUIPC Instruction ---")

;; Note: AUIPC adds imm<<12 to the current PC
;; PC starts at 0 and increments by 4 for each instruction
(test-instruction "AUIPC single"
  "auipc x1, 1"  ; PC=0, x1 = 0 + (1 << 12) = 4096
  '((0 0 0 0 0 0 0 0 0 0))
  '(((1 . 4096))))

;; Test AUIPC in a sequence - parse instructions separately
(define prog-auipc-1 (send parser ir-from-string "addi x0, x0, 0"))
(define prog-auipc-2 (send parser ir-from-string "auipc x2, 1"))
(define prog-auipc-3 (send parser ir-from-string "addi x0, x0, 0"))
(define prog-auipc-4 (send parser ir-from-string "auipc x3, -1"))
(define prog-auipc (vector-append prog-auipc-1 prog-auipc-2 prog-auipc-3 prog-auipc-4))
(define encoded-auipc (send printer encode prog-auipc))
(pretty-display "Testing AUIPC sequence: nop; auipc x2, 1; nop; auipc x3, -1")

(define state-auipc (progstate (make-vector 10 0)
                               (new memory-racket% [get-fresh-val (lambda () 0)])))

(define result-auipc (send sim-racket interpret encoded-auipc state-auipc))
;; PC=0: nop
;; PC=4: auipc x2, 1 -> x2 = 4 + 4096 = 4100
;; PC=8: nop
;; PC=12: auipc x3, -1 -> x3 = 12 + (-4096) = -4084

(define x2-val (vector-ref (progstate-regs result-auipc) 2))
(define x3-val (vector-ref (progstate-regs result-auipc) 3))

(pretty-display (format "  x2 (PC=4 + 1<<12) = ~a, expected 4100: ~a"
                       x2-val (if (= x2-val 4100) "PASS" "FAIL")))
(pretty-display (format "  x3 (PC=12 + -1<<12) = ~a, expected -4084: ~a"
                       x3-val (if (= x3-val -4084) "PASS" "FAIL")))
(pretty-display "")

;; Test combining instructions
(pretty-display "--- Combined Instruction Tests ---")

;; Test: Load address using AUIPC + ADDI (common pattern)
(define prog-addr-1 (send parser ir-from-string "auipc x1, 1"))
(define prog-addr-2 (send parser ir-from-string "addi x2, x1, -8"))
(define prog-addr (vector-append prog-addr-1 prog-addr-2))
(define encoded-addr (send printer encode prog-addr))
(pretty-display "Testing address computation: auipc x1, 1; addi x2, x1, -8")

(define state-addr (progstate (make-vector 10 0)
                              (new memory-racket% [get-fresh-val (lambda () 0)])))
(define result-addr (send sim-racket interpret encoded-addr state-addr))

;; PC=0: auipc x1, 1 -> x1 = 0 + 4096 = 4096
;; PC=4: addi x2, x1, -8 -> x2 = 4096 - 8 = 4088
(define x1-addr (vector-ref (progstate-regs result-addr) 1))
(define x2-addr (vector-ref (progstate-regs result-addr) 2))

(pretty-display (format "  x1 = ~a, expected 4096: ~a"
                       x1-addr (if (= x1-addr 4096) "PASS" "FAIL")))
(pretty-display (format "  x2 = ~a, expected 4088: ~a"
                       x2-addr (if (= x2-addr 4088) "PASS" "FAIL")))

(pretty-display "")
(pretty-display "=== All RV32I Tests Complete ===")