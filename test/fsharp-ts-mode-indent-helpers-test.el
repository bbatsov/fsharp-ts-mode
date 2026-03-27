;;; fsharp-ts-mode-indent-helpers-test.el --- Tests for indentation helpers -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for shift-region and guess-indent-offset.

;;; Code:

(require 'fsharp-ts-mode-test-helpers)

(describe "fsharp-ts-mode indentation helpers"
  (describe "shift-region-right"
    (it "shifts region right by indent offset"
      (with-temp-buffer
        (insert "let x = 1\nlet y = 2\n")
        (fsharp-ts-mode)
        (fsharp-ts-mode-shift-region-right (point-min) (point-max))
        (expect (buffer-string) :to-equal "    let x = 1\n    let y = 2\n")))

    (it "shifts by multiple levels with prefix arg"
      (with-temp-buffer
        (insert "let x = 1\n")
        (fsharp-ts-mode)
        (setq-local indent-tabs-mode nil)
        (fsharp-ts-mode-shift-region-right (point-min) (point-max) 2)
        (expect (buffer-string) :to-equal "        let x = 1\n"))))

  (describe "shift-region-left"
    (it "shifts region left by indent offset"
      (with-temp-buffer
        (insert "    let x = 1\n    let y = 2\n")
        (fsharp-ts-mode)
        (fsharp-ts-mode-shift-region-left (point-min) (point-max))
        (expect (buffer-string) :to-equal "let x = 1\nlet y = 2\n")))

    (it "does not shift past column 0"
      (with-temp-buffer
        (insert "  let x = 1\n")
        (fsharp-ts-mode)
        (fsharp-ts-mode-shift-region-left (point-min) (point-max))
        (expect (buffer-string) :to-equal "let x = 1\n"))))

  (describe "guess-indent-offset"
    (it "guesses 4-space indentation"
      (with-temp-buffer
        (insert "let f x =\n    x + 1\n\nlet g y =\n    y * 2\n")
        (fsharp-ts-mode)
        (fsharp-ts-mode-guess-indent-offset)
        (expect fsharp-ts-indent-offset :to-equal 4)))

    (it "guesses 2-space indentation"
      (with-temp-buffer
        (insert "let f x =\n  x + 1\n\nlet g y =\n  y * 2\n")
        (fsharp-ts-mode)
        (fsharp-ts-mode-guess-indent-offset)
        (expect fsharp-ts-indent-offset :to-equal 2)))

    (it "defaults to current offset for empty buffers"
      (with-temp-buffer
        (fsharp-ts-mode)
        (let ((original fsharp-ts-indent-offset))
          (fsharp-ts-mode-guess-indent-offset)
          (expect fsharp-ts-indent-offset :to-equal original))))))

;;; fsharp-ts-mode-indent-helpers-test.el ends here
