#lang racket
(require (file "/home/allenjin/Codes/greenthumb_jerry/riscv/riscv-parser.rkt") (file "/home/allenjin/Codes/greenthumb_jerry/riscv/riscv-machine.rkt") (file "/home/allenjin/Codes/greenthumb_jerry/riscv/riscv-printer.rkt") (file "/home/allenjin/Codes/greenthumb_jerry/riscv/riscv-simulator-racket.rkt") (file "/home/allenjin/Codes/greenthumb_jerry/riscv/riscv-simulator-rosette.rkt") (file "/home/allenjin/Codes/greenthumb_jerry/riscv/riscv-validator.rkt") (file "/home/allenjin/Codes/greenthumb_jerry/riscv/riscv-stochastic.rkt"))
(define machine (new riscv-machine% [config 3]))
(define printer (new riscv-printer% [machine machine]))
(define parser (new riscv-parser%))
(define simulator-racket (new riscv-simulator-racket% [machine machine]))
(define simulator-rosette (new riscv-simulator-rosette% [machine machine]))
(define validator (new riscv-validator% [machine machine] [simulator simulator-rosette]))
(define search (new riscv-stochastic% [machine machine] [printer printer] [parser parser] [validator validator] [simulator simulator-racket] [syn-mode #f]))
(define prefix (send parser ir-from-string "
"))
(define code (send parser ir-from-string "
srai x2, x1, 4
"))
(define postfix (send parser ir-from-string "
"))
(define encoded-prefix (send printer encode prefix))
(define encoded-code (send printer encode code))
(define encoded-postfix (send printer encode postfix))
(send search superoptimize encoded-code (send printer encode-live '#(#(#f #f #f #f) #f)) "alternatives-all/srai/0/driver-2" 120 #f #:assume #f #:input-file #f #:start-prog #f #:prefix encoded-prefix #:postfix encoded-postfix)
