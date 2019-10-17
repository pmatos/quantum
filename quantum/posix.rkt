#lang racket/base
;; ---------------------------------------------------------------------------------------------------

(require ffi/unsafe
         racket/function
         racket/list)

(provide pagesize)

;; ---------------------------------------------------------------------------------------------------

(define get-page-size (get-ffi-obj "getpagesize" #false (_fun -> _int)))
(define pagesize (get-page-size))

(define (read-current-memory-use pid)
  (with-input-from-file (format "/proc/~a/statm" pid)
    (thunk
     (second
      (regexp-match #px"^[0-9]+ ([0-9]+) [0-9]+ [0-9]+ [0-9]+ [0-9]+ [0-9]+$"
                    (read-line))))))
