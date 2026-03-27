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
(require 'compile)

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

(defcustom fsharp-ts-guess-indent-offset nil
  "When non-nil, automatically guess the indentation offset on file open.
Uses `fsharp-ts-mode-guess-indent-offset' to scan the buffer and set
`fsharp-ts-indent-offset' to match the file's convention."
  :type 'boolean
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
    "delegate" "or" "null")
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
    "bigint" "ResizeArray")
  "F# builtin type names for tree-sitter font-locking.")

(defun fsharp-ts-mode--font-lock-settings (language)
  "Return tree-sitter font-lock settings for LANGUAGE.
The return value is suitable for `treesit-font-lock-settings'."
  (append
   ;; Shared rules that work with both fsharp and fsharp-signature grammars
   (treesit-font-lock-rules
    :language language
    :feature 'comment
    '(;; Doc comments start with ///
      (((line_comment) @font-lock-doc-face)
       (:match "^///" @font-lock-doc-face))
      (line_comment) @font-lock-comment-face
      (block_comment) @font-lock-comment-face)

    :language language
    :feature 'string
    :override t
    '([(string) (verbatim_string) (triple_quoted_string)
       (char)] @font-lock-string-face)

    :language language
    :feature 'type
    `((simple_type (long_identifier) @font-lock-type-face)
      (function_type "->" @font-lock-type-face)
      (namespace (long_identifier) @font-lock-type-face))

    :language language
    :feature 'bracket
    '((["(" ")" "[" "]" "{" "}" "[|" "|]" "[<" ">]"]) @font-lock-bracket-face)

    :language language
    :feature 'delimiter
    '((["," ";" ":"]) @font-lock-delimiter-face)

    :language language
    :feature 'variable
    '((identifier) @font-lock-variable-use-face))

   ;; Grammar-specific rules
   (if (eq language 'fsharp)
       (fsharp-ts-mode--font-lock-settings-fsharp)
     (fsharp-ts-mode--font-lock-settings-signature))))

