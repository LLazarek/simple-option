#lang racket/base

(require racket/contract/base)

(provide absent
         absent?
         option/c
         option-let*
         in-option
         for/first/option
         (contract-out
          [fail-if (boolean? . -> . (option/c false?))]

          [hash-ref/option (hash? any/c . -> . (option/c any/c))]
          [first/option (list? . -> . (option/c any/c))]))

(require racket/bool
         racket/list
         racket/match
         syntax/parse/define
         (for-syntax racket/base))

(define-values {absent absent?}
  (let ()
    (struct absent ())
    (values (absent) absent?)))

(define (option/c inner/c)
  (or/c absent? inner/c))

(define (in-option o)
  (in-list (match o
             [(? absent?) empty]
             [else (list o)])))

(define-simple-macro (for/first/option clauses body ...)
  (let/ec return
    (for* clauses
      (return (let () body ...)))
    absent))

(define-syntax (option-let* stx)
  (syntax-parse stx
    [(_ ([pat:expr maybe-value:expr]
         more-clauses ...)
        body ...)
     (syntax/loc stx
       (match maybe-value
         [(? absent? a) a]
         [pat (option-let* (more-clauses ...) body ...)]
         [else absent]))]
    [(_ () body ...)
     (syntax/loc stx
       (let () body ...))]))

(define (fail-if bool)
  (and bool absent))

(define (hash-ref/option h k)
  (match h
    [(hash-table [(== k) v] _ ...) v]
    [else                          absent]))

(define (first/option l)
  (if (empty? l) absent (first l)))

(module+ test
  (require ruinit)

  (test-begin
    #:name in-option
    (test-equal? (for/list ([x (in-option 5)]) x)
                 '(5))
    (test-equal? (for/list ([x (in-option absent)]) x)
                 '()))

  (test-begin
    #:name for/first/option
    (test-equal? (for/first/option ([i '(3 5 7)]
                                    #:when (even? i))
                   i)
                 absent)
    (test-equal? (for/first/option ([i '(3 5 2 7)]
                                    #:when (even? i))
                   i)
                 2))

  (test-begin
    #:name option-let*
    (test-equal? (option-let* () 5) 5)
    (test-equal? (option-let* ([x 5])
                              x)
                 5)
    (test-equal? (option-let* ([x absent])
                              x)
                 absent)
    (test-equal? (option-let* ([x 5]
                               [y absent])
                              (+ x y))
                 absent)
    (test-equal? (option-let* ([x 5]
                               [y (+ x 5)])
                              (+ x y))
                 15))

  (test-begin
    #:name fail-if
    (test-equal? (option-let* ([x 5]
                               [y (fail-if (odd? x))])
                              (/ x 2))
                 absent)
    (test-equal? (option-let* ([x 10]
                               [y (fail-if (odd? x))])
                              (/ x 2))
                 5))

  (test-begin
    #:name hash-ref/option
    (test-equal? (hash-ref/option (hash) 'a)
                 absent)
    (test-equal? (hash-ref/option (hash 'a 5) 'a)
                 5))
  
  (test-begin
    #:name first/option
    (test-equal? (first/option empty)
                 absent)
    (test-equal? (first/option '(5))
                 5)))
