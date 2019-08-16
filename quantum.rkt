#lang racket/base
;; ---------------------------------------------------------------------------------------------------

(require json
         racket/list
         racket/port
         racket/function)

(provide measure)

;; ---------------------------------------------------------------------------------------------------

(define (measure1 exe . args)
  (define-values (exit-code spent real gc)
    (time-apply
     (thunk
      (define-values (p out in err)
        (apply subprocess
               #false
               #false
               'stdout
               exe args))
      (close-output-port in)
      (thread (thunk (copy-port out (open-output-nowhere))))
      (subprocess-wait p)
      (subprocess-status p))
     '()))
    (unless (zero? (first exit-code))
      (printf "returned with non-zero exit code~n"))
  real)


(define (measure exe . args)
  (define measurements
    (for/list ([i (in-list (range 100))])
      (cons i (apply measure1 exe args))))
  (write-json (for/list ([m (in-list measurements)])
                (make-hash `((iteration . ,(car m))
                             (millisecs . ,(cdr m)))))))
