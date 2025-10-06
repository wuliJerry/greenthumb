#lang racket

(require "riscv-parser.rkt" "riscv-machine.rkt" "riscv-printer.rkt"
         "riscv-simulator-racket.rkt" "riscv-simulator-rosette.rkt"
         "riscv-validator.rkt" "riscv-enumerator.rkt"
         "../memory-racket.rkt" "../validator.rkt" "../inst.rkt")

;; Set up components
(define machine (new riscv-machine% [config 4]))
(define printer (new riscv-printer% [machine machine]))
(define parser (new riscv-parser%))
(define simulator-racket (new riscv-simulator-racket% [machine machine]))
(define simulator-rosette (new riscv-simulator-rosette% [machine machine]))
(define validator (new riscv-validator% [machine machine] [simulator simulator-rosette]))
(define enumerator (new riscv-enumerator% [machine machine] [printer printer]))

;; Find equivalent single instructions for a given instruction
(define (find-single-instruction-equivalents target-inst-str)
  (define target (send parser ir-from-string target-inst-str))
  (define target-encoded (send printer encode target))

  (pretty-display (format "\n=== Finding equivalents for: ~a ===" target-inst-str))

  ;; Extract which registers are used
  (define-values (dest-reg src-regs)
    (match target-inst-str
      [(regexp #rx"^([a-z]+) x([0-9]+), x([0-9]+), (.+)$" (list _ op d s1 s2))
       (values (string->number d) (list (string->number s1) (string->number s2)))]
      [(regexp #rx"^([a-z]+) x([0-9]+), x([0-9]+)$" (list _ op d s))
       (values (string->number d) (list (string->number s)))]
      [(regexp #rx"^([a-z]+) x([0-9]+), (.+)$" (list _ op d imm))
       (values (string->number d) '())]
      [_ (values 2 '(1))]))  ; Default

  ;; Only look at registers involved in the instruction
  (define live-out-list (list dest-reg))
  (define constraint (send printer encode-live live-out-list))

  (define equivalents '())
  (define checked 0)

  ;; Systematically try different instruction patterns
  (define opcodes-to-try
    '("add" "sub" "and" "or" "xor" "sll" "srl" "sra"
      "addi" "andi" "ori" "xori" "slli" "srli" "srai"
      "mul" "mulh" "mulhu"))

  ;; Try single instructions with same destination
  (for ([opcode opcodes-to-try])
    ;; Try various operand combinations
    (define candidates
      (cond
        ;; R-type instructions (3 operands)
        [(member opcode '("add" "sub" "and" "or" "xor" "sll" "srl" "sra" "mul" "mulh" "mulhu"))
         (list
          (format "~a x~a, x~a, x~a" opcode dest-reg
                  (if (null? src-regs) 1 (car src-regs))
                  (if (null? src-regs) 1 (car src-regs)))
          (format "~a x~a, x~a, x0" opcode dest-reg
                  (if (null? src-regs) 1 (car src-regs)))
          (format "~a x~a, x0, x~a" opcode dest-reg
                  (if (null? src-regs) 1 (car src-regs))))]
        ;; I-type instructions (2 operands + immediate)
        [(member opcode '("addi" "andi" "ori" "xori" "slli" "srli" "srai"))
         (append
          (for/list ([imm '(0 1 -1 2 -2 3 4 8)])
            (format "~a x~a, x~a, ~a" opcode dest-reg
                    (if (null? src-regs) 1 (car src-regs)) imm))
          (if (member opcode '("slli" "srli" "srai"))
              (for/list ([imm '(16 31)])
                (format "~a x~a, x~a, ~a" opcode dest-reg
                        (if (null? src-regs) 1 (car src-regs)) imm))
              '()))]
        [else '()]))

    (for ([cand-str candidates])
      (set! checked (add1 checked))
      (with-handlers ([exn:fail? (lambda (e) #f)])  ; Skip parse errors
        (define cand (send parser ir-from-string cand-str))
        (define cand-encoded (send printer encode cand))

        ;; Check equivalence using validator
        (define counterexample
          (send validator counterexample target-encoded cand-encoded constraint))

        (when (not counterexample)  ; No counterexample means equivalent
          (unless (equal? target-inst-str cand-str)
            (set! equivalents (cons cand-str equivalents))
            (pretty-display (format "  Found: ~a" cand-str)))))))

  (pretty-display (format "Checked ~a candidates, found ~a equivalents"
                         checked (length equivalents)))
  equivalents)

;; Find equivalent 2-instruction sequences
(define (find-two-instruction-equivalents target-inst-str max-candidates)
  (define target (send parser ir-from-string target-inst-str))
  (define target-encoded (send printer encode target))

  (pretty-display (format "\n=== Finding 2-inst sequences equivalent to: ~a ==="
                         target-inst-str))

  ;; Extract destination register
  (define dest-reg
    (match target-inst-str
      [(regexp #rx"x([0-9]+)" (list _ d)) (string->number d)]
      [_ 2]))

  (define live-out-list (list dest-reg))
  (define constraint (send printer encode-live live-out-list))

  (define equivalents '())
  (define checked 0)

  ;; Generate 2-instruction sequences
  ;; Use intermediate register x3 if needed
  (define simple-patterns
    (list
     ;; Patterns for multiply by 2
     "add x3, x1, x1\nadd x2, x3, x0"
     "slli x3, x1, 1\nadd x2, x3, x0"
     "add x3, x1, x0\nadd x2, x3, x3"

     ;; Patterns for copy
     "add x3, x1, x0\nadd x2, x3, x0"
     "or x3, x1, x0\nadd x2, x3, x0"
     "and x3, x1, x1\nadd x2, x3, x0"

     ;; Patterns for zero
     "xor x3, x1, x1\nadd x2, x3, x0"
     "sub x3, x1, x1\nadd x2, x3, x0"
     "and x3, x1, x0\nadd x2, x3, x0"
     "mul x3, x1, x0\nadd x2, x3, x0"))

  (for ([seq simple-patterns])
    (when (< checked max-candidates)
      (set! checked (add1 checked))
      (with-handlers ([exn:fail? (lambda (e) #f)])
        (define cand (send parser ir-from-string seq))
        (define cand-encoded (send printer encode cand))

        (define counterexample
          (send validator counterexample target-encoded cand-encoded constraint))

        (when (not counterexample)
          (set! equivalents (cons seq equivalents))
          (pretty-display (format "  Found 2-inst sequence:"))
          (for ([line (string-split seq "\n")])
            (pretty-display (format "    ~a" line)))))))

  (pretty-display (format "Checked ~a sequences, found ~a equivalents"
                         checked (length equivalents)))
  equivalents)

;; Main testing function
(define (test-equivalence-finding)
  (pretty-display "=== Instruction Equivalence Finder ===")
  (pretty-display "Finding alternative representations for common instructions\n")

  ;; Test single instructions
  (define test-instructions
    '("add x2, x1, x0"     ; Copy
      "add x2, x1, x1"     ; Double
      "xor x2, x1, x1"     ; Zero
      "and x2, x1, x1"     ; Identity
      "slli x2, x1, 1"     ; Shift left by 1 (multiply by 2)
      "slli x2, x1, 2"     ; Shift left by 2 (multiply by 4)
      ))

  (define all-results '())

  (for ([inst test-instructions])
    (define equivs (find-single-instruction-equivalents inst))
    (set! all-results (cons (cons inst equivs) all-results)))

  ;; Test finding 2-instruction sequences for single instructions
  (pretty-display "\n=== Finding 2-instruction sequences ===")

  (for ([inst '("add x2, x1, x1" "slli x2, x1, 1")])
    (find-two-instruction-equivalents inst 20))

  ;; Summary
  (pretty-display "\n=== SUMMARY ===")
  (for ([result (reverse all-results)])
    (pretty-display (format "~a has ~a single-inst equivalents"
                           (car result) (length (cdr result)))))

  all-results)

;; Run the tests
(test-equivalence-finding)