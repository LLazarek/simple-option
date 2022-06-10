#lang scribble/manual

@(require scribble/core)

@;;;;;;;;;;;;;;;@
@; Boilerplate ;@
@;;;;;;;;;;;;;;;@

@(require (for-label (except-in racket absent)
                     simple-option)
          scribble/example)

@(define simple-option-eval (make-base-eval))
@examples[#:eval simple-option-eval #:hidden (require (except-in racket absent) simple-option/option)]

@title{simple-option}
@author{Lukas Lazarek}

This library provides a minimalist and untyped-y take on the classic @tt{option} and @tt{either} data types.
In particular, these data types traditionally explicitly distinguish successful computation results from failures with a @tt{present} wrapper structure (often also called @tt{just}, or @tt{success} for either).
This library drops those wrappers.
Successful results are just themselves, and only failures are indicated with a special value.

This is usually convenient, but beware that it does sacrifice expressiveness.
In particular, this design makes it impossible to distinguish situations like this, and all variations on it:
@examples[#:eval simple-option-eval
(first/option (list absent))
(first/option (list))
]


@section{option}
@defmodule[simple-option]

@deftogether[(
@defthing[absent (option/c any/c)]
@defproc[(absent? [v any/c]) boolean?]
)]{
The unique value representing the absence of a value / result, and a predicate recognizing it.

@examples[#:eval simple-option-eval
(define (try-parse-number s)
  (or (string->number s) absent))
(try-parse-number "5")
(try-parse-number "nope")
(absent? (try-parse-number "nope"))
]
}

@defproc[(option/c [inner contract?]) contract?]{
Creates a contract recognizing either @racket[absent] or @racket[inner].
}

@defform[(option-let* [pat expr] ... result-expr)]{
Sequence computations that may fail (produce @racket[absent]), short-circuiting to @racket[absent] if so.

Match the result of each @racket[expr] to each pattern @racket[pat] like @racket[match-let*], unless the result is @racket[absent].
If no @racket[expr] is @racket[absent], the result of the whole expression is @racket[result-expr].
If any @racket[expr] is absent or fails to match @racket[pat], then the result of the whole expression is @racket[absent], without evaluating any remaining clauses or the result expression.

@examples[#:eval simple-option-eval
(option-let* ([x 1]
              [(list y) '(2)])
             (+ x y))
(option-let* ([x absent]
              ; the rest is skipped
              [(list y) '(2)])
             (+ x y))
(define (fails-on-odd-numbers n)
  (if (even? n)
      (/ n 2)
      absent))
(option-let* ([x 1]
              [y (fails-on-odd-numbers 8)]
              [z (fails-on-odd-numbers y)])
             (+ x y z))
(option-let* ([x 1]
              [y (fails-on-odd-numbers 7)]
              (code:comment "the rest is skipped")
              [z (fails-on-odd-numbers y)])
             (+ x y z))
]
        }

@defproc[(fail-if [test any/c]) (or/c absent? #t)]{
Returns true if @racket[test] is non-false, otherwise returns @racket[absent].

@racket[fail-if] is mostly useful in @racket[option-let*], to explicitly short-circuit under a condition (see example below).

@examples[#:eval simple-option-eval
(option-let* ([x 5]
	      [_ (fail-if (odd? x))]
	      [z (/ x 2)])
	     (add1 z))
(option-let* ([x 8]
	      [_ (fail-if (odd? x))]
	      [z (/ x 2)])
	     (add1 z))
]
}

@defproc[(in-option [v (option/c any/c)]) (sequence/c any/c)]{
Returns the empty sequence given absent, otherwise a one-value sequence containing its argument (like @racket[in-value]).

@examples[#:eval simple-option-eval
(for/list ([x (in-option 5)]) x)
(for/list ([x (in-option absent)]) x)
]
}

@defform[(for/first/option clause ... body ...)]{
Like @racket[for/first], but returns absent instead of false in the case of no iterations.
}

@defproc[(hash-ref/option [h hash?] [k any/c]) (option/c any/c)]{
Equivalent to:
@verbatim{(hash-ref h k absent)}
}

@defproc[(first/option [l list?]) (option/c any/c)]{
Returns the first element of @racket[l] unless it is empty, in which case returns @racket[absent].
}

@section{either}
@defmodule[simple-option/either]

@tt{either} values are like @tt{option}s, but failures also carry an error message.
This module provides the same interface as for options, adapted to support error messages.

@defstruct*[failure ([msg string?]) #:prefab]{
The structure representing failure values, analagous to @racket[absent].

@examples[#:eval simple-option-eval #:hidden (require simple-option/either)]
@examples[#:eval simple-option-eval
(define (try-parse-number s)
  (or (string->number s) (failure "not a number")))
(try-parse-number "5")
(try-parse-number "nope")
(failure? (try-parse-number "nope"))
]
}

@defproc[(either/c [inner contract?]) contract?]{
Creates a contract recognizing either @racket[either] or @racket[inner].
}

@deftogether[(
@defform[(either-let* [pat expr maybe-extra-failure-message] ... result-expr)
#:grammar ([maybe-extra-failure-message (code:line) (code:line #:extra-failure-message msg-e)])]
@defproc[(fail-if [v any/c] [msg string?]) (either/c any/c)]
@defproc[(in-either [v (option/c any/c)]) (sequence/c any/c)]
@defform[(for/first/either clause ... maybe-failure-message body ...)
#:grammar ([maybe-failure-message (code:line) (code:line #:failure-message msg-e)])]
)]{
The either version of @racket[option-let*], @racket[fail-if], @racket[in-option], and @racket[for/first/option].
See the corresponding @racket[option] versions for details.
}

@defproc[(hash-ref/option [h hash?]
			  [k any/c]
			  [failure-msg string? (format "hash-ref/either: key ~e not found" k)])
         (option/c any/c)]{
Equivalent to:
@verbatim{(hash-ref h k (thunk (failure (format "hash-ref/either: key ~e not found" k))))}
}

@defproc[(first/option [l list?] [failure-msg string? "first/either: empty list"]) (option/c any/c)]{
Returns the first element of @racket[l] unless it is empty, in which case returns a @racket[failure] with the message @racket[failure-msg].
}

