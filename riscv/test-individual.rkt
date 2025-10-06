#lang s-exp rosette

(require "riscv-parser.rkt" "riscv-printer.rkt" "riscv-machine.rkt"
         "riscv-simulator-rosette.rkt" "../memory-racket.rkt" "../validator.rkt")

(current-bitwidth 32)

(define parser (new riscv-parser%))
(define machine (new riscv-machine% [config 10]))
(define printer (new riscv-printer% [machine machine]))
(define sim (new riscv-simulator-rosette% [machine machine]))

;; Helper
(define (make-state . reg-values)
  (define regs (make-vector 10 0))
  (for ([val reg-values] [i (length reg-values)])
    (vector-set! regs i val))
  (progstate regs (new memory-racket% [get-fresh-val (get-rand-func 4)])))

;; Get filename from command-line args
(define args (current-command-line-arguments))
(define filename
  (if (> (vector-length args) 0)
      (vector-ref args 0)
      "programs/negate.s"))

(pretty-display (format "=== Testing ~a ===" filename))

;; Parse the file
(define code (send parser ir-from-file filename))
(if (eq? code #f)
    (begin
      (pretty-display (format "Error: Could not parse file ~a" filename))
      (exit 1))
    (begin
      (pretty-display "Source:")
      (send printer print-syntax code)

      (define encoded (send printer encode code))

      ;; Create test input - default values x1=42, x2=10
      (define input (make-state 0 42 10 0 0 0 0 0 0 0))
      (pretty-display (format "\nInput registers:"))
      (pretty-display (progstate-regs input))

      (define output (send sim interpret encoded input))
      (pretty-display (format "\nOutput registers:"))
      (pretty-display (progstate-regs output))))