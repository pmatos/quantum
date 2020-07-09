#lang racket/base
;; ---------------------------------------------------------------------------------------------------

(require "quantum-lib/quantum.rkt"
         "quantum-lib/params.rkt")

;; ---------------------------------------------------------------------------------------------------

(module+ main

  (require racket/cmdline)

  (define cmd
    (command-line
     #:program "quantum"
     #:once-any
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
     (unless (p/measure-mode)
       (fprintf (current-error-port)
                "Specify a measurement mode: time (with -t) or memory (with -m)~n")
       (exit 0))

     cmd))

  (run-cmd cmd))
