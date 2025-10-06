#lang racket

(require "../parallel-driver.rkt" racket/draw)
(require "riscv-parser.rkt" "riscv-machine.rkt" "riscv-printer.rkt"
         "riscv-simulator-racket.rkt" "riscv-simulator-rosette.rkt"
         "riscv-validator.rkt" "riscv-symbolic.rkt" "riscv-forwardbackward.rkt"
         "riscv-stochastic.rkt" "riscv-enumerator.rkt"
         racket/cmdline)

(define parser (new riscv-parser%))
(define machine (new riscv-machine%))

;; Parse command line arguments
(define cores 4)
(define dir "output")
(define hybrid #t)
(define time-limit 3600)
(define size #f)
(define prog-file #f)
(define cost-file #f)

(define-values (given-cores given-dir given-time sym-mode stoch-mode enum-mode hybrid-mode given-size given-cost)
  (command-line
   #:once-each
   [("-c" "--core") c "Number of cores (default: 4)" (set! cores (string->number c))]
   [("-d" "--dir") d "Output directory (default: output)" (set! dir d)]
   [("-t" "--time-limit") t "Time limit in seconds" (set! time-limit (string->number t))]
   [("-s" "--size") s "Maximum size" (set! size (string->number s))]
   [("--cost") cost "Cost model file" (set! cost-file cost)]
   [("--sym") "Use symbolic search" (values #t #f #f #f)]
   [("--stoch") "Use stochastic search" (values #f #t #f #f)]
   [("--enum") "Use enumerative search" (values #f #f #t #f)]
   [("--hybrid") "Use hybrid search" (values #f #f #f #t)]
   #:args (filename)
   (set! prog-file filename)
   (values cores dir time-limit
           sym-mode stoch-mode enum-mode hybrid-mode
           size cost-file)))

;; Load cost model if provided
(define cost-model
  (if (and given-cost (file-exists? given-cost))
      (begin
        (pretty-display (format "Loading cost model from: ~a" given-cost))
        (with-input-from-file given-cost read))
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
(define symbolic (new riscv-symbolic% [machine machine] [printer printer]
                       [validator validator] [simulator simulator-racket]))
(define stochastic (new riscv-stochastic% [machine machine] [printer printer] [parser parser]
                         [validator validator] [simulator simulator-racket]))
(define forwardbackward (new riscv-forwardbackward% [machine machine] [printer printer] [parser parser]))

;; Load and parse program
(define code (send parser ast-from-file prog-file))
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
       [config 0] [syn-mode #t]))

;; Determine search type
(define-values (sym-cores stoch-cores enum-cores)
  (cond
    [sym-mode (values given-cores 0 0)]
    [stoch-mode (values 0 given-cores 0)]
    [enum-mode (values 0 0 given-cores)]
    [else (values 0 given-cores 0)]))  ; Default to stochastic

(pretty-display (format "SEARCH TYPE: sym=~a stoch=~a enum=~a size=~a"
                       sym-cores stoch-cores enum-cores given-size))

(when cost-model
  (pretty-display "Using custom cost model"))

;; Run optimization
(send driver optimize code
      #:prefix (send parser ast-from-string "")
      #:forwardbackward forwardbackward
      #:prefix-info prefix-info
      #:output-dir given-dir
      #:cores-sym sym-cores
      #:cores-stoch stoch-cores
      #:cores-enum enum-cores
      #:time-limit given-time
      #:size given-size)