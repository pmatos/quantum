;;     LL-Tracket is a low-level application performance tracker
;;     Copyright (C) 2019 Paulo Matos

;;     This program is free software: you can redistribute it and/or modify
;;     it under the terms of the GNU General Public License as published by
;;     the Free Software Foundation, either version 3 of the License, or
;;     (at your option) any later version.

;;     This program is distributed in the hope that it will be useful,
;;     but WITHOUT ANY WARRANTY; without even the implied warranty of
;;     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;     GNU General Public License for more details.

;;     You should have received a copy of the GNU General Public License
;;     along with this program. If not, see <https://www.gnu.org/licenses/>.

#lang racket/base
;; ---------------------------------------------------------------------------------------------------

(require ffi/unsafe
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

(define get-page-size (get-ffi-obj "getpagesize" #false (_fun -> _int)))
(define pagesize (get-page-size))

(define (read-current-memory-use pid)
  (with-input-from-file (format "/proc/~a/statm" pid)
    (thunk
     (second
      (regexp-match #px"^[0-9]+ ([0-9]+) [0-9]+ [0-9]+ [0-9]+ [0-9]+ [0-9]+$"
                    (read-line))))))

;; To track a procedure we will probably have to play the game where we
;; actually degenerate into tracking a racket subprocess that executes the
;; procedure. We actually lift the thunk to be at the top-level of a module,
;; and call it.
(define (track-procedure thunk)

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
     #:program "ll-tracket"
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
