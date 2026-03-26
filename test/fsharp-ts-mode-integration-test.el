;;; fsharp-ts-mode-integration-test.el --- Integration tests for fsharp-ts-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov

;;; Commentary:

;; Integration tests that load sample resource files and verify that
;; indentation and font-lock work correctly end-to-end.

;;; Code:

(require 'buttercup)
(require 'fsharp-ts-mode)

(defvar fsharp-ts-mode-test--resources-dir
  (expand-file-name "resources" (file-name-directory (or load-file-name buffer-file-name)))
  "Directory containing test resource files.")

(defun fsharp-ts-mode-test--resource-file (name)
  "Return the absolute path of resource file NAME."
  (expand-file-name name fsharp-ts-mode-test--resources-dir))

(describe "integration: sample.fs"
  (before-all
    (unless (treesit-language-available-p 'fsharp)
      (signal 'buttercup-pending "fsharp grammar not available")))

  (it "preserves correct indentation after indent-region"
    (let* ((file (fsharp-ts-mode-test--resource-file "sample.fs"))
           (original (with-temp-buffer
                       (insert-file-contents file)
                       (buffer-string))))
      (with-temp-buffer
        (insert original)
        (fsharp-ts-mode)
        (indent-region (point-min) (point-max))
        (expect (buffer-string) :to-equal original))))

  (it "applies expected font-lock faces"
    (let ((file (fsharp-ts-mode-test--resource-file "sample.fs")))
      (with-temp-buffer
        (insert-file-contents file)
        (let ((treesit-font-lock-level 4))
          (fsharp-ts-mode))
        (font-lock-ensure)
        ;; Check that "let" keyword is fontified
        (goto-char (point-min))
        (search-forward "let area")
        (expect (get-text-property (match-beginning 0) 'face)
                :to-equal 'font-lock-keyword-face)
        ;; Check that a type name is fontified
        (goto-char (point-min))
        (search-forward "type Shape")
        (let ((type-start (+ (match-beginning 0) 5)))
          (expect (get-text-property type-start 'face)
                  :to-equal 'font-lock-type-face))
        ;; Check that a comment is fontified
        (goto-char (point-min))
        (search-forward "// A function using try/with")
        (expect (get-text-property (match-beginning 0) 'face)
                :to-equal 'font-lock-comment-face)))))

(describe "integration: sample.fsi"
  (before-all
    (unless (treesit-language-available-p 'fsharp-signature)
      (signal 'buttercup-pending "fsharp-signature grammar not available")))

  (it "preserves correct indentation after indent-region"
    (let* ((file (fsharp-ts-mode-test--resource-file "sample.fsi"))
           (original (with-temp-buffer
                       (insert-file-contents file)
                       (buffer-string))))
      (with-temp-buffer
        (insert original)
        (fsharp-ts-signature-mode)
        (indent-region (point-min) (point-max))
        (expect (buffer-string) :to-equal original))))

  (it "applies expected font-lock faces"
    (let ((file (fsharp-ts-mode-test--resource-file "sample.fsi")))
      (with-temp-buffer
        (insert-file-contents file)
        (let ((treesit-font-lock-level 4))
          (fsharp-ts-signature-mode))
        (font-lock-ensure)
        ;; Check that "val" keyword is fontified
        (goto-char (point-min))
        (search-forward "val area")
        (expect (get-text-property (match-beginning 0) 'face)
                :to-equal 'font-lock-keyword-face)
        ;; Check that a doc comment is fontified
        (goto-char (point-min))
        (search-forward "/// Compute the area")
        (expect (get-text-property (match-beginning 0) 'face)
                :to-equal 'font-lock-doc-face)))))

(describe "integration: sample.fsx"
  (before-all
    (unless (treesit-language-available-p 'fsharp)
      (signal 'buttercup-pending "fsharp grammar not available")))

  (it "preserves correct indentation after indent-region"
    (let* ((file (fsharp-ts-mode-test--resource-file "sample.fsx"))
           (original (with-temp-buffer
                       (insert-file-contents file)
                       (buffer-string))))
      (with-temp-buffer
        (insert original)
        (fsharp-ts-mode)
        (indent-region (point-min) (point-max))
        (expect (buffer-string) :to-equal original))))

  (it "applies expected font-lock faces"
    (let ((file (fsharp-ts-mode-test--resource-file "sample.fsx")))
      (with-temp-buffer
        (insert-file-contents file)
        (let ((treesit-font-lock-level 4))
          (fsharp-ts-mode))
        (font-lock-ensure)
        ;; Check that "let" keyword is fontified
        (goto-char (point-min))
        (search-forward "let greeting")
        (expect (get-text-property (match-beginning 0) 'face)
                :to-equal 'font-lock-keyword-face)
        ;; Check that a string is fontified
        (goto-char (point-min))
        (search-forward "Hello from F# script!")
        (expect (get-text-property (match-beginning 0) 'face)
                :to-equal 'font-lock-string-face)))))


;;; fsharp-ts-mode-integration-test.el ends here
