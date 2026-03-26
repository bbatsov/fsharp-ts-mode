;;; fsharp-ts-mode.el --- Major mode for F# code -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov
;;
;; Author: Bozhidar Batsov <bozhidar@batsov.dev>
;; Maintainer: Bozhidar Batsov <bozhidar@batsov.dev>
;; URL: https://github.com/bbatsov/fsharp-ts-mode
;; Keywords: languages fsharp
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Provides font-lock, indentation, and navigation for the
;; F# programming language (https://fsharp.org).

;; For the tree-sitter grammar this mode is based on,
;; see https://github.com/ionide/tree-sitter-fsharp.

;;; License:

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Code:

(require 'treesit)

(defgroup fsharp-ts nil
  "Major mode for editing F# code with tree-sitter."
  :prefix "fsharp-ts-"
  :group 'languages
  :link '(url-link :tag "GitHub" "https://github.com/bbatsov/fsharp-ts-mode")
  :link '(emacs-commentary-link :tag "Commentary" "fsharp-ts-mode"))

(defcustom fsharp-ts-indent-offset 4
  "Number of spaces for each indentation step in the major modes."
  :type 'natnum
  :safe 'natnump
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-other-file-alist
  '(("\\.fsi\\'" (".fs"))
    ("\\.fs\\'" (".fsi")))
  "Associative list of alternate extensions to find.
See `ff-other-file-alist' and `ff-find-other-file'."
  :type '(repeat (list regexp (choice (repeat string) function)))
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defvar fsharp-ts--debug nil
  "Enable debugging messages and show the current node in the mode-line.
When set to t, show indentation debug info.
When set to `font-lock', show fontification info as well.

Only intended for use at development time.")

(defconst fsharp-ts-mode-version "0.1.0")

(defun fsharp-ts-mode-version ()
  "Display the current package version in the minibuffer."
  (interactive)
  (let ((pkg-version (package-get-version)))
    (if (called-interactively-p 'interactively)
        (if pkg-version
            (message "fsharp-ts-mode %s (package: %s)" fsharp-ts-mode-version pkg-version)
          (message "fsharp-ts-mode %s" fsharp-ts-mode-version))
      (or pkg-version fsharp-ts-mode-version))))

;;;; Grammar management

(defconst fsharp-ts-mode-grammar-recipes
  '((fsharp "https://github.com/ionide/tree-sitter-fsharp"
            "0.2.2"
            "fsharp/src")
    (fsharp-signature "https://github.com/ionide/tree-sitter-fsharp"
                      "0.2.2"
                      "fsharp_signature/src"))
  "Tree-sitter grammar recipes for F# and F# Signature.
Each entry is a list of (LANGUAGE URL REV SOURCE-DIR).
Suitable for use as the value of `treesit-language-source-alist'.")

(defun fsharp-ts-mode-install-grammars (&optional force)
  "Install required language grammars if not already available.
With prefix argument FORCE, reinstall grammars even if they are
already installed.  This is useful after upgrading fsharp-ts-mode to a
version that requires a newer grammar."
  (interactive "P")
  (dolist (recipe fsharp-ts-mode-grammar-recipes)
    (let ((grammar (car recipe)))
      (when (or force (not (treesit-language-available-p grammar nil)))
        (message "Installing %s tree-sitter grammar..." grammar)
        (let ((treesit-language-source-alist fsharp-ts-mode-grammar-recipes))
          (treesit-install-language-grammar grammar))))))

;;;; Syntax table

(defvar fsharp-ts-base-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?_ "_" st)
    (modify-syntax-entry ?' "_" st)      ; type parameters like 'a
    ;; Operator characters
    (dolist (c '(?! ?$ ?% ?& ?+ ?- ?< ?= ?> ?@ ?^ ?| ?~ ??))
      (modify-syntax-entry c "." st))
    ;; String delimiters
    (modify-syntax-entry ?\" "\"" st)
    (modify-syntax-entry ?\\ "\\" st)
    ;; Block comments: (* ... *)
    (modify-syntax-entry ?*  ". 23" st)
    (modify-syntax-entry ?\( "()1n" st)
    (modify-syntax-entry ?\) ")(4n" st)
    ;; Line comments: // ...
    ;; The // style is handled via `comment-start' and font-lock.
    ;; The syntax table handles (* *) natively so that
    ;; `forward-comment' and `comment-dwim' work on block comments.
    st)
  "Syntax table in use in fsharp-ts-mode buffers.")

;;;; Font-locking
;;
;; See https://github.com/ionide/tree-sitter-fsharp/blob/main/queries/fsharp/highlights.scm

(defvar fsharp-ts-mode--keywords
  '("let" "let!" "use" "use!" "do" "do!" "and" "rec" "inline" "mutable"
    "if" "then" "else" "elif" "when"
    "match" "match!" "with" "function" "fun"
    "for" "in" "to" "downto" "while"
    "try" "finally"
    "return" "return!" "yield" "yield!"
    "new" "lazy" "assert" "upcast" "downcast"
    "as" "begin" "end" "done" "default"
    "get" "set" "of" "val"
    "module" "namespace" "open"
    "type" "exception" "inherit" "interface" "class" "struct" "enum"
    "member" "abstract" "override" "static"
    "delegate" "not" "or" "null")
  "F# keywords for tree-sitter font-locking.")

(defvar fsharp-ts-mode--builtin-ids
  '("failwith" "failwithf" "raise" "reraise" "ignore"
    "invalidArg" "invalidOp" "nullArg"
    "nameof" "typeof" "typedefof" "sizeof"
    "stdin" "stdout" "stderr"
    "printfn" "printf" "eprintfn" "eprintf" "sprintf" "fprintf"
    "box" "unbox" "ref" "fst" "snd" "id" "not")
  "F# builtin identifiers for tree-sitter font-locking.")

