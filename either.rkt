#lang at-exp racket/base

;; This design does not explicitly wrap successes.
;; I find that this is often a convenient way to work with these things,
;; but it does have one issue to be aware of when using the helpers
;; `hash-ref/either` and `first/either`.
;; There's no way to distinguish these two scenarios:
;; (hash-ref/failure (hash) 'a "bad")
;; (hash-ref/failure (hash 'a (failure "bad")) "bad")
;;
;; In practice, I find this doesn't happen much, and if it does then
;; the messages are different, and since the earliest one is used it
;; doesn't pose a real problem -- it still accomplishes the job of
;; handling and reporting failures.

(require racket/contract/base)

(provide (struct-out failure)
         either/c
         either-let*
         in-success
         in-failure
         for/first/either
         (contract-out
          [fail-if (boolean? string? . -> . (either/c false?))]

          [hash-ref/either ({hash? any/c} {string?} . ->* . (either/c any/c))]
          [first/either ({list?} {string?} . ->* . (either/c any/c))]))

(require racket/bool
         racket/format
         racket/list
         racket/match
         syntax/parse/define
         (for-syntax racket/base))

(struct failure (msg) #:prefab)

(define (either/c v-ctc)
  (or/c failure? v-ctc))

(define-syntax (either-let* stx)
  (syntax-parse stx
    [(_ ([pat:expr maybe-value:expr
                   {~optional {~seq #:extra-failure-message extra-msg}}]
         more-clauses ...)
        body ...)
     (syntax/loc stx
       (match maybe-value
         [(failure msg)
          (failure {~? (~a extra-msg msg) msg})]
         [pat
          (either-let* (more-clauses ...) body ...)]))]
    [(_ () body ...)
     (syntax/loc stx
       (let () body ...))]))

(define (in-success v)
  (in-list (match v
             [(? failure?) empty]
             [else (list v)])))

(define (in-failure v)
  (in-list (match v
             [(failure msg) (list msg)]
             [else empty])))

(define-simple-macro (for/first/either clauses
                       {~optional {~seq #:failure-message msg}}
                       body ...)
  (let/ec return
    (for* clauses
      (return (let () body ...)))
    (failure {~? msg "for/first/either failed"})))

(define (fail-if bool msg)
  (and bool (failure msg)))

(define (hash-ref/either h k [fail-msg @~a{hash-ref/either: key @~e[k] not found}])
  (match h
    [(hash-table [(== k) v] _ ...) v]
    [else                          (failure fail-msg)]))

(define (first/either l [failure-msg "first/either: empty list"])
  (if (empty? l) (failure failure-msg) (first l)))

(module+ test
  (require ruinit)
  (test-begin
    #:name either-let*
    (test-equal? (either-let* () 5) 5)
    (test-equal? (either-let* ([x 5])
                              x)
                 5)
    (test-equal? (either-let* ([x (failure "bad")])
                              x)
                 (failure "bad"))
    (test-equal? (either-let* ([x 5]
                               [y (failure "bad")])
                              (+ x y))
                 (failure "bad"))
    (test-equal? (either-let* ([x 5]
                               [y (+ x 5)])
                              (+ x y))
                 15))

  (test-begin
    #:name fail-if
    (test-equal? (either-let* ([x 5]
                               [y (fail-if (odd? x) "bad x")])
                              (/ x 2))
                 (failure "bad x"))
    (test-equal? (either-let* ([x 10]
                               [y (fail-if (odd? x) "bad x")])
                              (/ x 2))
                 5))

  (test-begin
    #:name in-success
    (test-equal? (for/list ([x (in-success 5)])
                   x)
                 '(5))
    (test-equal? (for/list ([x (in-success (failure "bad"))])
                   x)
                 '()))

  (test-begin
    #:name in-failure
    (test-equal? (for/list ([x (in-failure 5)])
                   x)
                 '())
    (test-equal? (for/list ([m (in-failure (failure "bad"))])
                   m)
                 '("bad")))

  (test-begin
    #:name for/first/either
    (test-equal? (for/first/either ([i '(3 5 7)]
                                    #:when (even? i))
                   #:failure-message "no evens!"
                   i)
                 (failure "no evens!"))
    (test-equal? (for/first/either ([i '(3 5 2 7)]
                                    #:when (even? i))
                   #:failure-message "no evens!"
                   i)
                 2))

  (test-begin
    #:name hash-ref/either
    (test-equal? (hash-ref/either (hash) 'a)
                 (failure "hash-ref/either: key 'a not found"))
    (test-equal? (hash-ref/either (hash) 'a "bad")
                 (failure "bad"))
    (test-equal? (hash-ref/either (hash 'a 5) 'a)
                 5))
  
  (test-begin
    #:name first/either
    (test-equal? (first/either empty)
                 (failure "first/either: empty list"))
    (test-equal? (first/either empty "bad")
                 (failure "bad"))
    (test-equal? (first/either '(5))
                 5)))
