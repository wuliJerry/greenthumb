#lang racket

(require "riscv-parser.rkt" "riscv-machine.rkt" "riscv-printer.rkt"
         "riscv-simulator-racket.rkt" "riscv-simulator-rosette.rkt"
         "riscv-validator.rkt" "riscv-stochastic.rkt"
         "../parallel-driver.rkt"
         "../memory-racket.rkt" "../ops-racket.rkt" "../inst.rkt"
         racket/cmdline)

;; Parse command line arguments
(define prog-file #f)
(define cost-file #f)
(define time-limit 60)
(define cores 1)
(define output-dir "output")

(command-line
 #:program "optimize-alt"
 #:once-each
 [("-t" "--time") t "Time limit in seconds" (set! time-limit (string->number t))]
 [("-p" "--cores") p "Number of cores to use" (set! cores (string->number p))]
 [("-c" "--cost") c "Cost model file" (set! cost-file c)]
 [("-d" "--dir") d "Output directory" (set! output-dir d)]
 #:args (filename)
 (set! prog-file filename))

;; Load cost model if provided
(define cost-model
  (if (and cost-file (file-exists? cost-file))
      (begin
        (pretty-display (format "Loading cost model from: ~a" cost-file))
        (with-input-from-file cost-file read))
      #f))

;; Set up components
(define machine (new riscv-machine% [config 4]))
(define printer (new riscv-printer% [machine machine]))
(define parser (new riscv-parser%))

;; Create simulators with optional cost model
(define simulator-racket
  (new riscv-simulator-racket%
       [machine machine]
       [cost-model cost-model]))

(define simulator-rosette
  (new riscv-simulator-rosette%
       [machine machine]
       [cost-model cost-model]))

(define validator
  (new riscv-validator%
       [machine machine]
       [simulator simulator-rosette]))

;; Create parallel driver for multi-core support
(define driver
  (new parallel-driver%
       [isa "riscv"]
       [parser parser]
       [machine machine]
       [printer printer]
       [validator validator]
       [simulator simulator-racket]
       [search-type 'stoch]  ; stochastic search
       [mode 'opt]))         ; optimization mode

;; Load and parse program
(define code (send parser ir-from-file prog-file))
(define encoded (send printer encode code))
(define info (send parser info-from-file prog-file))
(define live-out (send printer encode-live info))  ; Encode the live-out registers

;; Display initial info
(pretty-display "=== Optimization with Custom Cost Model ===")
(pretty-display (format "Program: ~a" prog-file))
(pretty-display "Original code:")
(send printer print-syntax code)
(pretty-display (format "Original cost: ~a"
                        (send simulator-racket performance-cost encoded)))

(when cost-model
  (pretty-display (format "Using custom cost model with ~a cores" cores)))

;; Run optimization using parallel driver
(pretty-display (format "Running optimization for ~a seconds with ~a cores..." time-limit cores))
(define result
  (send driver optimize code live-out
        #:dir output-dir
        #:cores cores
        #:time-limit time-limit
        #:size #f
        #:input-file #f))

;; Display results
(with-handlers ([exn:fail? (lambda (e)
                            (pretty-display "\nOptimization completed. Check output directory for results.")
                            (pretty-display (format "Output directory: ~a" output-dir)))])
  (when result
    (pretty-display "\nOptimized code found:")
    (when (vector? result)
      (send printer print-syntax (send printer decode result))
      (pretty-display (format "New cost: ~a"
                              (send simulator-racket performance-cost result))))))