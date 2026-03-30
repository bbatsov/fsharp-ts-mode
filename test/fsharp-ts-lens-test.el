;;; fsharp-ts-lens-test.el --- Tests for fsharp-ts-lens -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov

;;; Commentary:

;; Tests for the type signature overlay (LineLens) feature.

;;; Code:

(require 'buttercup)
(require 'fsharp-ts-lens)

(describe "fsharp-ts-lens"
  (describe "symbol filtering"
    (it "accepts function symbols"
      (let ((sym '((GlyphChar . "Fc") (EnclosingEntity . "") (IsAbstract . nil))))
        (expect (fsharp-ts-lens--interesting-p sym) :to-be-truthy)))

    (it "accepts method symbols"
      (let ((sym '((GlyphChar . "M") (EnclosingEntity . "") (IsAbstract . nil))))
        (expect (fsharp-ts-lens--interesting-p sym) :to-be-truthy)))

    (it "accepts property symbols"
      (let ((sym '((GlyphChar . "P") (EnclosingEntity . "") (IsAbstract . nil))))
        (expect (fsharp-ts-lens--interesting-p sym) :to-be-truthy)))

    (it "rejects abstract symbols"
      (let ((sym '((GlyphChar . "M") (EnclosingEntity . "") (IsAbstract . t))))
        (expect (fsharp-ts-lens--interesting-p sym) :not :to-be-truthy)))

    (it "rejects interface members"
      (let ((sym '((GlyphChar . "M") (EnclosingEntity . "I") (IsAbstract . nil))))
        (expect (fsharp-ts-lens--interesting-p sym) :not :to-be-truthy)))

    (it "rejects record fields"
      (let ((sym '((GlyphChar . "F") (EnclosingEntity . "R") (IsAbstract . nil))))
        (expect (fsharp-ts-lens--interesting-p sym) :not :to-be-truthy)))

    (it "rejects DU case members"
      (let ((sym '((GlyphChar . "Fc") (EnclosingEntity . "D") (IsAbstract . nil))))
        (expect (fsharp-ts-lens--interesting-p sym) :not :to-be-truthy)))

    (it "rejects unknown glyph types"
      (let ((sym '((GlyphChar . "X") (EnclosingEntity . "") (IsAbstract . nil))))
        (expect (fsharp-ts-lens--interesting-p sym) :not :to-be-truthy))))

  (describe "position collection"
    (it "extracts top-level function positions"
      (let ((response
             (list (list (cons 'Declaration
                               '((GlyphChar . "Fc")
                                 (IsTopLevel . t)
                                 (BodyRange . ((Start . ((Line . 5) (Column . 4)))))))
                         (cons 'Nested [])))))
        (let ((positions (fsharp-ts-lens--collect-positions response)))
          (expect (length positions) :to-equal 1)
          (expect (car (car positions)) :to-equal 6)))) ;; 1-indexed

    (it "deduplicates positions on the same line"
      (let ((response
             (list (list (cons 'Declaration
                               '((GlyphChar . "Fc")
                                 (IsTopLevel . t)
                                 (BodyRange . ((Start . ((Line . 5) (Column . 4)))))))
                         (cons 'Nested
                               (vector '((GlyphChar . "Fc")
                                         (EnclosingEntity . "")
                                         (IsAbstract . nil)
                                         (BodyRange . ((Start . ((Line . 5) (Column . 10))))))))))))
        (let ((positions (fsharp-ts-lens--collect-positions response)))
          (expect (length positions) :to-equal 1))))

    (it "returns empty for no symbols"
      (expect (fsharp-ts-lens--collect-positions nil) :to-equal nil)))

  (describe "overlay management"
    (it "adds and clears overlays"
      (with-temp-buffer
        (insert "line 1\nline 2\nline 3\n")
        (fsharp-ts-lens--add-overlay 2 "int -> string")
        (expect (length fsharp-ts-lens--overlays) :to-equal 1)
        (fsharp-ts-lens--clear)
        (expect (length fsharp-ts-lens--overlays) :to-equal 0)))

    (it "displays the signature as after-string"
      (with-temp-buffer
        (insert "let f x = x\n")
        (fsharp-ts-lens--add-overlay 1 "int -> int")
        (let ((ov (car fsharp-ts-lens--overlays)))
          (expect (overlay-get ov 'after-string) :to-match "int -> int")
          (expect (overlay-get ov 'fsharp-ts-lens) :to-be t))))))

;;; fsharp-ts-lens-test.el ends here
