#lang racket

(require "riscv-parser.rkt"
         "riscv-machine.rkt"
         "riscv-printer.rkt"
         "riscv-simulator-rosette.rkt"
         "riscv-validator.rkt")

;; Test the validator bug with complex_identity

(define parser (new riscv-parser%))
(define machine (new riscv-machine%))
(define printer (new riscv-printer% [machine machine]))
(define simulator (new riscv-simulator-rosette% [machine machine]))
(define validator (new riscv-validator% [machine machine] [simulator simulator] [printer printer]))

;; Original program: x7 = x1 (identity through x1+1-1+1-1+1-1)
(define original-code (send parser ir-from-file "programs/complex_identity.s"))

;; Buggy optimized program: writes to x5 instead of x7
;; This computes x5 = x1 (via double NOT), but doesn't touch x7!
(define buggy-file "programs/test_buggy.s")
(call-with-output-file buggy-file
  (lambda (out)
    (display "xori x2, x1, -1\nxori x5, x2, -1\n" out))
  #:exists 'replace)
(define buggy-code (send parser ir-from-file buggy-file))

;; Set machine config first (number of registers)
(send machine set-config 8)

;; live-out: only x7 matters
(define live-out (list 7))
(define constraint (send printer encode-live live-out))

(pretty-display "=== Testing Validator Bug ===")
(pretty-display "Original program should compute x7 = x1")
(pretty-display "Buggy program computes x5 = x1, leaves x7 untouched")
(pretty-display "")

;; Encode programs
(define encoded-original (send printer encode original-code))
(define encoded-buggy (send printer encode buggy-code))

(pretty-display "Constraint (only x7 should be checked):")
(send machine display-state constraint)

;; Check if validator detects the bug
(pretty-display "\nRunning counterexample check...")
(define ce (send validator counterexample encoded-original encoded-buggy constraint))

(if ce
    (begin
      (pretty-display "✓ GOOD: Validator found a counterexample!")
      (pretty-display "Counterexample input state:")
      (send machine display-state ce))
    (begin
      (pretty-display "✗ BUG: Validator incorrectly accepted the buggy program!")
      (pretty-display "This means the programs were considered equivalent when they're not.")))
