#lang s-exp rosette

(require "riscv-parser.rkt" "riscv-printer.rkt" "riscv-machine.rkt"
         "riscv-simulator-rosette.rkt" "riscv-simulator-racket.rkt"
         "../memory-racket.rkt" "../validator.rkt")

(current-bitwidth 32)

;; Test a program file
(define parser (new riscv-parser%))
(define machine (new riscv-machine% [config 10]))
(define printer (new riscv-printer% [machine machine]))

(pretty-display "=== Testing programs/negate.s ===")
(define code1 (send parser ir-from-file "programs/negate.s"))
(pretty-display "Source:")
(send printer print-syntax code1)

(define encoded-code1 (send printer encode code1))
(define simulator1 (new riscv-simulator-rosette% [machine machine]))

;; Create test input: x1 = 42
(define input-state1
  (progstate (vector 0 42 0 0 0 0 0 0 0 0)
             (new memory-racket% [get-fresh-val (get-rand-func 4)])))

(pretty-display "\nInput state (x1=42):")
(pretty-display (progstate-regs input-state1))

(define output-state1 (send simulator1 interpret encoded-code1 input-state1))
(pretty-display "Output state (x0 should be -42):")
(pretty-display (progstate-regs output-state1))

(newline)
(pretty-display "=== Testing programs/identity.s ===")
(define code2 (send parser ir-from-file "programs/identity.s"))
(pretty-display "Source:")
(send printer print-syntax code2)

(define encoded-code2 (send printer encode code2))

;; Create test input: x1 = 7
(define input-state2
  (progstate (vector 0 7 0 0 0 0 0 0 0 0)
             (new memory-racket% [get-fresh-val (get-rand-func 4)])))

(pretty-display "\nInput state (x1=7):")
(pretty-display (progstate-regs input-state2))

(define output-state2 (send simulator1 interpret encoded-code2 input-state2))
(pretty-display "Output state (x0 should be 7):")
(pretty-display (progstate-regs output-state2))

(newline)
(pretty-display "=== Testing programs/double_negate.s ===")
(define code3 (send parser ir-from-file "programs/double_negate.s"))
(pretty-display "Source:")
(send printer print-syntax code3)

(define encoded-code3 (send printer encode code3))

;; Create test input: x1 = 22
(define input-state3
  (progstate (vector 0 22 0 0 0 0 0 0 0 0)
             (new memory-racket% [get-fresh-val (get-rand-func 4)])))

(pretty-display "\nInput state (x1=22):")
(pretty-display (progstate-regs input-state3))

(define output-state3 (send simulator1 interpret encoded-code3 input-state3))
(pretty-display "Output state (x0 should be 22):")
(pretty-display (progstate-regs output-state3))