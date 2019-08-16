#lang racket/base
;; ---------------------------------------------------------------------------------------------------

(require "quantum.rkt")

;; ---------------------------------------------------------------------------------------------------

(module+ main
  (require racket/cmdline)

  (measure "/home/pmatos/installs/racket-7.3/bin/racket" "-e" "(exit)"))
