;;; fsharp-ts-mode-test-helpers.el --- Shared test helpers for fsharp-ts-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov

;;; Commentary:

;; Shared macros and functions used across fsharp-ts-mode buttercup test suites.
;; Provides unified buffer setup, font-lock assertion helpers, and
;; indentation test macros that work with both `fsharp-ts-mode' and
;; `fsharp-ts-signature-mode'.

;;; Code:

(require 'buttercup)
(require 'fsharp-ts-mode)

;;;; String helpers

(defun fsharp-ts-mode-test--dedent (string)
  "Remove common leading whitespace from all non-empty lines in STRING.
A single leading newline is stripped (so the string can start on the
line after the opening quote), and a single trailing newline followed
by only whitespace is stripped (so the closing quote can sit on its
own indented line).  Interior blank lines and trailing newlines that
are part of the content are preserved.

  (fsharp-ts-mode-test--dedent \"
    let x = 1
    let y = 2\")

produces \"let x = 1\\nlet y = 2\"."
  (if (not (string-search "\n" string))
      string
    (let* ((str (if (string-prefix-p "\n" string)
                    (substring string 1)
                  string))
           (str (if (string-match "\n[ \t]*\\'" str)
                    (substring str 0 (match-beginning 0))
                  str))
           (lines (split-string str "\n"))
           (non-empty (seq-filter (lambda (l) (not (string-blank-p l))) lines))
           (min-indent (if non-empty
                          (apply #'min (mapcar (lambda (l)
                                                (- (length l) (length (string-trim-left l))))
                                              non-empty))
                        0)))
      (mapconcat (lambda (l)
                   (if (string-blank-p l) ""
                     (substring l min-indent)))
                 lines "\n"))))

;;;; Buffer setup

(defmacro with-fsharp-ts-mode-test-buffer (mode content &rest body)
  "Set up a temporary buffer with CONTENT in MODE, run BODY.
MODE should be a symbol like `fsharp-ts-mode' or `fsharp-ts-signature-mode'.
CONTENT is automatically dedented via `fsharp-ts-mode-test--dedent'."
  (declare (indent 2))
  `(with-temp-buffer
     (insert (fsharp-ts-mode-test--dedent ,content))
     (funcall #',mode)
     (goto-char (point-min))
     ,@body))

(defmacro with-fsharp-ts-mode-buffer (content &rest body)
  "Set up a temporary buffer with CONTENT in `fsharp-ts-mode', run BODY.
CONTENT is automatically dedented via `fsharp-ts-mode-test--dedent'."
  (declare (indent 1))
  `(with-fsharp-ts-mode-test-buffer fsharp-ts-mode ,content ,@body))

(defmacro with-fsharp-ts-signature-buffer (content &rest body)
  "Set up a temporary buffer with CONTENT in `fsharp-ts-signature-mode', run BODY.
CONTENT is automatically dedented via `fsharp-ts-mode-test--dedent'."
  (declare (indent 1))
  `(with-fsharp-ts-mode-test-buffer fsharp-ts-signature-mode ,content ,@body))

;;;; Font-lock helpers

(defun fsharp-ts-mode-test-face-at-range (start end)
  "Return the face at range [START, END] in the current buffer.
If all positions in the range share the same face, return it.
Otherwise return the symbol `various-faces'."
  (let ((face (get-text-property start 'face)))
    (if (= start end)
        face
      (let ((pos (1+ start))
            (consistent t))
        (while (and consistent (<= pos end))
          (unless (equal (get-text-property pos 'face) face)
            (setq consistent nil))
          (setq pos (1+ pos)))
        (if consistent face 'various-faces)))))

(defun fsharp-ts-mode-test--check-face-specs (mode content face-specs)
  "Fontify CONTENT with MODE and assert FACE-SPECS.
Each element of FACE-SPECS is either:
  (\"text\" EXPECTED-FACE) -- search for \"text\" sequentially and check its face
  (START END EXPECTED-FACE) -- check face at position range [START, END]"
  (with-temp-buffer
    (insert content)
    (let ((treesit-font-lock-level 4))
      (funcall mode))
    (font-lock-ensure)
    (goto-char (point-min))
    (dolist (spec face-specs)
      (if (stringp (car spec))
          ;; Text-based spec: ("text" face)
          (let* ((text (nth 0 spec))
                 (expected (nth 1 spec))
                 (case-fold-search nil)
                 (found (if (string-match-p "\\`[a-zA-Z_][a-zA-Z0-9_]*\\'" text)
                            (re-search-forward
                             (concat "\\_<" (regexp-quote text) "\\_>") nil t)
                          (search-forward text nil t))))
            (expect found :not :to-be nil)
            (when found
              (let* ((start (match-beginning 0))
                     (end (1- (match-end 0)))
                     (actual (fsharp-ts-mode-test-face-at-range start end)))
                (expect actual :to-equal expected))))
        ;; Position-based spec: (start end face)
        (let* ((start (nth 0 spec))
               (end (nth 1 spec))
               (expected (nth 2 spec))
               (actual (fsharp-ts-mode-test-face-at-range start end)))
          (expect actual :to-equal expected))))))

