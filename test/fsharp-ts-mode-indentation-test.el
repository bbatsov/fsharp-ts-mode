;;; fsharp-ts-mode-indentation-test.el --- Indentation tests for fsharp-ts-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov

;;; Commentary:

;; Buttercup tests for `fsharp-ts-mode' indentation.
;; Because F# is an indentation-sensitive language, tree-sitter requires
;; properly indented input to parse correctly.  These tests verify that
;; already-indented code is preserved by `indent-region'.

;;; Code:

(require 'fsharp-ts-mode-test-helpers)

(describe "fsharp-ts-mode indentation"
  (before-all
    (unless (treesit-language-available-p 'fsharp)
      (signal 'buttercup-pending "fsharp grammar not available")))

  (describe "top-level"
    (when-indenting-it "keeps top-level bindings at column 0"
      "let x = 1
let y = 2
")

    (when-indenting-it "keeps namespace body at column 0"
      "namespace MyApp

open System
let x = 1
"))

  (describe "let bindings"
    (when-indenting-it "indents function body"
      "let add x y =
    x + y
")

    (when-indenting-it "indents value binding body"
      "let result =
    computeSomething()
"))

  (describe "module definitions"
    (when-indenting-it "indents module body"
      "module MyModule =
    let x = 1
    let y = 2
"))

  (describe "type definitions"
    (when-indenting-it "indents discriminated union cases"
      "type Color =
    | Red
    | Green
    | Blue
")

    (when-indenting-it "indents record type body"
      "type Point = { X: float; Y: float }
"))

  (describe "match expressions"
    (when-indenting-it "indents match with cases"
      "let f x =
    match x with
    | 0 -> \"zero\"
    | _ -> \"other\"
"))

  (describe "if/elif/else"
    (when-indenting-it "indents if/then/else bodies"
      "let f x =
    if x > 0 then
        x + 1
    elif x < 0 then
        x - 1
    else
        0
"))

  (describe "try/with"
    (when-indenting-it "indents try/with blocks"
      "let x =
    try
        doSomething()
    with
    | :? IOException as ex -> handleIO ex
    | _ -> reraise()
"))

  (describe "loops"
    (when-indenting-it "indents for loop body"
      "for i in items do
    process i
"))

  (describe "sequential expressions"
    (when-indenting-it "keeps sequential expressions aligned"
      "let f () =
    let x = 1
    let y = 2
    x + y
")))

;;; fsharp-ts-mode-indentation-test.el ends here