(defun fsharp-ts-mode--font-lock-settings-fsharp ()
  "Return fsharp-specific font-lock rules."
  (treesit-font-lock-rules
   :language 'fsharp
   :feature 'definition
   :override t
   '((function_or_value_defn
      (function_declaration_left (identifier) @font-lock-function-name-face))
     (function_or_value_defn
      (value_declaration_left
       (identifier_pattern
        (long_identifier_or_op (identifier) @font-lock-variable-name-face))))
     (type_name type_name: (_) @font-lock-type-face)
     (exception_definition
      exception_name: (_) @font-lock-type-face)
     (method_or_prop_defn
      name: (property_or_ident
             method: (identifier) @font-lock-function-name-face))
     (method_or_prop_defn
      name: (property_or_ident
             (identifier) @font-lock-function-name-face))
     (member_signature (identifier) @font-lock-function-name-face)
     (module_defn (identifier) @font-lock-type-face))

   :language 'fsharp
   :feature 'keyword
   :override t
   `([,@fsharp-ts-mode--keywords] @font-lock-keyword-face
     (access_modifier) @font-lock-keyword-face
     (fun_expression "->" @font-lock-keyword-face)
     (rules (rule "->" @font-lock-keyword-face)))

   :language 'fsharp
   :feature 'type
   :override t
   `((union_type_case (identifier) @font-lock-constant-face)
     (named_module name: (_) @font-lock-type-face)
     (import_decl (long_identifier) @font-lock-type-face)
     ((long_identifier_or_op
       (long_identifier (identifier) @font-lock-constant-face))
      (:match "^[A-Z]" @font-lock-constant-face)))

   :language 'fsharp
   :feature 'attribute
   '((attribute) @font-lock-preprocessor-face
     (compiler_directive_decl) @font-lock-preprocessor-face)

   :language 'fsharp
   :feature 'builtin
   :override t
   `(((long_identifier_or_op (identifier) @font-lock-builtin-face)
      (:match ,(regexp-opt fsharp-ts-mode--builtin-ids 'symbols)
              @font-lock-builtin-face))
     ((simple_type
       (long_identifier (identifier) @font-lock-builtin-face))
      (:match ,(regexp-opt fsharp-ts-mode--builtin-types 'symbols)
              @font-lock-builtin-face)))

   :language 'fsharp
   :feature 'constant
   '(((const) @font-lock-constant-face
      (:match "^\\(true\\|false\\|()\\|null\\)$"
              @font-lock-constant-face)))

   :language 'fsharp
   :feature 'escape-sequence
   :override t
   '((format_string_eval) @font-lock-escape-face)

   :language 'fsharp
   :feature 'number
   :override t
   '([(int) (int32) (int64) (nativeint) (unativeint)
      (float) (decimal) (ieee32) (ieee64)
      (xint) (byte) (sbyte) (int16) (uint16) (uint32) (uint64)] @font-lock-number-face)

   :language 'fsharp
   :feature 'operator
   '((infix_op) @font-lock-operator-face
     (prefix_op) @font-lock-operator-face)

   :language 'fsharp
   :feature 'property
   '((record_field (identifier) @font-lock-property-use-face)
     (field_initializer field: (_) @font-lock-property-use-face))

   :language 'fsharp
   :feature 'function
   :override t
   '((application_expression
      :anchor
      (long_identifier_or_op (identifier) @font-lock-function-call-face))
     (application_expression
      :anchor
      (long_identifier_or_op
       (long_identifier (_) @_mod
                        :anchor
                        (identifier) @font-lock-function-call-face)))
     ((infix_expression
       (_)
       (infix_op) @_op
       (long_identifier_or_op
        (identifier) @font-lock-function-call-face))
      (:match "^[|]>$" @_op)))))

(defun fsharp-ts-mode--font-lock-settings-signature ()
  "Return fsharp-signature-specific font-lock rules."
  (treesit-font-lock-rules
   :language 'fsharp-signature
   :feature 'definition
   :override t
   '((value_definition
      (value_declaration_left
       (identifier_pattern
        (long_identifier_or_op (identifier) @font-lock-variable-name-face))))
     (member_signature (identifier) @font-lock-function-name-face))

   :language 'fsharp-signature
   :feature 'keyword
   '((access_modifier) @font-lock-keyword-face
     ["val" "namespace" "module" "abstract" "member"
      "static" "default" "and" "mutable" "new"
      "class" "struct" "interface" "enum"
      "delegate" "end" "with"] @font-lock-keyword-face)))

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

(defun fsharp-ts-mode--trailing-comment-p (node _parent &rest _)
  "Return non-nil if NODE is a trailing comment after PARENT's content.
A trailing comment is a `line_comment' that appears after all named
children of a definition node.  The grammar attaches these to the
preceding definition, but they should be indented at the definition's
level, not the body's."
  (and (string= (treesit-node-type node) "line_comment")
       (null (treesit-node-next-sibling node t))))

