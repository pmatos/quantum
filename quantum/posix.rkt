#lang racket/base
;; ---------------------------------------------------------------------------------------------------

(require ffi/unsafe
         (prefix-in c: racket/contract)
         racket/function
         racket/list)

(provide
 (c:contract-out
  [pagesize exact-positive-integer?]
  [read-current-memory-use (c:-> exact-positive-integer? exact-positive-integer?)]))

;; ---------------------------------------------------------------------------------------------------

(define get-page-size (get-ffi-obj "getpagesize" #false (_fun -> _int)))
(define pagesize (get-page-size))

(define (read-current-memory-use pid)
  (with-input-from-file (format "/proc/~a/statm" pid)
    (thunk
     (string->number
      (second
       (regexp-match #px"^[0-9]+ ([0-9]+) [0-9]+ [0-9]+ [0-9]+ [0-9]+ [0-9]+$"
                     (read-line)))))))