(defvar fsharp-ts-mode--builtin-types
  '("bool" "byte" "sbyte" "int16" "uint16" "int" "uint" "int32" "uint32"
    "int64" "uint64" "nativeint" "unativeint" "decimal" "float" "double"
    "float32" "single" "char" "string" "unit" "obj" "exn"
    "option" "voption" "list" "array" "seq"
    "async" "task" "result" "lazy"
    "bigint" "byte" "ResizeArray")
  "F# builtin type names for tree-sitter font-locking.")

(defun fsharp-ts-mode--font-lock-settings (language)
  "Return tree-sitter font-lock settings for LANGUAGE.
The return value is suitable for `treesit-font-lock-settings'."
  (treesit-font-lock-rules
   ;; Level 1: comments
   :language language
   :feature 'comment
   '(;; Doc comments start with ///
     (((line_comment) @font-lock-doc-face)
      (:match "^///" @font-lock-doc-face))
     (line_comment) @font-lock-comment-face
     (block_comment) @font-lock-comment-face)

   ;; Level 1: definitions
   :language language
   :feature 'definition
   '(;; Function definitions: let f x y = ...
     (function_or_value_defn
      (function_declaration_left (identifier) @font-lock-function-name-face))
     ;; Value definitions: let x = ...
     (function_or_value_defn
      (value_declaration_left
       (identifier_pattern
        (long_identifier_or_op (identifier) @font-lock-variable-name-face))))
     ;; Type names in type definitions
     (type_name type_name: (_) @font-lock-type-face)
     ;; Exception names
     (exception_definition
      exception_name: (_) @font-lock-type-face)
     ;; Member names (properties and methods)
     (method_or_prop_defn
      name: (property_or_ident
             method: (identifier) @font-lock-function-name-face))
     (method_or_prop_defn
      name: (property_or_ident
             (identifier) @font-lock-function-name-face))
     ;; Abstract member signatures
     (member_signature (identifier) @font-lock-function-name-face)
     ;; Module definitions
     (module_defn (identifier) @font-lock-type-face))

   ;; Level 2: keywords
   :language language
   :feature 'keyword
   `([,@fsharp-ts-mode--keywords] @font-lock-keyword-face
     (access_modifier) @font-lock-keyword-face
     ;; Arrow in fun expressions and match rules
     (fun_expression "->" @font-lock-keyword-face)
     (rules (rule "->" @font-lock-keyword-face)))

   ;; Level 2: strings
   :language language
   :feature 'string
   :override t
   '([(string) (verbatim_string) (triple_quoted_string)
      (char)] @font-lock-string-face)

   ;; Level 2: types
   :language language
   :feature 'type
   `(;; DU constructors get constant face
     (union_type_case (identifier) @font-lock-constant-face)
     ;; Type annotations
     (simple_type (long_identifier) @font-lock-type-face)
     ;; Function type arrows
     (function_type "->" @font-lock-type-face)
     ;; Module/namespace names
     (namespace name: (_) @font-lock-type-face)
     (named_module name: (_) @font-lock-type-face)
     ;; Opened modules
     (import_decl (long_identifier) @font-lock-type-face)
     ;; DU constructor usage in expressions
     ((long_identifier_or_op
       (long_identifier (identifier) @font-lock-constant-face))
      (:match "^[A-Z]" @font-lock-constant-face)))

   ;; Level 3: attributes
   :language language
   :feature 'attribute
   '((attribute) @font-lock-preprocessor-face
     (compiler_directive_decl) @font-lock-preprocessor-face)

   ;; Level 3: builtins
   :language language
   :feature 'builtin
   `(((long_identifier_or_op (identifier) @font-lock-builtin-face)
      (:match ,(regexp-opt fsharp-ts-mode--builtin-ids 'symbols)
              @font-lock-builtin-face))
     ;; Builtin types
     ((simple_type
       (long_identifier (identifier) @font-lock-builtin-face))
      (:match ,(regexp-opt fsharp-ts-mode--builtin-types 'symbols)
              @font-lock-builtin-face)))

   ;; Level 3: constants
   ;; bool, unit, and null are supertype nodes inside `const' that
   ;; cannot be queried directly, so we match via their parent.
   :language language
   :feature 'constant
   '(((const) @font-lock-constant-face
      (:match "^\\(true\\|false\\|()\\|null\\)$"
              @font-lock-constant-face)))

   ;; Level 3: escape sequences (interpolation in format strings)
   :language language
   :feature 'escape-sequence
   :override t
   '((format_string_eval) @font-lock-escape-face)

   ;; Level 3: numbers
   :language language
   :feature 'number
   :override t
   '([(int) (int32) (int64) (nativeint) (unativeint)
      (float) (decimal) (ieee32) (ieee64)
      (xint) (byte) (sbyte) (int16) (uint16) (uint32) (uint64)] @font-lock-number-face)

   ;; Level 4: operators
   :language language
   :feature 'operator
   '((infix_op) @font-lock-operator-face
     (prefix_op) @font-lock-operator-face)

   ;; Level 4: brackets
   :language language
   :feature 'bracket
   '((["(" ")" "[" "]" "{" "}" "[|" "|]" "[<" ">]"]) @font-lock-bracket-face)

   ;; Level 4: delimiters
   :language language
   :feature 'delimiter
   '((["," ";" ":"]) @font-lock-delimiter-face)

   ;; Level 4: variables (catch-all for identifiers)
   :language language
   :feature 'variable
   '((identifier) @font-lock-variable-use-face)

   ;; Level 4: properties (record fields, dot access)
   :language language
   :feature 'property
   '(;; Record field definitions
     (record_field (identifier) @font-lock-property-use-face)
     ;; Record field initializers
     (field_initializer field: (_) @font-lock-property-use-face))

   ;; Level 4: function calls
   :language language
   :feature 'function
   :override t
   '(;; Application: f x
     (application_expression
      :anchor
      (long_identifier_or_op (identifier) @font-lock-function-call-face))
     (application_expression
      :anchor
      (long_identifier_or_op
       (long_identifier (_) @_mod
                        :anchor
                        (identifier) @font-lock-function-call-face)))
     ;; x |> f
     ((infix_expression
       (_)
       (infix_op) @_op
       (long_identifier_or_op
        (identifier) @font-lock-function-call-face))
      (:match "^[|]>$" @_op)))))

;;;; Indentation

(defvar fsharp-ts-mode--indent-body-tokens
  '("=" "->" "then" "else" "do" "begin" "with" "finally"
    "yield" "yield!" "return" "return!")
  "Node types at end of line that imply the next line should be indented.")

(defun fsharp-ts-mode--empty-line-offset (_node _parent bol &rest _)
  "Compute extra indentation offset for an empty line at BOL.
If the previous line ends with a body-expecting token (like `=', `->',
`then', etc.), return `fsharp-ts-indent-offset', otherwise return 0."
  (save-excursion
    (goto-char bol)
    (if (and (zerop (forward-line -1))
             (progn
               (end-of-line)
               (skip-chars-backward " \t")
               (> (point) (line-beginning-position)))
             (let ((node (treesit-node-at (1- (point)))))
               (and node
                    (member (treesit-node-type node)
                            fsharp-ts-mode--indent-body-tokens))))
        fsharp-ts-indent-offset
      0)))

(defun fsharp-ts-mode--indent-rules (language)
  "Return tree-sitter indentation rules for LANGUAGE.
The return value is suitable for `treesit-simple-indent-rules'."
  `((,language
     ;; Comment continuation lines: align with body text.
     ;; Must come before `no-node' because empty lines inside
     ;; multi-line comments have node=nil, parent=block_comment.
     ((parent-is "block_comment") prev-adaptive-prefix 0)

     ;; Empty lines: use previous line's indentation, adding offset
     ;; when the previous line ends with a body-expecting token.
     (no-node prev-line fsharp-ts-mode--empty-line-offset)

     ;; Top-level definitions: column 0
     ((parent-is "file") column-0 0)
     ((parent-is "named_module") column-0 0)

     ;; Namespace body does NOT indent (F# convention)
     ((parent-is "namespace") column-0 0)

     ;; Closing delimiters align with the opening construct
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((node-is "}") parent-bol 0)
     ((node-is "|]") parent-bol 0)
     ((node-is "|}") parent-bol 0)
     ((node-is ">]") parent-bol 0)
     ((node-is "end") parent-bol 0)
     ((node-is "done") parent-bol 0)

     ;; elif aligns with if
     ((node-is "elif_expression") parent-bol 0)
     ;; else aligns with if
     ((match "else" "if_expression") parent-bol 0)

     ;; with in match/try aligns with the keyword
     ((match "with" "match_expression") parent-bol 0)
     ((match "with" "try_expression") parent-bol 0)

     ;; | in match rules aligns with the match keyword
     ((node-is "rule") parent-bol 0)
     ((match "^[|]$" "rules") parent-bol 0)

     ;; Match rule body (after ->) is indented from |
     ((parent-is "rule") parent-bol fsharp-ts-indent-offset)

     ;; then/else/elif bodies are indented
     ((parent-is "if_expression") parent-bol fsharp-ts-indent-offset)
     ((parent-is "elif_expression") parent-bol fsharp-ts-indent-offset)

     ;; Module body is indented
     ((parent-is "module_defn") parent-bol fsharp-ts-indent-offset)

     ;; Function/value binding body
     ((parent-is "function_or_value_defn") parent-bol fsharp-ts-indent-offset)

     ;; Type definitions
     ((parent-is "type_definition") parent-bol fsharp-ts-indent-offset)
     ((parent-is "union_type_defn") parent-bol fsharp-ts-indent-offset)
     ((parent-is "union_type_cases") parent-bol 0)
     ((parent-is "record_type_defn") parent-bol fsharp-ts-indent-offset)
     ((parent-is "record_fields") parent-bol 0)
     ((parent-is "enum_type_defn") parent-bol fsharp-ts-indent-offset)
     ((parent-is "interface_type_defn") parent-bol fsharp-ts-indent-offset)
     ((parent-is "class_type_defn") parent-bol fsharp-ts-indent-offset)
     ((parent-is "type_abbrev_defn") parent-bol fsharp-ts-indent-offset)

     ;; Member definitions
     ((parent-is "member_defn") parent-bol fsharp-ts-indent-offset)

     ;; Compound expressions
     ((parent-is "paren_expression") parent-bol fsharp-ts-indent-offset)
     ((parent-is "list_expression") parent-bol fsharp-ts-indent-offset)
     ((parent-is "array_expression") parent-bol fsharp-ts-indent-offset)
     ((parent-is "brace_expression") parent-bol fsharp-ts-indent-offset)
     ((parent-is "anon_record_expression") parent-bol fsharp-ts-indent-offset)

     ;; Application expressions (multi-line function calls)
     ((parent-is "application_expression") parent-bol fsharp-ts-indent-offset)

     ;; Sequential expressions (expr1; expr2) — keep aligned
     ((parent-is "sequential_expression") parent-bol 0)
     ;; declaration_expression children stay aligned
     ((parent-is "declaration_expression") parent-bol 0)

     ;; try/with/finally
     ((parent-is "try_expression") parent-bol fsharp-ts-indent-offset)

     ;; for/while loops
     ((parent-is "for_expression") parent-bol fsharp-ts-indent-offset)
     ((parent-is "while_expression") parent-bol fsharp-ts-indent-offset)

     ;; fun/function expressions
     ((parent-is "fun_expression") parent-bol fsharp-ts-indent-offset)
     ((parent-is "function_expression") parent-bol fsharp-ts-indent-offset)

     ;; Computation expressions
     ((parent-is "ce_expression") parent-bol fsharp-ts-indent-offset)

     ;; Object expressions
     ((parent-is "object_expression") parent-bol fsharp-ts-indent-offset)

     ;; match_expression body
     ((parent-is "match_expression") parent-bol fsharp-ts-indent-offset)

     ;; Infix expressions (including pipes) -- keep aligned
     ((parent-is "infix_expression") parent-bol 0)

     ;; Error recovery
     ((parent-is "ERROR") parent-bol fsharp-ts-indent-offset)

     ;; Strings: preserve previous indentation
     ((node-is "string") prev-line 0)
     ((node-is "triple_quoted_string") prev-line 0)
     ((node-is "verbatim_string") prev-line 0))))

;;;; Mode setup

(defun fsharp-ts--setup-mode (language)
  "Common tree-sitter mode setup for LANGUAGE.
LANGUAGE should be `fsharp' or `fsharp-signature'."
  (when (treesit-ready-p language)
    (let ((parser (treesit-parser-create language)))
      (when (boundp 'treesit-primary-parser)
        (setq-local treesit-primary-parser parser)))

    (when fsharp-ts--debug
      (setq-local treesit--indent-verbose t)
      (when (eq fsharp-ts--debug 'font-lock)
        (setq-local treesit--font-lock-verbose t))
      (treesit-inspect-mode))

    ;; Font-lock
    (setq-local treesit-font-lock-settings
                (fsharp-ts-mode--font-lock-settings language))

    ;; Indentation
    (setq-local treesit-simple-indent-rules
                (fsharp-ts-mode--indent-rules language))

    (treesit-major-mode-setup)))

(define-derived-mode fsharp-ts-base-mode prog-mode "F#"
  "Base major mode for F# files, providing shared setup.
This mode is not intended to be used directly.  Use `fsharp-ts-mode'
for .fs files and `fsharp-ts-signature-mode' for .fsi files."
  :syntax-table fsharp-ts-base-mode-syntax-table

  ;; Comment settings: F# primarily uses // line comments
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "//+\\s-*")

  ;; Electric indentation on delimiters
  (setq-local electric-indent-chars
              (append "{}()" electric-indent-chars))

  (setq-local treesit-font-lock-feature-list
              '((comment definition)
                (keyword string type)
                (attribute builtin constant escape-sequence number)
                (operator bracket delimiter variable property function)))

  (setq-local indent-line-function #'treesit-indent)

  ;; which-func-mode / add-log integration
  (setq-local add-log-current-defun-function #'treesit-add-log-current-defun)

  ;; ff-find-other-file setup
  (setq-local ff-other-file-alist fsharp-ts-other-file-alist))

;;;###autoload
(define-derived-mode fsharp-ts-mode fsharp-ts-base-mode "F#"
  "Major mode for editing F# code.

\\{fsharp-ts-base-mode-map}"
  (fsharp-ts--setup-mode 'fsharp))

;;;###autoload
(define-derived-mode fsharp-ts-signature-mode fsharp-ts-base-mode "F#[Sig]"
  "Major mode for editing F# signature (fsi) code.

\\{fsharp-ts-base-mode-map}"
  (fsharp-ts--setup-mode 'fsharp-signature))

;;;###autoload
(progn
  (add-to-list 'auto-mode-alist '("\\.fs\\'" . fsharp-ts-mode))
  (add-to-list 'auto-mode-alist '("\\.fsx\\'" . fsharp-ts-mode))
  (add-to-list 'auto-mode-alist '("\\.fsi\\'" . fsharp-ts-signature-mode)))

;; Hide F# build artifacts from find-file completion
(dolist (ext '(".dll" ".exe" ".pdb"))
  (add-to-list 'completion-ignored-extensions ext))

;; Eglot integration: set the language IDs that fsautocomplete expects.
(put 'fsharp-ts-mode 'eglot-language-id "fsharp")
(put 'fsharp-ts-signature-mode 'eglot-language-id "fsharp")

(provide 'fsharp-ts-mode)

;;; fsharp-ts-mode.el ends here
