#lang racket

(require "riscv-parser.rkt" "riscv-machine.rkt" "riscv-printer.rkt"
         "riscv-simulator-racket.rkt" "riscv-simulator-rosette.rkt"
         "riscv-validator.rkt" "riscv-stochastic.rkt"
         "../memory-racket.rkt" "../ops-racket.rkt")

;; Set up the optimizer components
(define machine (new riscv-machine% [config 4]))
(define printer (new riscv-printer% [machine machine]))
(define parser (new riscv-parser%))
(define simulator-racket (new riscv-simulator-racket% [machine machine]))
(define simulator-rosette (new riscv-simulator-rosette% [machine machine]))
(define validator (new riscv-validator% [machine machine] [simulator simulator-rosette]))
(define search (new riscv-stochastic% [machine machine] [printer printer] [parser parser]
                                       [validator validator] [simulator simulator-racket]
                                       [syn-mode #f]))

(pretty-display "=== Testing Optimizer Directly ===")
(pretty-display "")

;; Test 1: Trivial redundant copy
(pretty-display "Test 1: Redundant copy (2 instructions -> 1)")
(define code1 (send parser ir-from-string "add x2, x1, x0\nadd x3, x2, x0"))
(define encoded1 (send printer encode code1))
(define cost1 (send simulator-racket performance-cost encoded1))
(pretty-display (format "  Original cost: ~a" cost1))

;; Run search for a short time
(pretty-display "  Running stochastic search for 10 seconds...")
(define result1
  (with-handlers ([exn:fail? (lambda (e)
                               (pretty-display (format "  ERROR: ~a" (exn-message e)))
                               #f)])
    (send search superoptimize encoded1
          (send printer encode-live '(3))  ; x3 is live-out
          "test-output"
          10  ; 10 second timeout
          #f  ; no size limit
          #:assume #f
          #:input-file #f
          #:start-prog #f
          #:prefix (send printer encode (vector))
          #:postfix (send printer encode (vector)))))

(pretty-display "")

;; Test 2: Multiply by 2
(pretty-display "Test 2: Multiply by 2 (cost 5 -> 1)")
(define code2 (send parser ir-from-string "addi x3, x0, 2\nmul x2, x1, x3"))
(define encoded2 (send printer encode code2))
(define cost2 (send simulator-racket performance-cost encoded2))
(pretty-display (format "  Original cost: ~a" cost2))

(pretty-display "  Running stochastic search for 10 seconds...")
(define result2
  (with-handlers ([exn:fail? (lambda (e)
                               (pretty-display (format "  ERROR: ~a" (exn-message e)))
                               #f)])
    (send search superoptimize encoded2
          (send printer encode-live '(2))  ; x2 is live-out
          "test-output"
          10
          #f
          #:assume #f
          #:input-file #f
          #:start-prog #f
          #:prefix (send printer encode (vector))
          #:postfix (send printer encode (vector)))))

(pretty-display "")

;; Test 3: Simple add that shouldn't improve
(pretty-display "Test 3: Simple add (no improvement expected)")
(define code3 (send parser ir-from-string "add x2, x1, x1"))
(define encoded3 (send printer encode code3))
(define cost3 (send simulator-racket performance-cost encoded3))
(pretty-display (format "  Original cost: ~a" cost3))

(pretty-display "  Running stochastic search for 5 seconds...")
(define result3
  (with-handlers ([exn:fail? (lambda (e)
                               (pretty-display (format "  ERROR: ~a" (exn-message e)))
                               #f)])
    (send search superoptimize encoded3
          (send printer encode-live '(2))
          "test-output"
          5
          #f
          #:assume #f
          #:input-file #f
          #:start-prog #f
          #:prefix (send printer encode (vector))
          #:postfix (send printer encode (vector)))))

(pretty-display "")
(pretty-display "=== Test Complete ===")
(pretty-display "If no errors occurred, the optimizer is working.")
(pretty-display "Check test-output.best for any improvements found.")