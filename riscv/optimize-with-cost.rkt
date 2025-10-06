#lang racket

(require "../parallel-driver.rkt" racket/draw)
(require "riscv-parser.rkt" "riscv-machine.rkt" "riscv-printer.rkt"
         "riscv-simulator-racket.rkt" "riscv-simulator-rosette.rkt"
         "riscv-validator.rkt" "riscv-symbolic.rkt" "riscv-forwardbackward.rkt"
         "riscv-stochastic.rkt" "riscv-enumerator.rkt" "riscv-inverse.rkt"
         racket/cmdline)

(define parser (new riscv-parser%))
(define machine (new riscv-machine%))

;; Parse command line arguments
(define cores 4)
(define dir "output")
(define time-limit 3600)
(define size #f)
(define prog-file #f)
(define cost-file #f)
(define sym-mode #f)
(define stoch-mode #f)
(define enum-mode #f)
(define hybrid-mode #f)

(command-line
 #:program "optimize-with-cost"
 #:once-each
 [("-c" "--core") c "Number of cores (default: 4)" (set! cores (string->number c))]
 [("-d" "--dir") d "Output directory (default: output)" (set! dir d)]
 [("-t" "--time-limit") t "Time limit in seconds" (set! time-limit (string->number t))]
 [("-s" "--size") s "Maximum size" (set! size (string->number s))]
 [("--cost") cost "Cost model file" (set! cost-file cost)]
 [("--sym") "Use symbolic search" (set! sym-mode #t)]
 [("--stoch") "Use stochastic search" (set! stoch-mode #t)]
 [("--enum") "Use enumerative search" (set! enum-mode #t)]
 [("--hybrid") "Use hybrid search" (set! hybrid-mode #t)]
 #:args (filename)
 (set! prog-file filename))

;; Set default to stochastic if no mode specified
(when (not (or sym-mode stoch-mode enum-mode hybrid-mode))
  (set! stoch-mode #t))

;; Load cost model if provided
(define cost-model
  (if (and cost-file (file-exists? cost-file))
      (begin
        (pretty-display (format "Loading cost model from: ~a" cost-file))
        (with-input-from-file cost-file read))
      #f))

;; Create simulators with optional cost model
(define simulator-racket
  (new riscv-simulator-racket%
       [machine machine]
       [cost-model cost-model]))

(define simulator-rosette
  (new riscv-simulator-rosette%
       [machine machine]
       [cost-model cost-model]))

;; Rest of the components
(define printer (new riscv-printer% [machine machine]))
(define validator (new riscv-validator% [machine machine] [simulator simulator-rosette]))
(define symbolic (new riscv-symbolic% [machine machine] [printer printer] [parser parser]
                       [validator validator] [simulator simulator-rosette]))
(define stochastic (new riscv-stochastic% [machine machine] [printer printer] [parser parser]
                         [validator validator] [simulator simulator-racket]
                         [syn-mode #f]))  ; #f for optimization mode
(define forwardbackward (new riscv-forwardbackward%
                              [machine machine] [printer printer] [parser parser]
                              [validator validator] [simulator simulator-racket]
                              [enumerator% riscv-enumerator%] [inverse% riscv-inverse%]))

;; Load and parse program
(define code (send parser ir-from-file prog-file))
(define prefix-info (send parser info-from-file prog-file))

;; Run optimization
(define driver
  (new parallel-driver%
       [printer printer]
       [validator validator]
       [simulator-racket simulator-racket]
       [simulator-rosette simulator-rosette]
       [enumerator% riscv-enumerator%]
       [forwardbackward forwardbackward]
       [symbolic symbolic]
       [stochastic stochastic]
       [machine machine]
       [config 0] [syn-mode #f]))  ; #f for optimization mode

;; Determine search type
(define-values (sym-cores stoch-cores enum-cores)
  (cond
    [sym-mode (values cores 0 0)]
    [stoch-mode (values 0 cores 0)]
    [enum-mode (values 0 0 cores)]
    [hybrid-mode (values 1 (- cores 1) 0)]  ; Hybrid: mix of symbolic and stochastic
    [else (values 0 cores 0)]))  ; Default to stochastic

(pretty-display (format "SEARCH TYPE: sym=~a stoch=~a enum=~a size=~a"
                       sym-cores stoch-cores enum-cores size))

(when cost-model
  (pretty-display "Using custom cost model"))

;; Run optimization
(send driver optimize code
      #:prefix (send parser ir-from-string "")
      #:forwardbackward forwardbackward
      #:prefix-info prefix-info
      #:output-dir dir
      #:cores-sym sym-cores
      #:cores-stoch stoch-cores
      #:cores-enum enum-cores
      #:time-limit time-limit
      #:size size)