#lang racket

(require "riscv-parser.rkt" "riscv-machine.rkt" "riscv-printer.rkt"
         "riscv-simulator-racket.rkt" "riscv-simulator-rosette.rkt"
         "riscv-validator.rkt" "riscv-enumerator.rkt"
         "../memory-racket.rkt" "../validator.rkt" "../inst.rkt"
         racket/serialize racket/date json)

;; Set up components
(define machine (new riscv-machine% [config 4]))
(define printer (new riscv-printer% [machine machine]))
(define parser (new riscv-parser%))
(define simulator-racket (new riscv-simulator-racket% [machine machine]))
(define simulator-rosette (new riscv-simulator-rosette% [machine machine]))
(define validator (new riscv-validator% [machine machine] [simulator simulator-rosette]))

;; Generate interesting instruction patterns
(define (generate-interesting-patterns)
  (define patterns '())

  ;; Common idioms and their potential equivalents
  (define idioms
    '(;; Identity/Copy operations
      ("add x2, x1, x0" . "copy")
      ("addi x2, x1, 0" . "copy")
      ("or x2, x1, x0" . "copy")
      ("or x2, x1, x1" . "copy")
      ("and x2, x1, x1" . "copy")
      ("slli x2, x1, 0" . "copy")
      ("srli x2, x1, 0" . "copy")
      ("srai x2, x1, 0" . "copy")
      ("xori x2, x1, 0" . "copy")
      ("ori x2, x1, 0" . "copy")
      ("andi x2, x1, -1" . "copy")

      ;; Zero operations
      ("xor x2, x1, x1" . "zero")
      ("sub x2, x1, x1" . "zero")
      ("and x2, x0, x0" . "zero")
      ("and x2, x1, x0" . "zero")
      ("mul x2, x1, x0" . "zero")
      ("mul x2, x0, x0" . "zero")
      ("andi x2, x1, 0" . "zero")

      ;; Double operations (multiply by 2)
      ("add x2, x1, x1" . "double")
      ("slli x2, x1, 1" . "double")

      ;; Quadruple (multiply by 4)
      ("slli x2, x1, 2" . "quadruple")

      ;; Negate operations
      ("sub x2, x0, x1" . "negate")
      ("xori x2, x1, -1" . "bitwise-not")

      ;; Sign extension
      ("slli x2, x1, 16" . "shift-left-16")
      ("srai x2, x1, 31" . "sign-bit")

      ;; Common constants
      ("addi x2, x0, 1" . "load-1")
      ("addi x2, x0, -1" . "load-minus-1")
      ("addi x2, x0, 0" . "load-0")
      ("lui x2, 1" . "load-high")))

  (map car idioms))

