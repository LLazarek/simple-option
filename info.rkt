#lang info

(define collection "simple-option")
(define deps '("base"
               "git://github.com/llazarek/ruinit.git"))
(define build-deps '("scribble-lib"
                     "racket-doc"
                     "at-exp-lib"))
(define pkg-desc "Simple (minimal) option and either datatypes")
(define pkg-authors '(lukas))
(define scribblings '(("scribblings/simple-option.scrbl" ())))

