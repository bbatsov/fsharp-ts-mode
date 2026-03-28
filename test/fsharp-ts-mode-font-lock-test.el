;;; fsharp-ts-mode-font-lock-test.el --- Font-lock tests for fsharp-ts-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for `fsharp-ts-mode' font-lock (syntax highlighting).

;;; Code:

(require 'fsharp-ts-mode-test-helpers)

(describe "fsharp-ts-mode font-lock"
  (before-all
    (unless (treesit-language-available-p 'fsharp)
      (signal 'buttercup-pending "fsharp grammar not available")))

  (describe "level 1"
    (describe "comments"
      (when-fontifying-it "highlights line comments"
        ("// this is a comment\n"
         ("// this is a comment" font-lock-comment-face)))

      (when-fontifying-it "highlights block comments"
        ("(* block comment *)\n"
         ("(* block comment *)" font-lock-comment-face)))

      (when-fontifying-it "highlights doc comments"
        ("/// doc comment\nlet x = 1\n"
         ("/// doc comment" font-lock-doc-face))))

    (describe "definitions"
      (when-fontifying-it "highlights function names"
        ("let add x y = x + y\n"
         ("add" font-lock-function-name-face)))

      (when-fontifying-it "highlights value names"
        ("let name = \"hello\"\n"
         ("name" font-lock-variable-name-face)))

      (when-fontifying-it "highlights type definition names"
        ("type Color =\n    | Red\n    | Green\n"
         ("Color" font-lock-type-face)))

      (when-fontifying-it "highlights module names"
        ("module MyModule =\n    let x = 1\n"
         ("MyModule" font-lock-type-face)))))

  (describe "level 2"
    (describe "keywords"
      (when-fontifying-it "highlights common keywords"
        ("let x = 1\n"
         ("let" font-lock-keyword-face))
        ("let rec f x = f x\n"
         ("rec" font-lock-keyword-face))
        ("if true then 1 else 0\n"
         ("if" font-lock-keyword-face)
         ("then" font-lock-keyword-face)
         ("else" font-lock-keyword-face))
        ("match x with\n| 1 -> true\n"
         ("match" font-lock-keyword-face)
         ("with" font-lock-keyword-face))
        ("open System\n"
         ("open" font-lock-keyword-face))
        ("module M =\n    let x = 1\n"
         ("module" font-lock-keyword-face))))

    (describe "strings"
      (when-fontifying-it "highlights string literals"
        ("let s = \"hello world\"\n"
         ("hello world" font-lock-string-face)))

      (when-fontifying-it "highlights char literals"
        ("let c = 'a'\n"
         ("'a'" font-lock-string-face))))

    (describe "types"
      (when-fontifying-it "highlights DU constructors"
        ("type Color =\n    | Red\n    | Green\n"
         ("Red" font-lock-constant-face)
         ("Green" font-lock-constant-face)))

      (when-fontifying-it "highlights opened modules"
        ("open System\n"
         ("System" font-lock-type-face)))))

  (describe "level 3"
    (describe "constants"
      (when-fontifying-it "highlights boolean constants"
        ("let x = true\n"
         ("true" font-lock-constant-face))
        ("let x = false\n"
         ("false" font-lock-constant-face)))

      (when-fontifying-it "highlights unit constant"
        ("let x = ()\n"
         ("()" font-lock-constant-face))))

    (describe "numbers"
      (when-fontifying-it "highlights integer literals"
        ("let x = 42\n"
         ("42" font-lock-number-face)))

      (when-fontifying-it "highlights float literals"
        ("let x = 3.14\n"
         ("3.14" font-lock-number-face)))))

  (describe "level 4"
    (describe "operators"
      (when-fontifying-it "highlights infix operators"
        ("let x = 1 + 2\n"
         ("+" font-lock-operator-face))))

    (describe "function calls"
      (when-fontifying-it "highlights function application"
        ("let x = add 1 2\n"
         ("add" font-lock-function-call-face)))

      (when-fontifying-it "highlights pipe-left target"
        ("let x = printfn <| \"hello\"\n"
         ("printfn" font-lock-function-call-face)))))

  (describe "additional highlights"
    (when-fontifying-it "highlights wildcard pattern"
      ("let f x =\n    match x with\n    | _ -> 0\n"
       ("_" font-lock-constant-face)))

    (when-fontifying-it "highlights CE builder name"
      ("let w =\n    async {\n        return 42\n    }\n"
       ("async" font-lock-constant-face)))

    (when-fontifying-it "highlights preprocessor directives"
      ("#if DEBUG\nlet y = 2\n#endif\n"
       ("#if" font-lock-preprocessor-face)))))

;;; fsharp-ts-mode-font-lock-test.el ends here
