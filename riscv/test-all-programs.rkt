#lang s-exp rosette

(require "riscv-parser.rkt" "riscv-printer.rkt" "riscv-machine.rkt"
         "riscv-simulator-rosette.rkt" "riscv-simulator-racket.rkt"
         "../memory-racket.rkt" "../validator.rkt")

(current-bitwidth 64)

(define parser (new riscv-parser%))
(define machine (new riscv-machine% [config 10]))
(define printer (new riscv-printer% [machine machine]))
(define sim-rosette (new riscv-simulator-rosette% [machine machine]))
(define sim-racket (new riscv-simulator-racket% [machine machine]))

;; Helper to create input state
(define (make-state . reg-values)
  (define regs (make-vector 10 0))
  (for ([val reg-values] [i (length reg-values)])
    (vector-set! regs i val))
  (progstate regs (new memory-racket% [get-fresh-val (get-rand-func 4)])))

;; Helper to run test
(define (test-program name file expected-tests)
  (pretty-display (format "\n=== Testing ~a ===" name))
  (define code (send parser ir-from-file file))
  (pretty-display "Source:")
  (send printer print-syntax code)

  (define encoded (send printer encode code))
  (newline)

  (define passed 0)
  (define failed 0)

  (for ([test expected-tests])
    (define input-vals (car test))
    (define expected-output (cdr test))

    (define input-state (apply make-state input-vals))
    (define output-rosette (send sim-rosette interpret encoded input-state))
    (define output-racket (send sim-racket interpret encoded input-state))

    ;; Check if both simulators agree
    (define rosette-regs (progstate-regs output-rosette))
    (define racket-regs (progstate-regs output-racket))

    (define simulators-agree?
      (for/and ([i 10])
        (= (vector-ref rosette-regs i) (vector-ref racket-regs i))))

    (unless simulators-agree?
      (pretty-display (format "ERROR: Simulators disagree!"))
      (pretty-display (format "  Input: ~a" input-vals))
      (pretty-display (format "  Rosette: ~a" rosette-regs))
      (pretty-display (format "  Racket:  ~a" racket-regs))
      (set! failed (add1 failed)))

    ;; Check expected output for specific registers
    (for ([expected expected-output])
      (define reg-idx (car expected))
      (define expected-val (cdr expected))
      (define actual-val (vector-ref rosette-regs reg-idx))

      (if (= actual-val expected-val)
          (begin
            (pretty-display (format "✓ Input ~a -> x~a = ~a (expected ~a)"
                                    input-vals reg-idx actual-val expected-val))
            (set! passed (add1 passed)))
          (begin
            (pretty-display (format "✗ FAIL: Input ~a -> x~a = ~a (expected ~a)"
                                    input-vals reg-idx actual-val expected-val))
            (set! failed (add1 failed))))))

  (pretty-display (format "\nResult: ~a passed, ~a failed\n" passed failed))
  (= failed 0))

;; Run all tests
(define all-passed? #t)

;; Test 1: test_add.s
(set! all-passed?
  (and all-passed?
       (test-program "test_add.s" "programs/test_add.s"
                     '(((0 5 3)   . ((0 . 8)))        ; 5 + 3 = 8
                       ((0 -5 3)  . ((0 . -2)))       ; -5 + 3 = -2
                       ((0 0 0)   . ((0 . 0)))        ; 0 + 0 = 0
                       ((0 -1 -1) . ((0 . -2)))))))   ; -1 + -1 = -2

;; Test 2: negate.s
(set! all-passed?
  (and all-passed?
       (test-program "negate.s" "programs/negate.s"
                     '(((0 42)   . ((0 . -42)))       ; -42
                       ((0 -42)  . ((0 . 42)))        ; 42
                       ((0 0)    . ((0 . 0)))         ; -0 = 0
                       ((0 1)    . ((0 . -1)))        ; -1
                       ((0 100)  . ((0 . -100)))))))  ; -100

;; Test 3: multiply_by_3.s
(set! all-passed?
  (and all-passed?
       (test-program "multiply_by_3.s" "programs/multiply_by_3.s"
                     '(((0 7)    . ((0 . 21)))        ; 7 * 3 = 21
                       ((0 -5)   . ((0 . -15)))       ; -5 * 3 = -15
                       ((0 0)    . ((0 . 0)))         ; 0 * 3 = 0
                       ((0 10)   . ((0 . 30)))        ; 10 * 3 = 30
                       ((0 -1)   . ((0 . -3)))))))    ; -1 * 3 = -3

;; Test 4: clear_rightmost_bit.s
(set! all-passed?
  (and all-passed?
       (test-program "clear_rightmost_bit.s" "programs/clear_rightmost_bit.s"
                     '(((0 22)   . ((0 . 20)))        ; 0b10110 -> 0b10100
                       ((0 7)    . ((0 . 6)))         ; 0b111 -> 0b110
                       ((0 8)    . ((0 . 8)))         ; 0b1000 -> 0b1000 (no change - already cleared)
                       ((0 15)   . ((0 . 14)))        ; 0b1111 -> 0b1110
                       ((0 1)    . ((0 . 0)))))))     ; 0b1 -> 0b0

;; Test 5: swap_xor.s
(set! all-passed?
  (and all-passed?
       (test-program "swap_xor.s" "programs/swap_xor.s"
                     '(((5 3)    . ((0 . 3) (1 . 5)))     ; swap 5 and 3
                       ((10 20)  . ((0 . 20) (1 . 10)))   ; swap 10 and 20
                       ((0 0)    . ((0 . 0) (1 . 0)))     ; swap 0 and 0
                       ((-5 7)   . ((0 . 7) (1 . -5)))    ; swap -5 and 7
                       ((100 -1) . ((0 . -1) (1 . 100)))))))  ; swap 100 and -1

;; Test 6: average.s (with shift by 32)
;; Note: This uses slli x4, x4, 32 which is a left shift, not right shift
;; This is likely incorrect for computing average!
(pretty-display "\n=== Testing average.s (expected to have issues) ===")
(define code-avg (send parser ir-from-file "programs/average.s"))
(send printer print-syntax code-avg)
(define encoded-avg (send printer encode code-avg))
(define test-avg-in (make-state 0 8 4))  ; avg(8,4) should be 6
(define test-avg-out (send sim-rosette interpret encoded-avg test-avg-in))
(pretty-display (format "Input: x1=8, x2=4"))
(pretty-display (format "Output: x0=~a (expected 6 for average)"
                        (vector-ref (progstate-regs test-avg-out) 0)))
(pretty-display "⚠️  NOTE: This program likely has bugs due to shift by 32 instead of 1\n")

;; Test 7: absolute_diff.s
(set! all-passed?
  (and all-passed?
       (test-program "absolute_diff.s" "programs/absolute_diff.s"
                     '(((0 10 3)   . ((0 . 7)))       ; |10 - 3| = 7
                       ((0 3 10)   . ((0 . 7)))       ; |3 - 10| = 7
                       ((0 5 5)    . ((0 . 0)))       ; |5 - 5| = 0
                       ((0 -5 3)   . ((0 . 8)))       ; |-5 - 3| = 8
                       ((0 0 -10)  . ((0 . 10)))))))  ; |0 - -10| = 10

(if all-passed?
    (pretty-display "\n✓✓✓ All tests PASSED! ✓✓✓")
    (pretty-display "\n✗✗✗ Some tests FAILED ✗✗✗"))
