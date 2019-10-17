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

(require json
         plot/no-gui
         racket/function
         racket/list
         racket/string)

;; ---------------------------------------------------------------------------------------------------

(define p/output-plot (make-parameter "plot.png"))
(define p/plot-h (make-parameter 1024))
(define p/plot-w (make-parameter 1024))

(define (get-renderer i p)
  (define name (car p))
  (define data (cdr p))
  (lines data #:label name #:color i))

(define (compare vs)
  (define data
    (for/list ([v (in-list vs)])
      (cons (car v)
            (for/list ([p (in-list (with-input-from-file (cdr v)
                                     (thunk (read-json))))])
              (define time (first p))
              (define mem (second p))
              ;; convert time to seconds and mem to mb
              (list (/ time 1000.0) mem)))))
  (plot-file
   (map get-renderer (range (length data)) data)
   #:x-min 0
   #:y-min 0
   #:width (p/plot-w)
   #:height (p/plot-h)
   #:title "Memory Allocation"
   #:x-label "Time (sec)"
   #:y-label "Mem (Mb)"
   (p/output-plot)))

(module+ main

  (require racket/cmdline
           racket/list)

  (define cmd
    (command-line
     #:program "tracket-cmp"
     #:once-each
     [("--output") path "Output comparison plot to path"
                   (p/output-plot path)]
     #:args vs
     ;; vs are of the form <NAME>:<PATH-json>
     ;; where <NAME> is a string and <PATH-json> is a valid path to a json file output by tracket
     ;; Here we split the name and the path and check all is ok.
     (for/list ([v (in-list vs)])
       (define splitv (string-split v ":" #:trim? #true #:repeat? #true))
       (unless (= (length splitv) 2)
         (error 'tracket-cmp "argument cannot be split: ~a" splitv))

       (define name (first splitv))
       (define path (second splitv))

       (unless (file-exists? path)
         (error 'tracket-cmp "path does not exist: ~a" path))

       (cons name path))))

  (when (check-duplicates cmd string=?
                            #:key car
                            #:default #false)
    (error 'tracket-cmp "duplicate names not allowed: ~a"
           (map car cmd)))

  (printf "Comparing:~n")
  (for ([p (in-list cmd)])
    (printf "~a: ~a~n" (car p) (cdr p)))

  (compare cmd)
  (printf "Output: ~a~n" (p/output-plot)))
