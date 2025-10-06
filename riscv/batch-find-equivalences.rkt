#lang racket

(require "riscv-parser.rkt" "riscv-machine.rkt" "riscv-printer.rkt"
         "riscv-simulator-racket.rkt" "riscv-simulator-rosette.rkt"
         "riscv-validator.rkt" "riscv-enumerator.rkt"
         "../memory-racket.rkt" "../validator.rkt" "../inst.rkt"
         racket/serialize racket/date)

;; Set up components
(define machine (new riscv-machine% [config 4]))
(define printer (new riscv-printer% [machine machine]))
(define parser (new riscv-parser%))
(define simulator-racket (new riscv-simulator-racket% [machine machine]))
(define simulator-rosette (new riscv-simulator-rosette% [machine machine]))
(define validator (new riscv-validator% [machine machine] [simulator simulator-rosette]))

;; Cache for already checked pairs
(define equivalence-cache (make-hash))
(define checked-pairs (make-hash))

;; Check if two instruction strings are equivalent
(define (check-equivalence inst1-str inst2-str dest-reg)
  ;; Check cache first
  (define cache-key (format "~a::~a" inst1-str inst2-str))
  (cond
    [(hash-has-key? equivalence-cache cache-key)
     (hash-ref equivalence-cache cache-key)]
    [else
     (with-handlers ([exn:fail? (lambda (e)
                                  (hash-set! equivalence-cache cache-key #f)
                                  #f)])
       (define inst1 (send parser ir-from-string inst1-str))
       (define inst2 (send parser ir-from-string inst2-str))
       (define enc1 (send printer encode inst1))
       (define enc2 (send printer encode inst2))
       (define constraint (send printer encode-live (list dest-reg)))

       (define counterexample
         (send validator counterexample enc1 enc2 constraint))

       (define result (not counterexample))
       (hash-set! equivalence-cache cache-key result)
       result)]))

;; Generate all single instruction patterns
(define (generate-all-single-instructions)
  (define instructions '())

  ;; R-type instructions
  (define r-type-ops '("add" "sub" "and" "or" "xor" "sll" "srl" "sra"
                       "mul" "mulh" "mulhu" "mulhsu"))

  ;; Generate R-type patterns
  (for* ([op r-type-ops]
         [dest '(2 3)]
         [src1 '(1)]
         [src2 '(0 1)])
    (set! instructions
          (cons (format "~a x~a, x~a, x~a" op dest src1 src2)
                instructions)))

  ;; I-type instructions
  (define i-type-ops '("addi" "andi" "ori" "xori"))
  (define shift-ops '("slli" "srli" "srai"))

  ;; Generate I-type patterns
  (for* ([op i-type-ops]
         [dest '(2 3)]
         [src '(1)]
         [imm '(0 1 -1 2 -2 4 8 16 -128 127)])
    (set! instructions
          (cons (format "~a x~a, x~a, ~a" op dest src imm)
                instructions)))

  ;; Generate shift patterns
  (for* ([op shift-ops]
         [dest '(2 3)]
         [src '(1)]
         [shamt '(0 1 2 3 4 8 16 31)])
    (set! instructions
          (cons (format "~a x~a, x~a, ~a" op dest src shamt)
                instructions)))

  ;; LUI instruction
  (for* ([dest '(2 3)]
         [imm '(0 1 2 4 8 16 256 1024)])
    (set! instructions
          (cons (format "lui x~a, ~a" dest imm)
                instructions)))

  instructions)

;; Find equivalence classes
(define (find-equivalence-classes instructions)
  (define equiv-classes (make-hash))  ; representative -> list of equivalents

  (define total (length instructions))
  (define checked 0)

  (for* ([i (in-range total)]
         [j (in-range i total)])
    (define inst1 (list-ref instructions i))
    (define inst2 (list-ref instructions j))

    (set! checked (add1 checked))
    (when (= (modulo checked 1000) 0)
      (printf "Progress: ~a/~a pairs checked\n"
              checked (quotient (* total (sub1 total)) 2)))

    ;; Extract destination register (simple heuristic)
    (define dest-reg
      (match inst1
        [(regexp #rx"x([0-9]+)" (list _ d)) (string->number d)]
        [_ 2]))

    (when (check-equivalence inst1 inst2 dest-reg)
      ;; Add to equivalence class
      (cond
        [(hash-has-key? equiv-classes inst1)
         (hash-update! equiv-classes inst1
                      (lambda (lst) (cons inst2 lst)))]
        [(hash-has-key? equiv-classes inst2)
         (hash-update! equiv-classes inst2
                      (lambda (lst) (cons inst1 lst)))]
        [else
         (hash-set! equiv-classes inst1 (list inst2))])))

  equiv-classes)

;; Save results to file
(define (save-results equiv-classes filename)
  (with-output-to-file filename
    #:exists 'replace
    (lambda ()
      (pretty-display "# RISC-V Instruction Equivalence Classes")
      (pretty-display (format "# Generated: ~a" (date->string (current-date) #t)))
      (pretty-display (format "# Total classes: ~a\n" (hash-count equiv-classes)))

      (define sorted-keys
        (sort (hash-keys equiv-classes) string<?))

      (for ([key sorted-keys])
        (define equivs (hash-ref equiv-classes key))
        (when (> (length equivs) 1)  ; Only show interesting classes
          (pretty-display (format "Class: ~a" key))
          (for ([eq (remove-duplicates equivs)])
            (unless (equal? eq key)
              (pretty-display (format "  ≡ ~a" eq))))
          (pretty-display "")))))

  ;; Also save as serialized data for programmatic use
  (with-output-to-file (string-append filename ".data")
    #:exists 'replace
    (lambda ()
      (write equiv-classes))))

;; Main batch processing function
(define (batch-find-equivalences #:max-instructions [max-inst 100]
                                 #:output-file [output-file "equivalences.txt"])
  (pretty-display "=== Batch Equivalence Finder ===")
  (pretty-display (format "Generating instruction patterns..."))

  (define all-instructions (generate-all-single-instructions))
  (pretty-display (format "Generated ~a instruction patterns" (length all-instructions)))

  ;; Limit for testing
  (define instructions-to-test
    (take all-instructions (min max-inst (length all-instructions))))

  (pretty-display (format "Testing ~a instructions..." (length instructions-to-test)))
  (pretty-display "This may take a while...\n")

  (define start-time (current-seconds))
  (define equiv-classes (find-equivalence-classes instructions-to-test))
  (define end-time (current-seconds))

  (pretty-display (format "\nCompleted in ~a seconds" (- end-time start-time)))
  (pretty-display (format "Found ~a equivalence classes" (hash-count equiv-classes)))

  ;; Count interesting equivalences
  (define interesting-count
    (for/sum ([key (hash-keys equiv-classes)])
      (if (> (length (hash-ref equiv-classes key)) 1) 1 0)))

  (pretty-display (format "Found ~a non-trivial equivalence classes" interesting-count))

  (save-results equiv-classes output-file)
  (pretty-display (format "\nResults saved to ~a" output-file))

  equiv-classes)

;; Parallel version using places
(define (parallel-batch-find #:num-workers [num-workers 4]
                             #:max-instructions [max-inst 100]
                             #:output-file [output-file "equivalences.txt"])
  (pretty-display "=== Parallel Batch Equivalence Finder ===")
  (pretty-display (format "Using ~a worker threads" num-workers))

  ;; Generate instructions
  (define all-instructions (generate-all-single-instructions))
  (define instructions-to-test
    (take all-instructions (min max-inst (length all-instructions))))

  ;; Split work among workers
  (define chunk-size (quotient (length instructions-to-test) num-workers))
  (define work-chunks
    (for/list ([i (in-range num-workers)])
      (define start (* i chunk-size))
      (define end (if (= i (sub1 num-workers))
                     (length instructions-to-test)
                     (* (add1 i) chunk-size)))
      (take (drop instructions-to-test start) (- end start))))

  ;; TODO: Implement place-based parallel processing
  ;; For now, just use sequential version
  (batch-find-equivalences #:max-instructions max-inst
                          #:output-file output-file))

;; Command-line interface
(define (main)
  (command-line
   #:program "batch-find-equivalences"
   #:once-each
   [("-n" "--num-instructions") num
                                "Maximum number of instructions to test (default: 50)"
                                (batch-find-equivalences
                                 #:max-instructions (string->number num))]
   [("-p" "--parallel") workers
                        "Use parallel processing with N workers"
                        (parallel-batch-find
                         #:num-workers (string->number workers))]
   [("-o" "--output") file
                     "Output file name (default: equivalences.txt)"
                     (batch-find-equivalences #:output-file file)]
   #:args ()
   (batch-find-equivalences #:max-instructions 50)))

;; Run if executed directly
(module+ main
  (main))