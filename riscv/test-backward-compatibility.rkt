#lang racket

(require "riscv-parser.rkt" "riscv-machine.rkt" "riscv-printer.rkt"
         "riscv-simulator-racket.rkt" "riscv-simulator-rosette.rkt"
         "riscv-validator.rkt" "../memory-racket.rkt")

(pretty-display "=== Testing Backward Compatibility ===")
(pretty-display "Ensuring existing code works without cost model")
(pretty-display "")

;; Test 1: Create simulators without cost model (old way)
(define machine (new riscv-machine% [config 4]))
(define printer (new riscv-printer% [machine machine]))
(define parser (new riscv-parser%))

(define sim-racket-old (new riscv-simulator-racket% [machine machine]))
(define sim-rosette-old (new riscv-simulator-rosette% [machine machine]))

(pretty-display "✓ Simulators created without cost model (backward compatible)")

;; Test 2: Run a simple program with default costs
(define test-prog (send parser ir-from-string "add x2, x1, x1\nmul x3, x2, x1"))
(define encoded (send printer encode test-prog))

(define cost-old (send sim-racket-old performance-cost encoded))
(pretty-display (format "Program cost with default model: ~a (should be 5: add=1, mul=4)" cost-old))

(unless (= cost-old 5)
  (error "Default cost calculation failed!"))
(pretty-display "✓ Default cost model working correctly")

;; Test 3: Create simulators with custom cost model (new way)
(define custom-costs
  #hash((add . 10)   ; Make add expensive
        (mul . 2)))  ; Make mul cheaper

(define sim-racket-custom
  (new riscv-simulator-racket%
       [machine machine]
       [cost-model custom-costs]))

(define sim-rosette-custom
  (new riscv-simulator-rosette%
       [machine machine]
       [cost-model custom-costs]))

(pretty-display "✓ Simulators created with custom cost model")

;; Test 4: Verify custom costs work
(define cost-custom (send sim-racket-custom performance-cost encoded))
(pretty-display (format "Program cost with custom model: ~a (should be 12: add=10, mul=2)" cost-custom))

(unless (= cost-custom 12)
  (error "Custom cost calculation failed!"))
(pretty-display "✓ Custom cost model working correctly")

;; Test 5: Test validator still works
(define validator (new riscv-validator% [machine machine] [simulator sim-rosette-old]))
(pretty-display "✓ Validator works with simulator (backward compatible)")

;; Test 6: Run concrete simulation
(define state (progstate (vector 0 5 0 0)
                        (new memory-racket% [get-fresh-val (lambda () 0)])))

(define result (send sim-racket-old interpret encoded state))
(define regs (progstate-regs result))

(pretty-display (format "Simulation result: x2=~a, x3=~a (expected: x2=10, x3=50)"
                       (vector-ref regs 2) (vector-ref regs 3)))

(unless (and (= (vector-ref regs 2) 10)
            (= (vector-ref regs 3) 50))
  (error "Simulation failed!"))
(pretty-display "✓ Simulation works correctly")

(pretty-display "")
(pretty-display "=== All Backward Compatibility Tests Passed ===")
(pretty-display "Existing code will continue to work without modification")
(pretty-display "New cost model feature is opt-in via optional parameter")