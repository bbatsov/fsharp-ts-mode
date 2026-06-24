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

(describe "fsharp-ts-format-buffer"
  (it "derives the format extension from the visited file"
    (with-temp-buffer
      (setq buffer-file-name "/tmp/Foo.fsx")
      (expect (fsharp-ts-mode--format-extension) :to-equal ".fsx")))

  (it "derives a signature extension from the major mode for non-file buffers"
    (with-temp-buffer
      (fsharp-ts-signature-mode)
      (expect (fsharp-ts-mode--format-extension) :to-equal ".fsi")))

  (it "defaults to a script extension for non-file buffers"
    (with-temp-buffer
      (fsharp-ts-mode)
      (expect (fsharp-ts-mode--format-extension) :to-equal ".fsx")))

  (it "replaces the buffer with the formatter output"
    ;; A fake formatter that rewrites the file it is given in place.
    (let ((fake (make-temp-file "fake-fantomas" nil ".sh"
                                "#!/bin/sh\nprintf 'let x = 1\\n' > \"$1\"\n")))
      (unwind-protect
          (progn
            (set-file-modes fake #o755)
            (with-temp-buffer
              (let ((fsharp-ts-fantomas-program fake))
                (insert "let  x=1")
                (fsharp-ts-format-buffer)
                (expect (buffer-string) :to-equal "let x = 1\n"))))
        (delete-file fake))))

  (it "signals an error and leaves the buffer untouched when the formatter fails"
    (let ((fake (make-temp-file "fake-fantomas" nil ".sh"
                                "#!/bin/sh\necho 'boom' >&2\nexit 1\n")))
      (unwind-protect
          (progn
            (set-file-modes fake #o755)
            (with-temp-buffer
              (let ((fsharp-ts-fantomas-program fake))
                (insert "let  x=1")
                (expect (fsharp-ts-format-buffer) :to-throw 'user-error)
                (expect (buffer-string) :to-equal "let  x=1"))))
        (delete-file fake)))))

(describe "fsharp-ts-mode-project-find"
  (it "finds the solution directory as the project root"
    (let* ((root (make-temp-file "fsharp-test" t))
           (subdir (expand-file-name "src/App" root)))
      (unwind-protect
          (progn
            (make-directory subdir t)
            (with-temp-file (expand-file-name "App.sln" root) (insert ""))
            (with-temp-file (expand-file-name "App.fsproj" subdir) (insert ""))
            (let ((project (fsharp-ts-mode-project-find subdir)))
              (expect (car project) :to-equal 'fsharp-ts)
              (expect (project-root project)
                      :to-equal (file-name-as-directory root))))
        (delete-directory root t))))

  (it "falls back to the project directory when there is no solution"
    (let* ((root (make-temp-file "fsharp-test" t))
           (subdir (expand-file-name "nested" root)))
      (unwind-protect
          (progn
            (make-directory subdir)
            (with-temp-file (expand-file-name "Lib.fsproj" root) (insert ""))
            (expect (project-root (fsharp-ts-mode-project-find subdir))
                    :to-equal (file-name-as-directory root)))
        (delete-directory root t))))

  (it "returns nil outside any F# project"
    (let ((dir (make-temp-file "fsharp-test" t)))
      (unwind-protect
          (expect (fsharp-ts-mode-project-find dir) :to-be nil)
        (delete-directory dir t)))))

(describe "fsharp-ts-mode-set-font-lock-level"
  (it "sets treesit-font-lock-level buffer-locally"
    (with-temp-buffer
      (fsharp-ts-mode)
      (fsharp-ts-mode-set-font-lock-level 2)
      (expect treesit-font-lock-level :to-equal 2)
      (expect (local-variable-p 'treesit-font-lock-level) :to-be-truthy))))

;;; fsharp-ts-mode-misc-test.el ends here
