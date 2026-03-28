;;; fsharp-ts-mode-navigation-test.el --- Navigation tests for fsharp-ts-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for `fsharp-ts-mode' navigation and imenu support.

;;; Code:

(require 'fsharp-ts-mode-test-helpers)

(describe "fsharp-ts-mode navigation"
  (before-all
    (unless (treesit-language-available-p 'fsharp)
      (signal 'buttercup-pending "fsharp grammar not available")))

  (describe "defun-name"
    (it "returns function name"
      (with-fsharp-ts-mode-buffer "let add x y = x + y\n"
        (goto-char 5)
        (expect (treesit-add-log-current-defun) :to-equal "add")))

    (it "returns value name"
      (with-fsharp-ts-mode-buffer "let name = \"hello\"\n"
        (goto-char 5)
        (expect (treesit-add-log-current-defun) :to-equal "name")))

    (it "returns type name"
      (with-fsharp-ts-mode-buffer "type Color =\n    | Red\n    | Green\n"
        (goto-char 6)
        (expect (treesit-add-log-current-defun) :to-equal "Color")))

    (it "returns module name"
      (with-fsharp-ts-mode-buffer "module Sub =\n    let x = 1\n"
        (goto-char 8)
        (expect (treesit-add-log-current-defun) :to-equal "Sub")))))

(describe "fsharp-ts-mode imenu"
  (before-all
    (unless (treesit-language-available-p 'fsharp)
      (signal 'buttercup-pending "fsharp grammar not available")))

  (it "produces correct imenu categories"
    (with-fsharp-ts-mode-buffer
        "namespace MyApp

type Color =
    | Red
    | Green

exception MyError of string

let add x y = x + y

module Sub =
    let inner = 42
"
      (let* ((index (treesit-simple-imenu))
             (categories (mapcar #'car index)))
        (expect categories :to-have-same-items-as
                '("Namespace" "Type" "Case" "Exception" "Value" "Module")))))

  (it "produces fully-qualified names for nested definitions"
    (with-fsharp-ts-mode-buffer
        "module Sub =
    let inner = 42
"
      (let* ((index (treesit-simple-imenu))
             (value-entries (cdr (assoc "Value" index)))
             (names (mapcar #'car value-entries)))
        (expect names :to-contain "Sub.inner"))))

  (it "produces qualified names for union cases"
    (with-fsharp-ts-mode-buffer
        "namespace MyApp

type Color =
    | Red
    | Green
"
      (let* ((index (treesit-simple-imenu))
             (case-entries (cdr (assoc "Case" index)))
             (names (mapcar #'car case-entries)))
        (expect names :to-contain "MyApp.Color.Red")
        (expect names :to-contain "MyApp.Color.Green")))))

;;; fsharp-ts-mode-navigation-test.el ends here
