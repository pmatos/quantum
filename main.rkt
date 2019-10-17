#lang racket/base
;; ---------------------------------------------------------------------------------------------------

(require "quantum/quantum.rkt"
         "quantum/posix.rkt"
         ffi/unsafe
         plot/no-gui
         racket/format
         racket/function
         json
         racket/list
         racket/match
         racket/string)

;; ---------------------------------------------------------------------------------------------------

; Command line argument parameters
(define p/write-json (make-parameter #false))
(define p/write-plot (make-parameter #false))
(define p/output-to-stdout (make-parameter #false))
(define p/ms-interval (make-parameter 500)) ; half a second by default
(define p/measure-mode (make-parameter 'full))

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
     (thunk (track-subprocess parent (subprocess-pid sp)))))
  (subprocess-wait sp)
  (define exitcode (subprocess-status sp))

  (thread-send monitor 'done)
  (match-define (list data start end) (thread-receive))
  (thread-wait monitor)

  (unless (zero? exitcode)
    (fprintf (current-error-port) "Process exited with non-zero output: ~a~n" exitcode))

  (when data
    (printf "Process finished (in ~ams), gathered ~a records (once every ~ams)~n"
            (round (- end start))
            (length data)
            (~r (/ (round (- end start)) (length data))
                #:precision 2))

    ;; Tranform size into Megabytes
    (define rdata
      (for/list ([p (in-list data)])
        (cons (car p)
              (exact->inexact (/ (* pagesize (string->number (cdr p)))
                                 (* 1024 1024))))))
    (printf "Maximum virtual memory used: ~aMb~n" (~r (apply max (map cdr rdata))
                                                      #:precision 2))
    (when (p/write-plot)
      (plot-to-file (p/write-plot) rdata))
    (when (p/write-json)
      (json-to-file (p/write-json) rdata))))

(module+ main

  (require racket/cmdline)

  (define cmd
    (command-line
     #:program "quantum"
     [("-f" "--measure-full") "Full measurements"
                      (p/measure-mode 'full)]
     [("-m" "--measure-memory") "Run only for memory measurements"
                                (p/measure-mode 'mem)]
     [("-t" "--measure-time") "Run only for time measurements"
                              (p/measure-mode 'time)]
     #:once-each
     [("-i" "--interval") interval "Interval in milliseconds to check memory usage (default: 500)"
                          (p/ms-interval (string->number interval))]
     [("-o" "--stdout") "Output results to stdout"
                        (p/output-to-stdout #true)]
     [("-p" "--plot") path "Plot memory allocation over time"
                      (p/write-plot path)]
     [("-j" "--json") path "Write data to json file"
                      (p/write-json path)]
     #:args cmd
     cmd))

  (run-cmd cmd))
