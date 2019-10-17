#lang racket/base
;; ---------------------------------------------------------------------------------------------------

(require racket/contract)

(provide
 (contract-out
  [p/write-json (parameter/c boolean?)]
  [p/write-plot (parameter/c boolean?)]
  [p/output-to-stdout (parameter/c boolean?)]
  [p/ms-interval (parameter/c exact-positive-integer?)]
  [p/measure-mode (parameter/c (or/c #false 'mem 'time))]))

;; ---------------------------------------------------------------------------------------------------

; Command line argument parameters
(define p/write-json (make-parameter #false))
(define p/write-plot (make-parameter #false))
(define p/output-to-stdout (make-parameter #false))
(define p/ms-interval (make-parameter 500)) ; half a second by default
(define p/measure-mode (make-parameter #false))
