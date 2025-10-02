#lang racket

(require "../printer.rkt" "../inst.rkt" "riscv-machine.rkt")

(provide riscv-printer%)

(define riscv-printer%
  (class printer%
    (super-new)
    (inherit-field machine)
    (override encode-inst decode-inst print-syntax-inst)

    ;; Print in the assembly format.
    ;; x: string IR
    (define (print-syntax-inst x [indent ""])
      ;; RISC-V format: instruction rd, rs1, rs2
      (pretty-display (format "~a~a ~a"
                              indent
                              (inst-op x)
                              (string-join (vector->list (inst-args x)) ", "))))

    ;; Convert an instruction x from string-IR to encoded-IR format.
    (define (encode-inst x)
      (define opcode-name (inst-op x))

      (cond
       [opcode-name
        (define args (inst-args x))

        ;; Convert argument from string to number
        (define (convert-arg arg)
          (define first-char (substring arg 0 1))
          (cond
           [(or (equal? first-char "x") (equal? first-char "r"))
            (string->number (substring arg 1))]
           [else
            (string->number arg)]))

        (inst (send machine get-opcode-id (string->symbol opcode-name))
              (vector-map convert-arg args))]

       ;; opcode-name is #f, x is an unknown instruction (a place holder for synthesis)
       [else x]))

            

    ;; Convert an instruction x from encoded-IR to string-IR format.
    (define (decode-inst x)
      (define opcode-id (inst-op x))
      ;; get-opcode-name returns symbol, so we need to convert it to string
      (define opcode-name (symbol->string (send machine get-opcode-name opcode-id)))
      (define arg-types (send machine get-arg-types opcode-id))
      (define args (inst-args x))

      (define new-args
        (for/vector ([arg args] [type arg-types])
                    (cond
                     [(equal? type 'reg) (format "x~a" arg)]
                     [else (number->string arg)])))

      (inst opcode-name new-args))

    ;;;;;;;;;;;;;;;;;;;;;;;;; For cooperative search ;;;;;;;;;;;;;;;;;;;;;;;
    ;; Convert live-out (the output from parser::info-from-file) into string.
    ;; The string will be used as a piece of code the search driver generates as
    ;; the live-out argument to the method superoptimize of
    ;; stochastics%, forwardbackward%, and symbolic%.
    ;; The string should be evaluated to a program state that contains
    ;; #t and #f, where #t indicates that the corresponding element is live.
    (define/override (output-constraint-string live-out)
      ;; Method encode-live is implemented below, returning
      ;; live infomation in a program state format.
      (format "(send printer encode-live '~a)" live-out))

    ;; Convert liveness infomation to the same format as program state.
    (define/public (encode-live x)
      ;; If x is a list, iterate over elements in x, and set those elements to be live.
      (define reg-live (make-vector (send machine get-config) #f))
      (define mem-live #f)
      (for ([v x])
           (cond
            [(number? v) (vector-set! reg-live v #t)]
            [(equal? v 'memory) (set! mem-live #t)]))
      (progstate reg-live mem-live))

    ;; Return program state config from a given program in string-IR format.
    ;; program: string IR format
    ;; output: program state config
    (define/override (config-from-string-ir program)
      ;; config = number of registers
      ;; Find the highest register ID and return that as a config
      (define max-reg 0)
      (for* ([x program]
	     [arg (inst-args x)])
            (when (or (equal? "x" (substring arg 0 1))
                      (equal? "r" (substring arg 0 1)))
                  (let ([id (string->number (substring arg 1))])
                    (when (> id max-reg) (set! max-reg id)))))
      (add1 max-reg))
    
    ))