(defun fsharp-ts-mode--bracket-item-same-line-p (_node parent &rest _)
  "Return non-nil if PARENT is a bracket expression with first item inline.
Only matches `list_expression', `array_expression', and `paren_expression'
where the first element sits on the same line as the opening bracket."
  (and (member (treesit-node-type parent)
               '("list_expression" "array_expression" "paren_expression"))
       (let* ((bracket (treesit-node-child parent 0))
              (first-item (treesit-node-child parent 0 t)))
         (and first-item
              (= (line-number-at-pos (treesit-node-start bracket))
                 (line-number-at-pos (treesit-node-start first-item)))))))

(defun fsharp-ts-mode--first-item-anchor (_node parent &rest _)
  "Return the position of the first named child inside PARENT.
Used to align subsequent items in brackets with the first item."
  (let ((first-item (treesit-node-child parent 0 t)))
    (when first-item
      (treesit-node-start first-item))))

(defun fsharp-ts-mode--script-top-level-p (_node parent &rest _)
  "Return non-nil if PARENT is part of a top-level expression chain.
In script files without a module declaration, bare expressions like
`printfn` cause the grammar to chain subsequent declarations under
nested `application_expression' nodes.  Walk up through the chain
to check if it ultimately lives under `file'."
  (let ((ptype (treesit-node-type parent)))
    (and (member ptype '("application_expression" "ERROR"))
         (let ((ancestor parent))
           (while (and ancestor
                       (member (treesit-node-type ancestor)
                               '("application_expression"
                                 "declaration_expression"
                                 "ERROR")))
             (setq ancestor (treesit-node-parent ancestor)))
           (and ancestor
                (string= (treesit-node-type ancestor) "file"))))))

(defun fsharp-ts-mode--indent-rules (language)
  "Return tree-sitter indentation rules for LANGUAGE.
The return value is suitable for `treesit-simple-indent-rules'."
  `((,language
     ;; Trailing comments after a definition's body should align
     ;; with the definition itself, not be indented as body.
     ;; Must come before the generic parent-is rules.
     (fsharp-ts-mode--trailing-comment-p parent-bol 0)

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

     ;; Compound expressions: when the first item is on the same line
     ;; as the bracket, align subsequent items with it.
     (fsharp-ts-mode--bracket-item-same-line-p fsharp-ts-mode--first-item-anchor 0)
     ;; Otherwise fall back to standard indentation from the bracket.
     ((parent-is "paren_expression") parent-bol fsharp-ts-indent-offset)
     ((parent-is "list_expression") parent-bol fsharp-ts-indent-offset)
     ((parent-is "array_expression") parent-bol fsharp-ts-indent-offset)
     ((parent-is "brace_expression") parent-bol fsharp-ts-indent-offset)
     ((parent-is "anon_record_expression") parent-bol fsharp-ts-indent-offset)

     ;; Script top-level: declarations misparented under application_expression
     ;; due to bare expressions in .fsx files should stay at column 0.
     (fsharp-ts-mode--script-top-level-p column-0 0)

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

;;;; Navigation and Imenu

(defvar fsharp-ts-mode--defun-type-regexp
  (regexp-opt '("type_definition"
                "exception_definition"
                "function_or_value_defn"
                "member_defn"
                "module_defn")
              'symbols)
  "Regex matching tree-sitter node types treated as defun-like.
Used as the value of `treesit-defun-type-regexp'.")

(defun fsharp-ts-mode--subtree-text (node type &optional depth)
  "Return the text of the first TYPE child in NODE's subtree.
Search up to DEPTH levels deep (default 2).  Return nil if not found."
  (when-let* ((child (treesit-search-subtree node type nil nil (or depth 2))))
    (treesit-node-text child t)))

(defun fsharp-ts-mode--defun-name (node)
  "Return the defun name of NODE.
Return nil if there is no name or if NODE is not a defun node."
  (pcase (treesit-node-type node)
    ("type_definition"
     ;; type_definition > *_type_defn > type_name > identifier
     (fsharp-ts-mode--subtree-text node "type_name" 3))
    ("exception_definition"
     (fsharp-ts-mode--subtree-text node "\\`identifier\\'" 3))
    ("function_or_value_defn"
     (or
      ;; Function: function_declaration_left > identifier
      (when-let* ((fdl (treesit-search-subtree
                        node "function_declaration_left" nil nil 1)))
        (fsharp-ts-mode--subtree-text fdl "\\`identifier\\'"))
      ;; Value: value_declaration_left > identifier_pattern > ... > identifier
      (fsharp-ts-mode--subtree-text node "\\`identifier\\'" 4)))
    ("member_defn"
     ;; member_defn > method_or_prop_defn > property_or_ident
     (when-let* ((prop (treesit-search-subtree
                        node "property_or_ident" nil nil 2)))
       (or (fsharp-ts-mode--subtree-text prop "method" 1)
           (fsharp-ts-mode--subtree-text prop "\\`identifier\\'" 1))))
    ("module_defn"
     (fsharp-ts-mode--subtree-text node "\\`identifier\\'" 1))))

(defun fsharp-ts-mode--defun-valid-p (node)
  "Return non-nil if NODE is a valid definition.
All named definition nodes are valid."
  (not (null (treesit-node-type node))))

(defun fsharp-ts-mode--imenu-name (node)
  "Return a fully-qualified name for NODE by walking up ancestors.
Joins ancestor names with `.' as delimiter."
  (let ((name (fsharp-ts-mode--defun-name node))
        (ancestors nil)
        (parent (treesit-node-parent node)))
    (while parent
      (when (and (member (treesit-node-type parent)
                         '("module_defn" "type_definition" "namespace"))
                 (not (equal parent node)))
        (let ((pname (pcase (treesit-node-type parent)
                       ("namespace"
                        (fsharp-ts-mode--subtree-text parent "long_identifier" 1))
                       (_
                        (fsharp-ts-mode--defun-name parent)))))
          (when pname
            (push pname ancestors))))
      (setq parent (treesit-node-parent parent)))
    (if ancestors
        (concat (string-join ancestors ".") "." name)
      name)))

(defvar fsharp-ts-mode--imenu-settings
  `(("Type" "\\`type_definition\\'" nil fsharp-ts-mode--imenu-name)
    ("Exception" "\\`exception_definition\\'" nil fsharp-ts-mode--imenu-name)
    ("Value" "\\`function_or_value_defn\\'" nil fsharp-ts-mode--imenu-name)
    ("Member" "\\`member_defn\\'" nil fsharp-ts-mode--imenu-name)
    ("Module" "\\`module_defn\\'" nil nil))
  "Imenu settings for `fsharp-ts-mode'.")

;;;; Structured navigation (forward-sexp)

(defvar fsharp-ts-mode--block-regex
  (regexp-opt '("if_expression" "elif_expression"
                "match_expression" "fun_expression" "function_expression"
                "try_expression" "for_expression" "while_expression"
                "paren_expression" "list_expression" "array_expression"
                "brace_expression" "anon_record_expression"
                "ce_expression" "object_expression"
                "application_expression" "infix_expression"
                "function_or_value_defn" "type_definition"
                "module_defn" "member_defn"
                "exception_definition")
              'symbols)
  "Regexp matching node types suitable for sexp-like navigation.")

(defun fsharp-ts-mode--delimiter-p ()
  "Return non-nil if point is on a delimiter character."
  (let ((c (char-after)))
    (and c (memq c '(?\( ?\) ?\[ ?\] ?\{ ?\})))))

(defun fsharp-ts-mode--forward-sexp-hybrid (arg)
  "Sexp movement that delegates to syntax-table on delimiters.
Falls back to tree-sitter for everything else.  ARG is the number
of sexps to move."
  (if (fsharp-ts-mode--delimiter-p)
      (let ((forward-sexp-function nil))
        (forward-sexp arg))
    ;; treesit-end-of-thing / treesit-beginning-of-thing are Emacs 30+.
    ;; On Emacs 29, fall back to syntax-table movement.
    (if (fboundp 'treesit-end-of-thing)
        (funcall
         (if (> arg 0) #'treesit-end-of-thing #'treesit-beginning-of-thing)
         fsharp-ts-mode--block-regex (abs arg))
      (let ((forward-sexp-function nil))
        (forward-sexp arg)))))

;;;; Thing settings (Emacs 30+)

(defun fsharp-ts-mode--thing-settings (language)
  "Return `treesit-thing-settings' for LANGUAGE."
  `((,language
     (sexp (not ,(rx (or "(" ")" "[" "]" "{" "}"
                         "[|" "|]" "[<" ">]"
                         "," ";" ":" "." "->" "<-" "=" "|"))))
     (list ,(regexp-opt '("paren_expression" "list_expression"
                          "array_expression" "brace_expression"
                          "anon_record_expression" "object_expression")
                        'symbols))
     (sentence ,(regexp-opt '("function_or_value_defn" "type_definition"
                              "exception_definition" "module_defn"
                              "import_decl" "member_defn")
                            'symbols))
     (text ,(regexp-opt '("line_comment" "block_comment"
                          "string" "triple_quoted_string"
                          "verbatim_string" "char")
                        'symbols))
     (comment ,(regexp-opt '("line_comment" "block_comment")
                           'symbols)))))

;;;; Compilation error support

(defconst fsharp-ts-mode--compilation-error-regexp
  ;; Matches: /path/to/file.fs(10,5): error FS0001: message
  ;; Also:   /path/to/file.fs(10,5,10,20): error FS0001: message
  `(,(rx bol
         (group-n 1 (+ (not (in "()\n"))))   ; filename
         "(" (group-n 2 (+ digit))           ; line
         "," (group-n 3 (+ digit))           ; column
         (? "," (+ digit) "," (+ digit))     ; optional end line,col
         ")" ": "
         (group-n 4 (or "error" "warning"))  ; severity
         " FS" (+ digit) ": ")
    1 2 3 nil nil)
  "Compilation error regexp for F# compiler output (dotnet build).")

(defun fsharp-ts-mode--setup-compilation ()
  "Register F# compilation error patterns."
  (add-to-list 'compilation-error-regexp-alist-alist
               (cons 'fsharp fsharp-ts-mode--compilation-error-regexp))
  (add-to-list 'compilation-error-regexp-alist 'fsharp))

;;;; Indentation helpers

(defun fsharp-ts-mode-shift-region-right (start end &optional count)
  "Shift the region between START and END right by COUNT indentation levels.
COUNT defaults to 1.  With a negative prefix argument, shifts left."
  (interactive "r\np")
  (let ((offset (* (or count 1) fsharp-ts-indent-offset)))
    (indent-rigidly start end offset)))

(defun fsharp-ts-mode-shift-region-left (start end &optional count)
  "Shift the region between START and END left by COUNT indentation levels.
COUNT defaults to 1.  With a negative prefix argument, shifts right."
  (interactive "r\np")
  (let ((offset (* (or count 1) (- fsharp-ts-indent-offset))))
    (indent-rigidly start end offset)))

(defun fsharp-ts-mode-guess-indent-offset ()
  "Guess the indentation offset used in the current buffer.
Scans the buffer for the most common indentation step and sets
`fsharp-ts-indent-offset' accordingly."
  (interactive)
  (let ((counts (make-hash-table))
        (best-offset fsharp-ts-indent-offset))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (let ((indent (current-indentation)))
          (when (> indent 0)
            (puthash indent (1+ (gethash indent counts 0)) counts)))
        (forward-line 1)))
    ;; Find the best indentation step.  We look at the smallest actual
    ;; indentation value, since in well-indented code the first indent
    ;; level reveals the offset directly (e.g., 4 means offset 4,
    ;; not 2).  Fall back to checking common candidates if needed.
    (let ((min-indent nil))
      (maphash (lambda (indent _)
                 (when (or (null min-indent) (< indent min-indent))
                   (setq min-indent indent)))
               counts)
      (when (and min-indent (member min-indent '(2 3 4 8)))
        (setq best-offset min-indent)))
    (setq-local fsharp-ts-indent-offset best-offset)
    (when (called-interactively-p 'interactive)
      (message "Guessed indent offset: %d" best-offset))))

;;;; Utility commands

(defconst fsharp-ts-mode-report-bug-url
  "https://github.com/bbatsov/fsharp-ts-mode/issues/new"
  "URL for reporting fsharp-ts-mode bugs.")

(defconst fsharp-ts-mode-fsharp-docs-url
  "https://fsharp.org/docs/"
  "URL for the official F# documentation.")

(defun fsharp-ts-mode--grammar-info (language)
  "Return a string describing the status of the LANGUAGE grammar."
  (if (treesit-language-available-p language)
      (let ((recipe (assq language fsharp-ts-mode-grammar-recipes)))
        (format "%s (expected: %s)" language (or (nth 2 recipe) "unknown")))
    (format "%s (not installed)" language)))

(defun fsharp-ts-mode-bug-report-info ()
  "Display debug information for bug reports.
The information is also copied to the kill ring."
  (interactive)
  (let* ((info (format (concat "Emacs: %s\n"
                                "System: %s\n"
                                "fsharp-ts-mode: %s\n"
                                "Grammars: %s, %s\n"
                                "Eglot: %s")
                       emacs-version
                       system-type
                       fsharp-ts-mode-version
                       (fsharp-ts-mode--grammar-info 'fsharp)
                       (fsharp-ts-mode--grammar-info 'fsharp-signature)
                       (if (bound-and-true-p eglot--managed-mode)
                           "active" "inactive"))))
    (kill-new info)
    (message "%s\n(copied to kill ring)" info)))

(defun fsharp-ts-mode-report-bug ()
  "Report a bug in your default browser."
  (interactive)
  (fsharp-ts-mode-bug-report-info)
  (browse-url fsharp-ts-mode-report-bug-url))

(defun fsharp-ts-mode-browse-fsharp-docs ()
  "Browse the official F# documentation in your default browser."
  (interactive)
  (browse-url fsharp-ts-mode-fsharp-docs-url))

(defun fsharp-ts-mode-doc-at-point ()
  "Look up the identifier at point in the .NET API documentation."
  (interactive)
  (let ((symbol (thing-at-point 'symbol t)))
    (unless symbol (user-error "No symbol at point"))
    (browse-url
     (format "https://learn.microsoft.com/en-us/dotnet/api/?term=%s"
             (url-hexify-string symbol)))))

;;;; Build directory awareness

(defun fsharp-ts-mode--resolve-build-path (file)
  "Resolve FILE out of a `bin' or `obj' build directory, if applicable.
For paths like `/project/bin/Debug/net8.0/Foo.fs', find the source file
at `/project/Foo.fs'.  Return nil if FILE is not under a build directory
or the resolved source does not exist."
  (let ((case-fold-search (eq system-type 'windows-nt)))
    (when (string-match "/\\(bin\\|obj\\)/" file)
      (let* ((root (substring file 0 (match-beginning 0)))
             (basename (file-name-nondirectory file))
             ;; Search for the source file in the project root
             (candidate (expand-file-name basename root)))
        (when (file-readable-p candidate)
          candidate)))))

(defun fsharp-ts-mode--check-build-dir ()
  "If the current file is under `bin/' or `obj/', offer to switch to source.
Intended for use in `find-file-hook'."
  (when-let* ((file (buffer-file-name)))
    (when (and (derived-mode-p 'fsharp-ts-base-mode)
               (string-match-p "/\\(bin\\|obj\\)/" file))
      (if-let* ((source (fsharp-ts-mode--resolve-build-path file)))
          (when (y-or-n-p
                 (format "This file is under a build directory.  Switch to %s? "
                         source))
            (find-alternate-file source))
        (message "Note: this file is under a build directory (no source found)")))))

;;;; Prettify symbols

(defcustom fsharp-ts-mode-prettify-symbols-alist
  '(("->" . ?→)
    ("<-" . ?←)
    (">=" . ?≥)
    ("<=" . ?≤)
    ("<>" . ?≠)
    ("fun" . ?λ))
  "Alist of symbol prettifications for F# mode."
  :type '(alist :key-type string :value-type character)
  :package-version '(fsharp-ts-mode . "0.1.0"))

;;;; Mode setup

(defun fsharp-ts--setup-mode (language)
  "Common tree-sitter mode setup for LANGUAGE.
LANGUAGE should be `fsharp' or `fsharp-signature'."
  (when (treesit-ready-p language)
    (let ((parser (treesit-parser-create language)))
      (when (boundp 'treesit-primary-parser)
        (setq-local treesit-primary-parser parser))

      ;; Skip shebang line in .fsx scripts so the parser doesn't choke
      (when (save-excursion
              (goto-char (point-min))
              (looking-at "#!"))
        (let ((shebang-end (save-excursion
                             (goto-char (point-min))
                             (forward-line 1)
                             (point))))
          (treesit-parser-set-included-ranges
           parser (list (cons shebang-end (point-max)))))))

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

    ;; Navigation
    (setq-local treesit-defun-type-regexp
                (cons fsharp-ts-mode--defun-type-regexp
                      #'fsharp-ts-mode--defun-valid-p))
    (setq-local treesit-defun-name-function #'fsharp-ts-mode--defun-name)

    ;; Imenu
    (setq-local treesit-simple-imenu-settings fsharp-ts-mode--imenu-settings)

    ;; Structured navigation
    (setq-local forward-sexp-function #'fsharp-ts-mode--forward-sexp-hybrid)

    ;; Thing-based navigation (Emacs 30+)
    (when (boundp 'treesit-thing-settings)
      (setq-local treesit-thing-settings
                  (fsharp-ts-mode--thing-settings language)))

    (treesit-major-mode-setup)))

(defvar fsharp-ts-base-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-a") #'ff-find-other-file)
    (define-key map (kbd "C-c C-c") #'compile)
    (define-key map (kbd "C-c C-d") #'fsharp-ts-mode-doc-at-point)
    (define-key map (kbd "C-c >") #'fsharp-ts-mode-shift-region-right)
    (define-key map (kbd "C-c <") #'fsharp-ts-mode-shift-region-left)
    (easy-menu-define fsharp-ts-mode-menu map "F# Mode Menu"
      '("F#"
        ["Compile" compile t]
        ["Switch to .fs/.fsi" ff-find-other-file t]
        ["Shift Region Right" fsharp-ts-mode-shift-region-right
         :active mark-active]
        ["Shift Region Left" fsharp-ts-mode-shift-region-left
         :active mark-active]
        ["Guess Indent Offset" fsharp-ts-mode-guess-indent-offset t]
        "---"
        ["Browse F# Docs" fsharp-ts-mode-browse-fsharp-docs t]
        ["Look Up Symbol at Point" fsharp-ts-mode-doc-at-point t]
        "---"
        ["Install Grammars" fsharp-ts-mode-install-grammars t]
        ["Show Version" fsharp-ts-mode-version t]
        ["Bug Report Info" fsharp-ts-mode-bug-report-info t]
        ["Report a Bug" fsharp-ts-mode-report-bug t]))
    map)
  "Keymap for `fsharp-ts-base-mode'.")

(define-derived-mode fsharp-ts-base-mode prog-mode "F#"
  "Base major mode for F# files, providing shared setup.
This mode is not intended to be used directly.  Use `fsharp-ts-mode'
for .fs files and `fsharp-ts-signature-mode' for .fsi files."
  :syntax-table fsharp-ts-base-mode-syntax-table

  ;; Comment settings: F# primarily uses // line comments
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "//+\\s-*")
  ;; Make fill-paragraph preserve // prefixes on wrapped comment lines
  (setq-local adaptive-fill-regexp "[ \t]*\\(//+[ \t]*\\)*")

  ;; F# indentation is context-sensitive; electric-indent can't compute
  ;; correct indentation from a single keystroke, so inhibit it.
  (setq-local electric-indent-inhibit t)

  (setq-local treesit-font-lock-feature-list
              '((comment definition)
                (keyword string type)
                (attribute builtin constant escape-sequence number)
                (operator bracket delimiter variable property function)))

  (setq-local indent-line-function #'treesit-indent)

  ;; which-func-mode / add-log integration
  (setq-local add-log-current-defun-function #'treesit-add-log-current-defun)

  ;; ff-find-other-file setup
  (setq-local ff-other-file-alist fsharp-ts-other-file-alist)

  ;; outline-minor-mode integration (Emacs 30+)
  (when (boundp 'treesit-outline-predicate)
    (setq-local treesit-outline-predicate
                (cons fsharp-ts-mode--defun-type-regexp
                      #'fsharp-ts-mode--defun-valid-p)))

  ;; Prettify symbols
  (setq-local prettify-symbols-alist fsharp-ts-mode-prettify-symbols-alist)

  ;; Auto-guess indentation offset from file contents
  (when (and fsharp-ts-guess-indent-offset
             buffer-file-name
             (> (buffer-size) 0))
    (fsharp-ts-mode-guess-indent-offset)))

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

;; Register F# compilation error regexp once at load time
(fsharp-ts-mode--setup-compilation)

;; Hide F# build artifacts from find-file completion
(dolist (ext '(".dll" ".exe" ".pdb"))
  (add-to-list 'completion-ignored-extensions ext))

;; Offer to switch away from bin/obj copies
(add-hook 'find-file-hook #'fsharp-ts-mode--check-build-dir)

;; Eglot integration: set the language IDs that fsautocomplete expects.
(put 'fsharp-ts-mode 'eglot-language-id "fsharp")
(put 'fsharp-ts-signature-mode 'eglot-language-id "fsharp")

(provide 'fsharp-ts-mode)

;;; fsharp-ts-mode.el ends here
