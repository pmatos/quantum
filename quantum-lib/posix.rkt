#lang racket/base
;; ---------------------------------------------------------------------------------------------------

(require ffi/unsafe
         (prefix-in c: racket/contract)
         racket/function
         racket/list)

(provide
 (c:contract-out
  [pagesize exact-positive-integer?]
  [read-current-memory-use (c:-> exact-positive-integer? exact-positive-integer?)]
  [sched-getaffinity (c:-> exact-nonnegative-integer? exact-nonnegative-integer?)]
  [sched-setaffinity (c:-> exact-nonnegative-integer? exact-nonnegative-integer? void?)]))

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



;; ---------------------------------------------------------------------------------------------------

;
; Access to sched_ functions
;

(define _pid _ulong)
(define _cpu_set_t _ulong)

(define (check v who)
  (unless (zero? v)
    (error who "failed: ~a" v)))

(define _sched_getaffinity (get-ffi-obj "sched_getaffinity" #false
                                        (_fun _pid _size (o : (_ptr o _cpu_set_t))
                                              -> (r : _int)
                                              -> (begin0 o (check r 'sched_getaffinity)))))

(define _sched_setaffinity (get-ffi-obj "sched_setaffinity" #false
                                        (_fun _pid _size (i : (_ptr i _cpu_set_t))
                                              -> (r : _int)
                                              -> (check r 'sched_setaffinity))))
; external sched_getaffinity
(define (sched-getaffinity pid)
  (_sched_getaffinity pid (ctype-sizeof _cpu_set_t)))

(define (sched-setaffinity pid mask)
  (_sched_setaffinity pid (ctype-sizeof _cpu_set_t) mask))

;; ---------------------------------------------------------------------------------------------------
