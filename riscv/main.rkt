#lang racket

(require "../parallel-driver.rkt" "../inst.rkt"
         "riscv-parser.rkt" "riscv-machine.rkt" 
         "riscv-printer.rkt"
	 ;; simulator, validator
	 "riscv-simulator-racket.rkt" 
	 "riscv-simulator-rosette.rkt"
         "riscv-validator.rkt")

(provide optimize)

;; Main function to perform superoptimization on multiple cores.
;; >>> INPUT >>>
;; code: program to superoptimized in string-IR format
;; >>> OUTPUT >>>
;; Optimized code in string-IR format.
(define (optimize code live-out search-type mode
                  #:dir [dir "output"] 
                  #:cores [cores 4]
                  #:time-limit [time-limit 3600]
                  #:size [size #f]
                  #:window [window #f]
                  #:input-file [input-file #f])
  
  (define parser (new riscv-parser%))
  (define machine (new riscv-machine%))
  (define printer (new riscv-printer% [machine machine]))
  (define simulator (new riscv-simulator-rosette% [machine machine]))
  (define validator (new riscv-validator% [machine machine] [simulator simulator]))
  (define parallel (new parallel-driver% [isa "riscv"] [parser parser] [machine machine] 
                        [printer printer] [validator validator]
                        [search-type search-type] [mode mode]
                        [window window]))

  (send parallel optimize code live-out 
        #:dir dir #:cores cores 
        #:time-limit time-limit #:size size #:input-file input-file)
  )

