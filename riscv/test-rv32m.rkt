#lang s-exp rosette

(require "riscv-parser.rkt" "riscv-printer.rkt" "riscv-machine.rkt"
         "riscv-simulator-rosette.rkt" "riscv-simulator-racket.rkt"
         "../memory-racket.rkt" "../validator.rkt")

(current-bitwidth 32)

;; Test RV32M instructions
(define parser (new riscv-parser%))
(define machine (new riscv-machine% [config 10]))
(define printer (new riscv-printer% [machine machine]))
(define sim-rosette (new riscv-simulator-rosette% [machine machine]))
(define sim-racket (new riscv-simulator-racket% [machine machine]))

;; Helper to create state
(define (make-state . reg-values)
  (define regs (make-vector 10 0))
  (for ([val reg-values] [i (length reg-values)])
    (vector-set! regs i val))
  (progstate regs (new memory-racket% [get-fresh-val (get-rand-func 4)])))

(pretty-display "=== Testing RV32M Instructions ===\n")

;; Test 1: MULH (signed multiplication high)
(pretty-display "Test 1: MULH - Signed multiplication high")
(define code1 (send parser ir-from-string "mulh x0, x1, x2"))
(send printer print-syntax code1)
(define encoded1 (send printer encode code1))
(define input1 (make-state 0 1000000 2000000))  ; Large positive numbers
(pretty-display (format "Input: x1=~a, x2=~a" 1000000 2000000))
(define output1 (send sim-rosette interpret encoded1 input1))
(pretty-display (format "Expected: ~a (upper 32 bits of ~a)"
                       (arithmetic-shift (* 1000000 2000000) -32)
                       (* 1000000 2000000)))
(pretty-display (format "Result: x0=~a\n" (vector-ref (progstate-regs output1) 0)))

;; Test 2: MULHU (unsigned multiplication high)
(pretty-display "Test 2: MULHU - Unsigned multiplication high")
(define code2 (send parser ir-from-string "mulhu x0, x1, x2"))
(send printer print-syntax code2)
(define encoded2 (send printer encode code2))
(define input2 (make-state 0 -1 -1))  ; Will be treated as large unsigned
(pretty-display (format "Input: x1=~a (0x~x), x2=~a (0x~x)" -1 (sub1 (expt 2 32)) -1 (sub1 (expt 2 32))))
(define output2 (send sim-rosette interpret encoded2 input2))
(pretty-display (format "Result: x0=~a\n" (vector-ref (progstate-regs output2) 0)))

;; Test 3: MULHSU (signed×unsigned multiplication high)
(pretty-display "Test 3: MULHSU - Signed×Unsigned multiplication high")
(define code3 (send parser ir-from-string "mulhsu x0, x1, x2"))
(send printer print-syntax code3)
(define encoded3 (send printer encode code3))
(define input3 (make-state 0 -100 1000))  ; Negative × positive
(pretty-display (format "Input: x1=~a (signed), x2=~a (unsigned)" -100 1000))
(define output3 (send sim-rosette interpret encoded3 input3))
(pretty-display (format "Result: x0=~a\n" (vector-ref (progstate-regs output3) 0)))

;; Test 4: DIV (signed division)
(pretty-display "Test 4: DIV - Signed division")
(define code4 (send parser ir-from-string "div x0, x1, x2"))
(send printer print-syntax code4)
(define encoded4 (send printer encode code4))
(define input4 (make-state 0 -100 3))
(pretty-display (format "Input: x1=~a, x2=~a" -100 3))
(define output4 (send sim-racket interpret encoded4 input4))
(pretty-display (format "Result: x0=~a (expected ~a)\n"
                       (vector-ref (progstate-regs output4) 0)
                       (quotient -100 3)))

;; Test 5: DIVU (unsigned division)
(pretty-display "Test 5: DIVU - Unsigned division")
(define code5 (send parser ir-from-string "divu x0, x1, x2"))
(send printer print-syntax code5)
(define encoded5 (send printer encode code5))
(define input5 (make-state 0 100 3))
(pretty-display (format "Input: x1=~a, x2=~a" 100 3))
(define output5 (send sim-racket interpret encoded5 input5))
(pretty-display (format "Result: x0=~a (expected ~a)\n"
                       (vector-ref (progstate-regs output5) 0)
                       (quotient 100 3)))

;; Test 6: REM (signed remainder)
(pretty-display "Test 6: REM - Signed remainder")
(define code6 (send parser ir-from-string "rem x0, x1, x2"))
(send printer print-syntax code6)
(define encoded6 (send printer encode code6))
(define input6 (make-state 0 -100 7))
(pretty-display (format "Input: x1=~a, x2=~a" -100 7))
(define output6 (send sim-racket interpret encoded6 input6))
(pretty-display (format "Result: x0=~a (expected ~a)\n"
                       (vector-ref (progstate-regs output6) 0)
                       (remainder -100 7)))

;; Test 7: REMU (unsigned remainder)
(pretty-display "Test 7: REMU - Unsigned remainder")
(define code7 (send parser ir-from-string "remu x0, x1, x2"))
(send printer print-syntax code7)
(define encoded7 (send printer encode code7))
(define input7 (make-state 0 100 7))
(pretty-display (format "Input: x1=~a, x2=~a" 100 7))
(define output7 (send sim-racket interpret encoded7 input7))
(pretty-display (format "Result: x0=~a (expected ~a)\n"
                       (vector-ref (progstate-regs output7) 0)
                       (remainder 100 7)))

;; Test division by zero
(pretty-display "Test 8: Division by zero cases")
(define code-div-zero (send parser ir-from-string "div x0, x1, x2"))
(define encoded-div-zero (send printer encode code-div-zero))
(define input-div-zero (make-state 0 42 0))
(pretty-display "DIV 42/0:")
(define output-div-zero (send sim-racket interpret encoded-div-zero input-div-zero))
(pretty-display (format "Result: x0=~a (expected -1)"
                       (vector-ref (progstate-regs output-div-zero) 0)))

(define code-divu-zero (send parser ir-from-string "divu x0, x1, x2"))
(define encoded-divu-zero (send printer encode code-divu-zero))
(pretty-display "DIVU 42/0:")
(define output-divu-zero (send sim-racket interpret encoded-divu-zero input-div-zero))
(pretty-display (format "Result: x0=~a (expected 0xffffffff)"
                       (vector-ref (progstate-regs output-divu-zero) 0)))

(pretty-display "\n=== All RV32M instruction tests complete ===")