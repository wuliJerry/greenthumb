#lang racket
(require (file "/home/allenjin/Codes/greenthumb_jerry/riscv/riscv-parser.rkt") (file "/home/allenjin/Codes/greenthumb_jerry/riscv/riscv-machine.rkt") (file "/home/allenjin/Codes/greenthumb_jerry/riscv/riscv-printer.rkt") (file "/home/allenjin/Codes/greenthumb_jerry/riscv/riscv-simulator-racket.rkt") (file "/home/allenjin/Codes/greenthumb_jerry/riscv/riscv-simulator-rosette.rkt") (file "/home/allenjin/Codes/greenthumb_jerry/riscv/riscv-validator.rkt") (file "/home/allenjin/Codes/greenthumb_jerry/riscv/riscv-symbolic.rkt"))
(define machine (new riscv-machine% [config 4]))
(define printer (new riscv-printer% [machine machine]))
(define parser (new riscv-parser%))
(define simulator-racket (new riscv-simulator-racket% [machine machine]))
(define simulator-rosette (new riscv-simulator-rosette% [machine machine]))
(define validator (new riscv-validator% [machine machine] [simulator simulator-rosette]))
(define search (new riscv-symbolic% [machine machine] [printer printer] [parser parser] [validator validator] [simulator simulator-rosette] [syn-mode `linear]))
(define prefix (send parser ir-from-string "
"))
(define code (send parser ir-from-string "
addi x2, x1, 1
addi x3, x2, 1
addi x0, x3, -2
"))
(define postfix (send parser ir-from-string "
"))
(define encoded-prefix (send printer encode prefix))
(define encoded-code (send printer encode code))
(define encoded-postfix (send printer encode postfix))
(send search superoptimize encoded-code (send printer encode-live '(0)) "output-test2/0/driver-0" 10 #f #:assume #f #:input-file #f #:start-prog #f #:prefix encoded-prefix #:postfix encoded-postfix)
