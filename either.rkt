#lang at-exp racket/base

;; todo: finish the rest of the pkg necessities: info.rkt, tests, so on.

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
         (contract-out
          [hash-ref/either ({hash? any/c} {string?} . ->* . (either/c any/c))]
          [first/either ({list?} {string?} . ->* . (either/c any/c))]
          [fail-if (boolean? string? . -> . (either/c false?))]))

(require (for-syntax syntax/parse
                     racket/base)
         racket/bool
         racket/format
         racket/list
         racket/match)

(struct failure (msg) #:prefab)

(define (either/c v-ctc)
  (or/c failure? v-ctc))

(define-syntax (either-let* stx)
  (syntax-parse stx
    [(_ {~optional {~seq #:extra-failure-message extra-msg}}
        [pat:expr maybe-value:expr] more-clauses ... result)
     #'(match maybe-value
         [(failure msg)
          (failure {~? (~a extra-msg msg) msg})]
         [pat
          (either-let* more-clauses ... result)])]
    [(_ {~optional {~seq #:extra-failure-message _}} result)
     #'(success result)]))

(define (hash-ref/either h k [fail-msg @~a{Key '@k' not found}])
  (match h
    [(hash-table [(== k) v] _ ...) v]
    [else                          (failure fail-msg)]))

(define (first/either l [failure-msg "empty"])
  (if (empty? l) (failure failure-msg) (first l)))

(define (fail-if bool msg)
  (or bool (failure msg)))

(define (in-success v)
  (in-list (match v
             [(? failure?) empty]
             [else (list v)])))

