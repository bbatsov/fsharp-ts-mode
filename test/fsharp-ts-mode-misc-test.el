;;; fsharp-ts-mode-misc-test.el --- Tests for misc features -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov

;;; Commentary:

;; Tests for comment continuation, project name detection, and
;; other miscellaneous features.

;;; Code:

(require 'buttercup)
(require 'fsharp-ts-mode)

(describe "fsharp-ts-mode comment continuation"
  (it "continues /// doc comments on newline"
    (with-temp-buffer
      (fsharp-ts-mode)
      (insert "    /// This is a doc comment")
      (fsharp-ts-mode--comment-indent-new-line)
      (expect (buffer-string) :to-equal
              "    /// This is a doc comment\n    /// ")))

  (it "continues // line comments on newline"
    (with-temp-buffer
      (fsharp-ts-mode)
      (insert "    // This is a comment")
      (fsharp-ts-mode--comment-indent-new-line)
      (expect (buffer-string) :to-equal
              "    // This is a comment\n    // ")))

  (it "preserves indentation in doc comment continuation"
    (with-temp-buffer
      (fsharp-ts-mode)
      (insert "        /// Deeply indented")
      (fsharp-ts-mode--comment-indent-new-line)
      (expect (buffer-string) :to-equal
              "        /// Deeply indented\n        /// ")))

  (it "falls back to default for non-comment lines"
    (with-temp-buffer
      (fsharp-ts-mode)
      (insert "let x = 1")
      ;; Should not insert // prefix
      (fsharp-ts-mode--comment-indent-new-line)
      (expect (buffer-string) :not :to-match "//"))))

(describe "fsharp-ts-mode project name detection"
  (it "detects project name from .fsproj"
    (let* ((dir (make-temp-file "fsharp-test" t))
           (fsproj (expand-file-name "MyProject.fsproj" dir))
           (source (expand-file-name "Program.fs" dir)))
      (unwind-protect
          (progn
            (with-temp-file fsproj (insert "<Project></Project>"))
            (with-temp-file source (insert "let x = 1"))
            (with-temp-buffer
              (insert-file-contents source)
              (setq buffer-file-name source)
              (setq default-directory (file-name-as-directory dir))
              (expect (fsharp-ts-mode--detect-project-name)
                      :to-equal "MyProject")))
        (delete-directory dir t))))

  (it "returns nil when no .fsproj exists"
    (let* ((dir (make-temp-file "fsharp-test" t))
           (source (expand-file-name "Program.fs" dir)))
      (unwind-protect
          (progn
            (with-temp-file source (insert "let x = 1"))
            (with-temp-buffer
              (insert-file-contents source)
              (setq buffer-file-name source)
              (setq default-directory (file-name-as-directory dir))
              (expect (fsharp-ts-mode--detect-project-name) :to-be nil)))
        (delete-directory dir t))))

  (it "finds project in parent directory"
    (let* ((root (make-temp-file "fsharp-test" t))
           (subdir (expand-file-name "src" root))
           (fsproj (expand-file-name "App.fsproj" root))
           (source (expand-file-name "Lib.fs" subdir)))
      (unwind-protect
          (progn
            (make-directory subdir)
            (with-temp-file fsproj (insert "<Project></Project>"))
            (with-temp-file source (insert "let x = 1"))
            (with-temp-buffer
              (insert-file-contents source)
              (setq buffer-file-name source)
              (setq default-directory (file-name-as-directory subdir))
              (expect (fsharp-ts-mode--detect-project-name)
                      :to-equal "App")))
        (delete-directory root t)))))

;;; fsharp-ts-mode-misc-test.el ends here
