#lang s-exp rosette

(require "../enumerator.rkt" "../validator.rkt" "../inst.rkt"
         "riscv-machine.rkt" "riscv-printer.rkt" "riscv-parser.rkt"
         "riscv-enumerator.rkt" "riscv-validator.rkt"
         "riscv-simulator-rosette.rkt")

(provide riscv-equivalence-finder%)

(define riscv-equivalence-finder%
  (class object%
    (super-new)
    (init-field machine printer parser validator simulator enumerator
                [max-length 3]  ; Maximum length of sequences to check
                [timeout 60])   ; Timeout per equivalence check in seconds

    (public find-equivalences find-all-equivalences-parallel
            check-equivalence enumerate-candidates)

    ;; Check if two programs are equivalent
    ;; Returns #t if equivalent, #f otherwise
    (define (check-equivalence prog1 prog2 live-out)
      (define constraint (send printer encode-live live-out))
      (define counterexample
        (send validator counterexample prog1 prog2 constraint))
      (not counterexample))  ; If no counterexample, they're equivalent

    ;; Enumerate candidate programs up to given length
    ;; target-regs: list of registers to use
    ;; max-len: maximum program length
    (define (enumerate-candidates target-regs max-len)
      (define candidates '())

      ;; Generate all programs of length 1 to max-len
      (for ([len (in-range 1 (add1 max-len))])
        (define live-in (send machine init-live target-regs))
        (define live-out (send machine init-live target-regs))

        ;; Use enumerator to generate instructions
        (define gen (send enumerator generate-inst live-in live-out #f #f))

        ;; Collect a limited number of candidates per length
        (define count 0)
        (define max-per-length 1000)  ; Limit candidates per length

        (let loop ()
          (when (< count max-per-length)
            (define result (gen))
            (when (and result (car result))
              (define inst (car result))
              (unless (equal? (inst-op inst) (get-field nop-id machine))
                (set! candidates (cons (vector inst) candidates))
                (set! count (add1 count)))
              (loop)))))

      candidates)

    ;; Find all equivalent programs for a given instruction/sequence
    ;; prog: the target program (vector of instructions)
    ;; live-out: list of output registers
    ;; max-len: maximum length of equivalent programs to search
    (define (find-equivalences prog live-out max-len)
      (pretty-display "=== Finding Equivalences ===")
      (pretty-display "Target program:")
      (send printer print-syntax prog)
      (pretty-display (format "Live-out registers: ~a" live-out))
      (pretty-display (format "Max equivalent length: ~a" max-len))
      (pretty-display "")

      ;; Extract registers used in the program
      (define used-regs (send machine analyze-registers prog live-out))

      ;; Generate candidate programs
      (pretty-display "Generating candidate programs...")
      (define candidates (enumerate-candidates used-regs max-len))
      (pretty-display (format "Generated ~a candidates" (length candidates)))

      ;; Check each candidate for equivalence
      (define equivalents '())
      (define checked 0)

      (pretty-display "Checking equivalences...")
      (for ([candidate candidates])
        (set! checked (add1 checked))
        (when (= (modulo checked 100) 0)
          (pretty-display (format "  Checked ~a/~a..." checked (length candidates))))

        ;; Skip if it's the same program
        (unless (equal? prog candidate)
          (with-handlers ([exn:fail? (lambda (e) #f)])  ; Ignore errors
            (when (check-equivalence prog candidate
                                    (send printer encode-live live-out))
              (set! equivalents (cons candidate equivalents))
              (pretty-display (format "  Found equivalent #~a:"
                                     (length equivalents)))
              (send printer print-syntax candidate)))))

      (pretty-display "")
      (pretty-display (format "=== Found ~a equivalent programs ==="
                              (length equivalents)))
      equivalents)

    ;; Parallel version for batch processing multiple instructions
    (define (find-all-equivalences-parallel prog-list max-len)
      ;; TODO: Implement parallel processing
      ;; For now, just process sequentially
      (for/list ([prog prog-list])
        (define live-out (send machine get-live-out prog))
        (cons prog (find-equivalences prog live-out max-len))))

    ))

;; Helper function to create and run equivalence finder
(define (run-equivalence-finder target-prog-str)
  (define machine (new riscv-machine% [config 4]))
  (define printer (new riscv-printer% [machine machine]))
  (define parser (new riscv-parser%))
  (define simulator (new riscv-simulator-rosette% [machine machine]))
  (define validator (new riscv-validator% [machine machine]
                                          [simulator simulator]))
  (define enumerator (new riscv-enumerator% [machine machine]
                                            [printer printer]))

  (define finder (new riscv-equivalence-finder%
                      [machine machine]
                      [printer printer]
                      [parser parser]
                      [validator validator]
                      [simulator simulator]
                      [enumerator enumerator]
                      [max-length 2]))

  ;; Parse the target program
  (define target-prog (send parser ir-from-string target-prog-str))
  (define encoded-prog (send printer encode target-prog))

  ;; Find equivalences
  (send finder find-equivalences encoded-prog '(2) 2))