(defmacro when-fontifying-it (description &rest tests)
  "Create a Buttercup test asserting font-lock faces in F# code.
DESCRIPTION is the test name.  Each element of TESTS is
  (CODE SPEC ...)
where each SPEC is either (\"text\" FACE) for text-based matching
or (START END FACE) for position-based matching."
  (declare (indent 1))
  `(it ,description
     (dolist (test (quote ,tests))
       (let ((content (car test))
             (specs (cdr test)))
         (fsharp-ts-mode-test--check-face-specs #'fsharp-ts-mode content specs)))))

(defmacro when-fontifying-signature-it (description &rest tests)
  "Create a Buttercup test asserting font-lock faces in F# signature code.
DESCRIPTION is the test name.  Each element of TESTS is
  (CODE SPEC ...)
where each SPEC is either (\"text\" FACE) for text-based matching
or (START END FACE) for position-based matching."
  (declare (indent 1))
  `(it ,description
     (dolist (test (quote ,tests))
       (let ((content (car test))
             (specs (cdr test)))
         (fsharp-ts-mode-test--check-face-specs #'fsharp-ts-signature-mode content specs)))))

;;;; Indentation helpers

(defun fsharp-ts-mode-test--strip-indentation (code)
  "Remove all leading whitespace from each line of CODE."
  (mapconcat
   (lambda (line) (string-trim-left line))
   (split-string code "\n")
   "\n"))

(defmacro when-indenting--it (mode description &rest code-strings)
  "Create a Buttercup test that asserts indentation is preserved.
MODE is the major mode function to use.  DESCRIPTION is the test name.
Each element of CODE-STRINGS is a properly-indented F# code string.

Since F# is an indentation-sensitive language, the tree-sitter parser
needs correct indentation to parse correctly.  We test that
`indent-region' preserves already-correct indentation (round-trip)."
  (declare (indent 2))
  `(it ,description
     ,@(mapcar
        (lambda (code)
          `(let ((expected ,code))
             (expect
              (with-temp-buffer
                (insert expected)
                (funcall #',mode)
                (indent-region (point-min) (point-max))
                (buffer-string))
              :to-equal expected)))
        code-strings)))

(defmacro when-indenting-it (description &rest code-strings)
  "Create a Buttercup test that asserts each CODE-STRING indents correctly.
DESCRIPTION is the test name.  Uses `fsharp-ts-mode'."
  (declare (indent 1))
  `(when-indenting--it fsharp-ts-mode ,description ,@code-strings))

(defmacro when-indenting-signature-it (description &rest code-strings)
  "Create a Buttercup test that asserts each CODE-STRING indents correctly.
DESCRIPTION is the test name.  Uses `fsharp-ts-signature-mode'."
  (declare (indent 1))
  `(when-indenting--it fsharp-ts-signature-mode ,description ,@code-strings))

(defmacro when-newline-indenting--it (mode description &rest tests)
  "Create a Buttercup test asserting empty-line indentation.
MODE is the major mode function.  DESCRIPTION is the test name.
Each element of TESTS is (CODE EXPECTED-COLUMN) where CODE is a
source string and EXPECTED-COLUMN is the column that
`newline-and-indent' should produce after CODE."
  (declare (indent 2))
  `(it ,description
     (dolist (test (quote ,tests))
       (let ((code (nth 0 test))
             (expected-col (nth 1 test)))
         (with-temp-buffer
           (insert code)
           (let ((treesit-font-lock-level 4))
             (funcall #',mode))
           (goto-char (point-max))
           (newline-and-indent)
           (expect (current-column) :to-equal expected-col))))))

(defmacro when-newline-indenting-it (description &rest tests)
  "Create a Buttercup test asserting empty-line indentation.
DESCRIPTION is the test name.  Uses `fsharp-ts-mode'."
  (declare (indent 1))
  `(when-newline-indenting--it fsharp-ts-mode ,description ,@tests))

(provide 'fsharp-ts-mode-test-helpers)

;;; fsharp-ts-mode-test-helpers.el ends here
