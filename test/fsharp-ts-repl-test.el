;;; fsharp-ts-repl-test.el --- Tests for fsharp-ts-repl -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov

;;; Commentary:

;; Tests for the REPL integration, focusing on project reference
;; resolution and directive formatting.

;;; Code:

(require 'buttercup)
(require 'fsharp-ts-repl)

(describe "fsharp-ts-repl"
  (describe "fsproj detection"
    (it "finds fsproj for a source file"
      (let* ((dir (make-temp-file "fsharp-test" t))
             (fsproj (expand-file-name "Test.fsproj" dir))
             (source (expand-file-name "Program.fs" dir)))
        (unwind-protect
            (progn
              (with-temp-file fsproj (insert "<Project></Project>"))
              (with-temp-file source (insert "let x = 1"))
              (with-temp-buffer
                (setq buffer-file-name source)
                (setq default-directory (file-name-as-directory dir))
                (expect (fsharp-ts-repl--find-fsproj) :to-match "Test\\.fsproj")))
          (delete-directory dir t))))

    (it "returns nil without fsproj"
      (let* ((dir (make-temp-file "fsharp-test" t))
             (source (expand-file-name "Program.fs" dir)))
        (unwind-protect
            (progn
              (with-temp-file source (insert "let x = 1"))
              (with-temp-buffer
                (setq buffer-file-name source)
                (setq default-directory (file-name-as-directory dir))
                (expect (fsharp-ts-repl--find-fsproj) :to-be nil)))
          (delete-directory dir t)))))

  (describe "directive formatting"
    (it "formats references and sources"
      (let ((data (list :references '("/path/to/Lib.dll" "/path/to/Other.dll")
                        :sources '("/src/Lib.fs" "/src/Program.fs"))))
        (let ((output (fsharp-ts-repl--format-directives data)))
          (expect output :to-match "#r @\"/path/to/Lib.dll\"")
          (expect output :to-match "#r @\"/path/to/Other.dll\"")
          (expect output :to-match "#load @\"/src/Lib.fs\"")
          (expect output :to-match "#load @\"/src/Program.fs\""))))

    (it "handles references only"
      (let ((data (list :references '("/path/to/Lib.dll") :sources nil)))
        (let ((output (fsharp-ts-repl--format-directives data)))
          (expect output :to-match "#r")
          (expect output :not :to-match "#load"))))

    (it "handles sources only"
      (let ((data (list :references nil :sources '("/src/File.fs"))))
        (let ((output (fsharp-ts-repl--format-directives data)))
          (expect output :not :to-match "#r")
          (expect output :to-match "#load"))))

    (it "returns empty string for no data"
      (let ((data (list :references nil :sources nil)))
        (expect (fsharp-ts-repl--format-directives data) :to-equal ""))))

  (describe "excluded references"
    (it "filters out FSharp.Core"
      (expect fsharp-ts-repl--excluded-references :to-contain "FSharp.Core"))

    (it "filters out mscorlib"
      (expect fsharp-ts-repl--excluded-references :to-contain "mscorlib"))

    (it "filters out netstandard"
      (expect fsharp-ts-repl--excluded-references :to-contain "netstandard")))

  (describe "per-project REPL buffers"
    (it "uses the base name outside any project"
      (cl-letf (((symbol-function 'fsharp-ts-repl--project-id) (lambda () nil)))
        (expect (fsharp-ts-repl--buffer) :to-equal fsharp-ts-repl-buffer-name)))

    (it "derives a per-project name from the project id"
      (cl-letf (((symbol-function 'fsharp-ts-repl--project-id) (lambda () "MyApp")))
        (let ((fsharp-ts-repl-buffer-name "*F# Interactive*"))
          (expect (fsharp-ts-repl--buffer) :to-equal "*F# Interactive: MyApp*"))))

    (it "keeps the result asterisk-wrapped even without a trailing asterisk"
      (cl-letf (((symbol-function 'fsharp-ts-repl--project-id) (lambda () "MyApp")))
        (let ((fsharp-ts-repl-buffer-name "F# Interactive"))
          (expect (fsharp-ts-repl--buffer) :to-equal "F# Interactive: MyApp*")))))

  (describe "REPL flavor"
    (it "uses the configured program for the dotnet flavor"
      (let ((fsharp-ts-repl-flavor 'dotnet)
            (fsharp-ts-repl-program-name "dotnet")
            (fsharp-ts-repl-program-args '("fsi" "--readline-")))
        (expect (fsharp-ts-repl--command)
                :to-equal '("dotnet" "fsi" "--readline-"))))

    (it "uses fsharpi for the fsharpi flavor"
      (let ((fsharp-ts-repl-flavor 'fsharpi))
        (expect (fsharp-ts-repl--command) :to-equal '("fsharpi")))))

  (describe "msbuild JSON parsing"
    (it "parses items from JSON output"
      (cl-letf (((symbol-function 'shell-command-to-string)
                 (lambda (_cmd)
                   "{\"Items\":{\"Compile\":[{\"FullPath\":\"/src/File.fs\",\"Filename\":\"File\"}]}}")))
        (let ((items (fsharp-ts-repl--msbuild-get-items "/fake.fsproj" nil "Compile")))
          (expect (length items) :to-equal 1)
          (expect (alist-get 'FullPath (car items)) :to-equal "/src/File.fs"))))

    (it "returns nil on invalid JSON"
      (cl-letf (((symbol-function 'shell-command-to-string)
                 (lambda (_cmd) "not json")))
        (expect (fsharp-ts-repl--msbuild-get-items "/fake.fsproj" nil "Compile")
                :to-be nil)))))

;;; fsharp-ts-repl-test.el ends here
