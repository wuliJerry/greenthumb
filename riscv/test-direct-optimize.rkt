#lang racket

(require "riscv-parser.rkt" "riscv-machine.rkt" "riscv-printer.rkt"
         "riscv-simulator-racket.rkt" "riscv-simulator-rosette.rkt"
         "riscv-validator.rkt" "riscv-enumerative.rkt"
         "../memory-racket.rkt" "../ops-racket.rkt")

;; Set up the optimizer components
(define machine (new riscv-machine% [config 4]))
(define printer (new riscv-printer% [machine machine]))
(define parser (new riscv-parser%))
(define simulator-racket (new riscv-simulator-racket% [machine machine]))
(define simulator-rosette (new riscv-simulator-rosette% [machine machine]))
(define validator (new riscv-validator% [machine machine] [simulator simulator-rosette]))

;; Try enumerative search instead of stochastic
(define search (new riscv-enumerative% [machine machine] [printer printer] [parser parser]
                                        [validator validator] [simulator simulator-racket]))

(pretty-display "=== Testing Enumerative Search ===")

;; Test 1: Two instructions that can be reduced to one
(pretty-display "Test 1: Redundant copy (add x2, x1, x0; add x3, x2, x0)")
(define code1 (send parser ir-from-string "add x2, x1, x0\nadd x3, x2, x0"))
(define encoded1 (send printer encode code1))
(define cost1 (send simulator-racket performance-cost encoded1))
(pretty-display (format "  Original cost: ~a" cost1))
(pretty-display "  Original program:")
(send printer print-syntax code1)

(pretty-display "  Running enumerative search...")
(define result1
  (with-handlers ([exn:fail? (lambda (e)
                               (pretty-display (format "  ERROR: ~a" (exn-message e)))
                               #f)])
    (send search superoptimize encoded1
          (send printer encode-live '(3))  ; x3 is live-out
          "enum-output"
          300  ; 5 minute timeout
          1    ; size limit = 1 instruction
          #:assume #f
          #:input-file #f
          #:start-prog #f)))

(when result1
  (pretty-display "  Found improvement:")
  (send printer print-syntax (send printer decode result1))
  (pretty-display (format "  New cost: ~a" (send simulator-racket performance-cost result1))))

(pretty-display "")

;; Test 2: Try to find x1 * 2 = x1 + x1
(pretty-display "Test 2: Multiply by 2 (should find add)")
(define code2 (send parser ir-from-string "addi x3, x0, 2\nmul x2, x1, x3"))
(define encoded2 (send printer encode code2))
(define cost2 (send simulator-racket performance-cost encoded2))
(pretty-display (format "  Original cost: ~a (addi=1 + mul=4)" cost2))

(pretty-display "  Running enumerative search for single instruction...")
(define result2
  (with-handlers ([exn:fail? (lambda (e)
                               (pretty-display (format "  ERROR: ~a" (exn-message e)))
                               #f)])
    (send search superoptimize encoded2
          (send printer encode-live '(2))  ; x2 is live-out
          "enum-output2"
          300
          1    ; size limit = 1 instruction
          #:assume #f
          #:input-file #f
          #:start-prog #f)))

(when result2
  (pretty-display "  Found improvement:")
  (send printer print-syntax (send printer decode result2))
  (pretty-display (format "  New cost: ~a" (send simulator-racket performance-cost result2))))

(pretty-display "")
(pretty-display "=== Test Complete ===")