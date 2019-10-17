#lang racket/base
;; ---------------------------------------------------------------------------------------------------

(require json
         racket/list
         racket/port
         racket/function)

(provide measure)

;; ---------------------------------------------------------------------------------------------------

;; To track a procedure we will probably have to play the game where we
;; actually degenerate into tracking a racket subprocess that executes the
;; procedure. We actually lift the thunk to be at the top-level of a module,
;; and call it.
;(define (track-procedure thunk)

(define (track-subprocess parent pid [every (/ (p/ms-interval) 1000.0)])
  (printf "Tracking process ~a~n" pid)
  (define start (current-inexact-milliseconds))
  (let loop ([lst (list (cons 0 (read-current-memory-use pid)))])
    (sync (handle-evt
           (thread-receive-evt)
           (lambda (_)
             (thread-send parent (list lst start (current-inexact-milliseconds)))))
          (handle-evt
           (alarm-evt (+ (current-inexact-milliseconds) (* every 1000)))
           (lambda (_)
             (with-handlers ([exn:fail:filesystem:errno?
                              (lambda (e) (loop lst))])
               (define mem (read-current-memory-use pid))
               (define now (current-inexact-milliseconds))
               (when (p/output-to-stdout)
                 (printf "~a ~a~n"
                         now
                         (~r (/ (* pagesize (string->number mem))
                                (* 1024 1024))
                             #:precision 2)))
               (sleep every)
               (loop (cons (cons (- now start) mem)
                           lst))))))))

(define (json-to-file path data)
  (define fdata
    (for/list ([p (in-list data)])
      (list (car p) (cdr p))))
  (with-output-to-file path
    (thunk (write-json fdata))
    #:exists 'replace))

(define (plot-to-file path data)
  (define fdata
    (for/list ([p (in-list data)])
      (list (car p) (cdr p))))
  (plot-file
   (list
    (lines fdata)
    (points fdata
            #:alpha 0.4
            #:sym 'fullcircle1
            #:color "black"))
   #:x-min 0
   #:y-min 0
   #:title "Virtual Memory Allocation"
   #:x-label "Time (ms)"
   #:y-label "Mem (Mb)"
   path))


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
