#lang racket/base
;; ---------------------------------------------------------------------------------------------------

(require "params.rkt"
         "posix.rkt"
         json
         plot
         racket/format
         racket/function
         racket/list
         racket/match
         racket/port
         racket/string)

(provide track-subprocess
         plot-to-file
         json-to-file
         run-cmd)

;; ---------------------------------------------------------------------------------------------------

;; To track a procedure we will probably have to play the game where we
;; actually degenerate into tracking a racket subprocess that executes the
;; procedure. We actually lift the thunk to be at the top-level of a module,
;; and call it.
;(define (track-procedure thunk)

(struct measurement (start end mem-ticks)
  #:transparent)

(define (track-subprocess parent
                          pid
                          #:memory-accounting? [mem? #true]
                          #:progress? [progress? #true]
                          #:interval [secs (/ (p/ms-interval) 1000.0)])
  (printf "Tracking process ~a~n" pid)
  (define start (current-inexact-milliseconds))
  (let loop ([lst (if mem?
                      (list (cons 0 (read-current-memory-use pid)))
                      '())])
    (when (and mem? progress?)
      (printf "~a: ~a~n"
              (round (- (current-inexact-milliseconds) start))
              (cdar lst)))

    (sync (handle-evt
           (thread-receive-evt)
           (lambda (_)
             (thread-send parent
                          (measurement start (current-inexact-milliseconds) lst))))
          (handle-evt
           (if mem?
               (alarm-evt (+ (current-inexact-milliseconds) (* secs 1000)))
               never-evt)
           (lambda (_)
             (with-handlers ([exn:fail:filesystem:errno?
                              (lambda (e) (loop lst))])
               (define mem (read-current-memory-use pid))
               (define now (current-inexact-milliseconds))
               (when (p/output-to-stdout)
                 (printf "~a ~a~n"
                         now
                         (~r (/ (* pagesize mem)
                                (* 1024 1024))
                             #:precision 2)))
               (sleep secs)
               (loop (cons (cons (- now start) mem) lst))))))))

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

(define (run-cmd cmd)

  (define exe (first cmd))
  (define args (rest cmd))

  (define exepath
    (if (absolute-path? exe)
        exe
        (path->string (find-executable-path exe))))

  (printf "Running command line ~a ~a~n"
          exepath (string-join args))
  (printf "Page size for your system is ~a bytes~n" pagesize)

  (define-values (sp out in err)
    (apply subprocess
           (current-output-port)
           (current-input-port)
           (current-error-port)
           exepath args))

  (define parent (current-thread))
  (define monitor
    (thread
     (thunk (track-subprocess parent
                              (subprocess-pid sp)
                              #:memory-accounting? (eq? (p/measure-mode) 'mem)))))
  (subprocess-wait sp)
  (define exitcode (subprocess-status sp))

  (thread-send monitor 'done)
  (match-define (struct measurement (start end data)) (thread-receive))
  (thread-wait monitor)

  (unless (zero? exitcode)
    (fprintf (current-error-port) "Process exited with non-zero output: ~a~n" exitcode))

  (when (and (eq? (p/measure-mode) 'mem) data)
    (printf "Process finished (in ~ams), gathered ~a records (once every ~ams)~n"
            (round (- end start))
            (length data)
            (~r (/ (round (- end start)) (length data))
                #:precision 2))

    ;; Tranform size into Megabytes
    (define rdata
      (for/list ([p (in-list data)])
        (cons (car p)
              (exact->inexact (/ (* pagesize (cdr p))
                                 (* 1024 1024))))))
    (printf "Maximum virtual memory used: ~aMb~n" (~r (apply max (map cdr rdata))
                                                      #:precision 2))
    (when (p/write-plot)
      (plot-to-file (p/write-plot) rdata))
    (when (p/write-json)
      (json-to-file (p/write-json) rdata))))
