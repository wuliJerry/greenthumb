#lang racket

(require parser-tools/lex
         (prefix-in re- parser-tools/lex-sre)
         parser-tools/yacc
	 "../parser.rkt" "../inst.rkt")

(provide riscv-parser%)

;; This is a Racket Lex Yacc parser.
;; Refer to the follow resources to complete this file.
;; - Lexer:   http://docs.racket-lang.org/parser-tools/Lexers.html
;; - Parser:  http://docs.racket-lang.org/parser-tools/LALR_1__Parsers.html
;; - Example: https://gist.github.com/danking/1068185
(define riscv-parser%
  (class parser%
    (super-new)
    (inherit-field asm-parser asm-lexer)
    (init-field [compress? #f])
    
    (define-tokens a (WORD NUM REG)) ;; add more tokens
    (define-empty-tokens b (EOF HOLE COMMA)) ;; add more tokens

    (define-lex-abbrevs
      (line-comment (re-: (re-: "#" (re-* (char-complement #\newline))) #\newline))
      (digit10 (char-range "0" "9"))
      (number10 (number digit10))
      (snumber10 (re-or number10 (re-seq "-" number10)))

      (identifier-characters (re-or (char-range "A" "Z") (char-range "a" "z")))
      (identifier-characters-ext (re-or digit10 identifier-characters "_"))
      (identifier (re-seq identifier-characters
                          (re-* (re-or identifier-characters digit10))))
      ;; RISC-V register names: x0-x31 or r0-r31
      (reg (re-or (re-seq "x" number10) (re-seq "r" number10)))
      )

    ;; Complete lexer
    (set! asm-lexer
      (lexer-src-pos
       ("?"        (token-HOLE))
       (","        (token-COMMA))
       (reg        (token-REG lexeme))
       (snumber10  (token-NUM lexeme))
       (identifier (token-WORD lexeme))
       (line-comment (position-token-token (asm-lexer input-port)))
       (whitespace   (position-token-token (asm-lexer input-port)))
       ((eof) (token-EOF))))

    ;; Complete parser
    (set! asm-parser
      (parser
       (start program)
       (end EOF)
       (error
        (lambda (tok-ok? tok-name tok-value start-pos end-pos)
          (raise-syntax-error 'parser
                              (format "syntax error at '~a' in src l:~a c:~a"
                                      tok-name
                                      (position-line start-pos)
                                      (position-col start-pos)))))
       (tokens a b)
       (src-pos)
       (grammar

        (arg  ((REG) $1)
              ((NUM) $1))

        (args ((arg) (list $1))
              ((arg COMMA args) (cons $1 $3)))

        (instruction
         ((WORD args)    (inst $1 (list->vector $2)))

         ;; when parsing ?, return (inst #f #f) as an unknown instruction
         ;; (a place holder for synthesis)
         ((HOLE)         (inst #f #f)))

        (code
         (() (list))
         ((instruction code) (cons $1 $2)))

        (program
         ((code) (list->vector $1)))
       )))


    ;;;;;;;;;;;;;;;;;;;;;;;;; For cooperative search ;;;;;;;;;;;;;;;;;;;;;;;
    ;; Required method if using cooperative search driver.
    ;; Read from file and convert file content into the format we want.
    ;; Info usually includes live-out information.
    (define/override (info-from-file file)
      ;; read from file
      (define lines (file->lines file))
      (define live-out-str (first lines))
      ;; Parse comma-separated register indices
      (define live-out
        (if (equal? live-out-str "")
            '()
            (map string->number (string-split live-out-str ","))))
      live-out)

    ))