;; Check equivalence with timeout
(define (check-equiv-with-timeout inst1-str inst2-str dest-reg timeout-ms)
  (define result-channel (make-channel))

  (define worker-thread
    (thread
     (lambda ()
       (with-handlers ([exn:fail? (lambda (e) (channel-put result-channel #f))])
         (define inst1 (send parser ir-from-string inst1-str))
         (define inst2 (send parser ir-from-string inst2-str))
         (define enc1 (send printer encode inst1))
         (define enc2 (send printer encode inst2))
         (define constraint (send printer encode-live (list dest-reg)))

         (define counterexample
           (send validator counterexample enc1 enc2 constraint))

         (channel-put result-channel (not counterexample))))))

  ;; Wait for result with timeout
  (sync/timeout (/ timeout-ms 1000)
                (handle-evt result-channel (lambda (v) v))))

;; Find all equivalence classes
(define (find-all-equivalences patterns)
  (define equiv-classes '())  ; List of equivalence classes
  (define assigned (make-hash))  ; Track which patterns are assigned

  (define total (length patterns))
  (define checked 0)

  (for* ([i (in-range total)]
         [j (in-range (add1 i) total)])
    (define pat1 (list-ref patterns i))
    (define pat2 (list-ref patterns j))

    (set! checked (add1 checked))
    (when (= (modulo checked 100) 0)
      (printf "Checked ~a pairs...\n" checked))

    ;; Skip if already in same class
    (unless (and (hash-has-key? assigned pat1)
                (hash-has-key? assigned pat2)
                (equal? (hash-ref assigned pat1)
                       (hash-ref assigned pat2)))

      (define equiv (check-equiv-with-timeout pat1 pat2 2 5000))  ; 5 second timeout

      (when equiv
        (cond
          ;; Both unassigned - create new class
          [(and (not (hash-has-key? assigned pat1))
                (not (hash-has-key? assigned pat2)))
           (define new-class (list pat1 pat2))
           (set! equiv-classes (cons new-class equiv-classes))
           (hash-set! assigned pat1 new-class)
           (hash-set! assigned pat2 new-class)]

          ;; One assigned - add to existing class
          [(hash-has-key? assigned pat1)
           (define class-ref (hash-ref assigned pat1))
           (define updated-class (cons pat2 class-ref))
           ;; Update all references
           (for ([p class-ref])
             (hash-set! assigned p updated-class))
           (hash-set! assigned pat2 updated-class)]

          [(hash-has-key? assigned pat2)
           (define class-ref (hash-ref assigned pat2))
           (define updated-class (cons pat1 class-ref))
           ;; Update all references
           (for ([p class-ref])
             (hash-set! assigned p updated-class))
           (hash-set! assigned pat1 updated-class)]))))

  ;; Add singletons
  (for ([pat patterns])
    (unless (hash-has-key? assigned pat)
      (set! equiv-classes (cons (list pat) equiv-classes))
      (hash-set! assigned pat (list pat))))

  ;; Collect unique classes
  (define unique-classes (make-hash))
  (for ([pat patterns])
    (define class (hash-ref assigned pat))
    (define sorted-class (sort class string<?))
    (define key (string-join sorted-class "::"))
    (hash-set! unique-classes key sorted-class))

  (hash-values unique-classes))

;; Generate JSON output for visualization
(define (generate-json-output equiv-classes filename)
  (define json-data
    (for/list ([class equiv-classes]
               [id (in-naturals)])
      (hash 'id id
            'size (length class)
            'instructions class
            'representative (car class))))

  (with-output-to-file filename
    #:exists 'replace
    (lambda ()
      (write-json json-data))))

;; Generate markdown documentation
(define (generate-markdown equiv-classes filename)
  (with-output-to-file filename
    #:exists 'replace
    (lambda ()
      (displayln "# RISC-V Instruction Equivalence Database")
      (displayln "")
      (displayln (format "Generated: ~a" (date->string (current-date) #t)))
      (displayln "")
      (displayln "## Summary")
      (displayln (format "- Total equivalence classes: ~a"
                        (length equiv-classes)))
      (displayln (format "- Non-trivial classes: ~a"
                        (length (filter (lambda (c) (> (length c) 1))
                                      equiv-classes))))
      (displayln "")
      (displayln "## Equivalence Classes")
      (displayln "")

      (define sorted-classes
        (sort equiv-classes > #:key length))

      (for ([class sorted-classes]
            [num (in-naturals 1)])
        (when (> (length class) 1)
          (displayln (format "### Class ~a (~a instructions)" num (length class)))
          (displayln "")
          (displayln "```assembly")
          (for ([inst class])
            (displayln inst))
          (displayln "```")
          (displayln ""))))))

;; Main function
(define (generate-database)
  (pretty-display "=== RISC-V Equivalence Database Generator ===")
  (pretty-display "")

  (define patterns (generate-interesting-patterns))
  (pretty-display (format "Testing ~a instruction patterns..." (length patterns)))

  (define start-time (current-seconds))
  (define equiv-classes (find-all-equivalences patterns))
  (define end-time (current-seconds))

  (pretty-display (format "\nCompleted in ~a seconds" (- end-time start-time)))
  (pretty-display (format "Found ~a equivalence classes" (length equiv-classes)))

  ;; Generate outputs
  (generate-json-output equiv-classes "equiv-database.json")
  (generate-markdown equiv-classes "equiv-database.md")

  (pretty-display "\nGenerated files:")
  (pretty-display "  - equiv-database.json (for programmatic use)")
  (pretty-display "  - equiv-database.md (human-readable documentation)")

  ;; Show summary
  (pretty-display "\n=== Top Equivalence Classes ===")
  (define sorted (sort equiv-classes > #:key length))
  (for ([class (take sorted (min 5 (length sorted)))])
    (when (> (length class) 1)
      (pretty-display (format "\nClass with ~a members:" (length class)))
      (for ([inst (take class (min 5 (length class)))])
        (pretty-display (format "  - ~a" inst)))))

  equiv-classes)

;; Run the generator
(generate-database)