;;; fsharp-ts-eglot-test.el --- Tests for fsharp-ts-eglot -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov

;;; Commentary:

;; Tests for the enhanced Eglot integration.  These cover the
;; configuration and discovery logic -- actual LSP communication
;; requires a running FsAutoComplete server and is not tested here.

;;; Code:

(require 'buttercup)
(require 'fsharp-ts-eglot)

(describe "fsharp-ts-eglot"
  (describe "server command"
    (it "includes the adaptive lsp flag"
      (let ((cmd (fsharp-ts-eglot--server-command)))
        (expect cmd :to-contain "--adaptive-lsp-server-enabled")))

    (it "uses install dir when set"
      (let ((fsharp-ts-eglot-server-install-dir "/tmp/test-fsac"))
        (let ((cmd (fsharp-ts-eglot--server-command)))
          (expect (car cmd) :to-match "/tmp/test-fsac/fsautocomplete"))))

    (it "uses bare executable when install dir is nil"
      (let ((fsharp-ts-eglot-server-install-dir nil))
        (let ((cmd (fsharp-ts-eglot--server-command)))
          (expect (car cmd) :to-equal "fsautocomplete")))))

  (describe "fsproj detection"
    (it "finds fsproj in the current directory"
      (let* ((dir (make-temp-file "fsharp-test" t))
             (fsproj (expand-file-name "Test.fsproj" dir))
             (source (expand-file-name "Program.fs" dir)))
        (unwind-protect
            (progn
              (with-temp-file fsproj (insert "<Project></Project>"))
              (with-temp-file source (insert "let x = 1"))
              (with-temp-buffer
                (insert-file-contents source)
                (setq buffer-file-name source)
                (setq default-directory (file-name-as-directory dir))
                (let ((found (fsharp-ts-eglot--fsproj-for-current-file)))
                  (expect found :to-match "Test\\.fsproj"))))
          (delete-directory dir t))))

    (it "finds fsproj in a parent directory"
      (let* ((root (make-temp-file "fsharp-test" t))
             (subdir (expand-file-name "src" root))
             (fsproj (expand-file-name "Test.fsproj" root))
             (source (expand-file-name "Program.fs" subdir)))
        (unwind-protect
            (progn
              (make-directory subdir)
              (with-temp-file fsproj (insert "<Project></Project>"))
              (with-temp-file source (insert "let x = 1"))
              (with-temp-buffer
                (insert-file-contents source)
                (setq buffer-file-name source)
                (setq default-directory (file-name-as-directory subdir))
                (let ((found (fsharp-ts-eglot--fsproj-for-current-file)))
                  (expect found :to-match "Test\\.fsproj"))))
          (delete-directory root t))))

    (it "returns nil when no fsproj exists"
      (let* ((dir (make-temp-file "fsharp-test" t))
             (source (expand-file-name "Program.fs" dir)))
        (unwind-protect
            (progn
              (with-temp-file source (insert "let x = 1"))
              (with-temp-buffer
                (insert-file-contents source)
                (setq buffer-file-name source)
                (setq default-directory (file-name-as-directory dir))
                (expect (fsharp-ts-eglot--fsproj-for-current-file) :to-be nil)))
          (delete-directory dir t)))))

  (describe "eglot-server-programs registration"
    (it "registers for fsharp-ts-mode"
      (let ((found (cl-find-if
                    (lambda (entry)
                      (and (consp (car entry))
                           (memq 'fsharp-ts-mode (car entry))))
                    eglot-server-programs)))
        (expect found :not :to-be nil)))

    (it "registers for fsharp-ts-signature-mode"
      (let ((found (cl-find-if
                    (lambda (entry)
                      (and (consp (car entry))
                           (memq 'fsharp-ts-signature-mode (car entry))))
                    eglot-server-programs)))
        (expect found :not :to-be nil))))

  (describe "defcustom defaults"
    (it "has auto-install enabled by default"
      (expect fsharp-ts-eglot-auto-install :to-be t))

    (it "has linter enabled by default"
      (expect fsharp-ts-eglot-linter :to-be t))

    (it "has pipeline hints disabled by default"
      (expect fsharp-ts-eglot-pipeline-hints :to-be nil))

    (it "has external analyzers disabled by default"
      (expect fsharp-ts-eglot-enable-analyzers :to-be nil))))

;;; fsharp-ts-eglot-test.el ends here
