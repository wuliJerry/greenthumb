#lang s-exp rosette

(require "riscv-parser.rkt" "riscv-printer.rkt" "riscv-machine.rkt" "../validator.rkt"
         "riscv-simulator-rosette.rkt" "../memory-racket.rkt"
         "riscv-simulator-racket.rkt"
         ;;"riscv-validator.rkt" "riscv-symbolic.rkt"
         )

;; Phase 0: Set up bitwidth for Rosette
(current-bitwidth 64)

;; Phase A: Test machine, parser, printer
(pretty-display "Phase A: test machine, parser, and printer.")
(define parser (new riscv-parser%))
(define machine (new riscv-machine% [config 4]))
(define printer (new riscv-printer% [machine machine]))

(define code
(send parser ir-from-string "
add x0, x1, x2
sub x3, x2, x1
xor x0, x0, x3
"))

(pretty-display ">>> Source")
(send printer print-syntax code)

(pretty-display ">>> String-IR")
(send printer print-struct code)

(pretty-display ">>> Encoded-IR")
(define encoded-code (send printer encode code))
(send printer print-struct encoded-code)
(newline)


;; Phase B: Interpret concrete program with concrete inputs
(pretty-display "Phase B: interpret program using simulator writing in Rosette.")
;; define number of bits used for generating random test inputs
(define test-bit 4)
;; create random input state
(define input-state (send machine get-state (get-rand-func test-bit)))
(define simulator-rosette (new riscv-simulator-rosette% [machine machine]))
(pretty-display `(input ,input-state))
(pretty-display `(output ,(send simulator-rosette interpret encoded-code input-state)))
(newline)

;; Phase D: Duplicate rosette simulator to racket simulator
(pretty-display "Phase D: interpret program using simulator writing in Racket.")
(define simulator-racket (new riscv-simulator-racket% [machine machine]))
(pretty-display `(input ,input-state))
(pretty-display `(output ,(send simulator-racket interpret encoded-code input-state)))
(newline)

;; Skip Phase C (symbolic) for now - requires additional Rosette configuration

