;;; fsharp-ts-eglot.el --- Enhanced Eglot integration for F# -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov
;;
;; Author: Bozhidar Batsov <bozhidar@batsov.dev>

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Enhanced Eglot integration with FsAutoComplete for fsharp-ts-mode.
;; Provides auto-download of the LSP server, rich initialization options,
;; type signature display, documentation lookup, XML doc generation,
;; and .fsproj file manipulation commands.
;;
;; Basic usage:
;;
;;   (require 'fsharp-ts-eglot)
;;   (add-hook 'fsharp-ts-mode-hook #'eglot-ensure)

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

(require 'eglot)
(require 'json)

(defgroup fsharp-ts-eglot nil
  "Enhanced Eglot integration for F# with FsAutoComplete."
  :prefix "fsharp-ts-eglot-"
  :group 'fsharp-ts
  :link '(url-link :tag "FsAutoComplete" "https://github.com/fsharp/FsAutoComplete"))

;;;; FsAutoComplete installation

(defcustom fsharp-ts-eglot-server-version "latest"
  "Version of FsAutoComplete to install.
Set to \"latest\" to always fetch the newest release from NuGet,
or pin to a specific version like \"0.76.0\" to avoid surprises."
  :type 'string
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-eglot-server-install-dir
  (expand-file-name "fsautocomplete" user-emacs-directory)
  "Directory where FsAutoComplete is installed.
Set to nil to use a globally installed fsautocomplete."
  :type '(choice (directory :tag "Local install directory")
                 (const :tag "Use global install" nil))
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-eglot-auto-install t
  "When non-nil, automatically install FsAutoComplete if not found."
  :type 'boolean
  :package-version '(fsharp-ts-mode . "0.1.0"))

;;;; LSP feature toggles

(defcustom fsharp-ts-eglot-enable-analyzers nil
  "When non-nil, enable F# Analyzers SDK integration."
  :type 'boolean
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-eglot-unused-opens-analyzer t
  "When non-nil, highlight unused `open' statements."
  :type 'boolean
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-eglot-unused-declarations-analyzer t
  "When non-nil, highlight unused declarations."
  :type 'boolean
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-eglot-simplify-name-analyzer nil
  "When non-nil, suggest removing redundant qualifiers."
  :type 'boolean
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-eglot-linter t
  "When non-nil, enable the built-in FSharpLint integration."
  :type 'boolean
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-eglot-code-lenses t
  "When non-nil, enable reference count and signature code lenses."
  :type 'boolean
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-eglot-inlay-hints t
  "When non-nil, enable inlay hints for types and parameter names."
  :type 'boolean
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-eglot-pipeline-hints nil
  "When non-nil, show type hints for pipeline operators."
  :type 'boolean
  :package-version '(fsharp-ts-mode . "0.1.0"))

;;;; Server class

(defclass fsharp-ts-eglot-server (eglot-lsp-server) ()
  :documentation "FsAutoComplete LSP server for F#.")

(cl-defmethod eglot-initialization-options ((_server fsharp-ts-eglot-server))
  "Return initialization options for FsAutoComplete."
  `(:automaticWorkspaceInit t))

(cl-defmethod eglot-workspace-configuration ((_server fsharp-ts-eglot-server))
  "Return workspace configuration for FsAutoComplete."
  (list :FSharp
        (list
         :AutomaticWorkspaceInit t
         :keywordsAutocomplete t
         :resolveNamespaces t
         :Linter (if fsharp-ts-eglot-linter t :json-false)
         :enableAnalyzers (if fsharp-ts-eglot-enable-analyzers t :json-false)
         :UnusedOpensAnalyzer (if fsharp-ts-eglot-unused-opens-analyzer t :json-false)
         :UnusedDeclarationsAnalyzer (if fsharp-ts-eglot-unused-declarations-analyzer t :json-false)
         :SimplifyNameAnalyzer (if fsharp-ts-eglot-simplify-name-analyzer t :json-false)
         :EnableReferenceCodeLens (if fsharp-ts-eglot-code-lenses t :json-false)
         :inlayHints (list
                      :enabled (if fsharp-ts-eglot-inlay-hints t :json-false)
                      :parameterNames (if fsharp-ts-eglot-inlay-hints t :json-false)
                      :typeAnnotations (if fsharp-ts-eglot-inlay-hints t :json-false))
         :codeLenses (list
                      :references (list :enabled (if fsharp-ts-eglot-code-lenses t :json-false))
                      :signature (list :enabled (if fsharp-ts-eglot-code-lenses t :json-false)))
         :pipelineHints (list
                         :enabled (if fsharp-ts-eglot-pipeline-hints t :json-false)
                         :prefix " // ")
         :InterfaceStubGeneration t
         :InterfaceStubGenerationObjectIdentifier "this"
         :InterfaceStubGenerationMethodBody "failwith \"Not Implemented\""
         :RecordStubGeneration t
         :RecordStubGenerationBody "failwith \"Not Implemented\""
         :UnionCaseStubGeneration t
         :UnionCaseStubGenerationBody "failwith \"Not Implemented\""
         :excludeProjectDirectories [".git" "paket-files" ".fable" "packages" "node_modules"])))

;;;; Server installation and discovery

(defconst fsharp-ts-eglot--nuget-search-url
  "https://azuresearch-usnc.nuget.org/query?q=fsautocomplete&prerelease=false&packageType=DotnetTool"
  "NuGet API URL for searching FsAutoComplete.")

(defun fsharp-ts-eglot--latest-version ()
  "Fetch the latest FsAutoComplete version from NuGet."
  (with-temp-buffer
    (url-insert-file-contents fsharp-ts-eglot--nuget-search-url)
    (let* ((json-object-type 'alist)
           (json-array-type 'list)
           (result (json-read))
           (data (alist-get 'data result))
           (package (car data)))
      (alist-get 'version package))))

(defun fsharp-ts-eglot--installed-version ()
  "Return the installed FsAutoComplete version, or nil."
  (when fsharp-ts-eglot-server-install-dir
    (let ((output (shell-command-to-string
                   (format "dotnet tool list --tool-path %s"
                           (shell-quote-argument fsharp-ts-eglot-server-install-dir)))))
      (when (string-match "fsautocomplete\\s-+\\([0-9.]+\\)" output)
        (match-string 1 output)))))

(defun fsharp-ts-eglot--server-command ()
  "Return the command list to start FsAutoComplete."
  (let ((executable (if fsharp-ts-eglot-server-install-dir
                        (expand-file-name "fsautocomplete"
                                          fsharp-ts-eglot-server-install-dir)
                      "fsautocomplete")))
    (list executable "--adaptive-lsp-server-enabled")))

(defun fsharp-ts-eglot-install-server (&optional force)
  "Install or update FsAutoComplete.
With prefix argument FORCE, reinstall even if already present."
  (interactive "P")
  (let* ((desired (if (equal fsharp-ts-eglot-server-version "latest")
                      (progn
                        (message "Checking latest FsAutoComplete version...")
                        (fsharp-ts-eglot--latest-version))
                    fsharp-ts-eglot-server-version))
         (installed (fsharp-ts-eglot--installed-version))
         (install-dir (or fsharp-ts-eglot-server-install-dir
                          (error "Set `fsharp-ts-eglot-server-install-dir' for local install"))))
    (if (and (not force) (equal installed desired))
        (message "FsAutoComplete %s is already installed" installed)
      (when installed
        (message "Uninstalling FsAutoComplete %s..." installed)
        (shell-command-to-string
         (format "dotnet tool uninstall fsautocomplete --tool-path %s"
                 (shell-quote-argument install-dir))))
      (message "Installing FsAutoComplete %s..." desired)
      (let ((output (shell-command-to-string
                     (format "dotnet tool install fsautocomplete --tool-path %s --version %s"
                             (shell-quote-argument install-dir)
                             (shell-quote-argument desired)))))
        (if (string-match-p "was successfully installed" output)
            (message "FsAutoComplete %s installed successfully" desired)
          (error "Failed to install FsAutoComplete: %s" output))))))

(defun fsharp-ts-eglot--ensure-server ()
  "Ensure FsAutoComplete is installed, installing if needed."
  (when (and fsharp-ts-eglot-auto-install
             fsharp-ts-eglot-server-install-dir
             (not (fsharp-ts-eglot--installed-version)))
    (fsharp-ts-eglot-install-server)))

;;;; Custom LSP commands

(defun fsharp-ts-eglot--request (method params)
  "Send a custom METHOD request with PARAMS to the F# LSP server.
Returns the result or nil if eglot is not active."
  (when-let* ((server (eglot-current-server)))
    (jsonrpc-request server method params)))

(defun fsharp-ts-eglot-signature-at-point ()
  "Display the type signature of the symbol at point."
  (interactive)
  (let* ((params (eglot--TextDocumentPositionParams))
         (result (fsharp-ts-eglot--request :fsharp/signature params)))
    (if result
        (message "%s" result)
      (message "No signature information available"))))

(defun fsharp-ts-eglot-f1-help ()
  "Open the MSDN documentation for the symbol at point.
Falls back to a .NET API search if the LSP server doesn't provide a URL."
  (interactive)
  (let* ((params (eglot--TextDocumentPositionParams))
         (result (condition-case nil
                     (fsharp-ts-eglot--request :fsharp/f1Help params)
                   (error nil))))
    (if (and result (stringp result) (not (string-empty-p result)))
        (browse-url result)
      ;; Fall back to .NET API search
      (let ((symbol (thing-at-point 'symbol t)))
        (if symbol
            (browse-url
             (format "https://learn.microsoft.com/en-us/dotnet/api/?term=%s"
                     (url-hexify-string symbol)))
          (user-error "No symbol at point"))))))

(defun fsharp-ts-eglot-generate-doc-comment ()
  "Generate an XML documentation comment stub for the definition at point."
  (interactive)
  (let* ((params (eglot--TextDocumentPositionParams))
         (result (condition-case err
                     (fsharp-ts-eglot--request
                      :fsharp/documentationGenerator params)
                   (error (message "Doc generation failed: %s" (cdr err))
                          nil))))
    (when result
      (message "Documentation comment generated"))))

;;;; .fsproj manipulation

(defun fsharp-ts-eglot--fsproj-for-current-file ()
  "Find the .fsproj file for the current buffer."
  (when-let* ((file (buffer-file-name))
              (dir (file-name-directory file))
              (proj-dir (locate-dominating-file
                         dir (lambda (d)
                               (directory-files d nil "\\.fsproj\\'" t)))))
    (car (directory-files proj-dir t "\\.fsproj\\'"))))

(defun fsharp-ts-eglot--fsproj-request (method)
  "Send an fsproj METHOD request for the current file."
  (let* ((fsproj (or (fsharp-ts-eglot--fsproj-for-current-file)
                     (user-error "No .fsproj found for current file")))
         (file (or (buffer-file-name)
                   (user-error "Buffer is not visiting a file")))
         (relative (file-relative-name file (file-name-directory fsproj))))
    (fsharp-ts-eglot--request method
                               (list :FsProj fsproj
                                     :FileVirtualPath relative))))

(defun fsharp-ts-eglot-fsproj-move-file-up ()
  "Move the current file up in the .fsproj compilation order."
  (interactive)
  (fsharp-ts-eglot--fsproj-request :fsproj/moveFileUp)
  (message "Moved file up in project"))

(defun fsharp-ts-eglot-fsproj-move-file-down ()
  "Move the current file down in the .fsproj compilation order."
  (interactive)
  (fsharp-ts-eglot--fsproj-request :fsproj/moveFileDown)
  (message "Moved file down in project"))

(defun fsharp-ts-eglot-fsproj-remove-file ()
  "Remove the current file from the .fsproj."
  (interactive)
  (when (y-or-n-p "Remove current file from the project?")
    (fsharp-ts-eglot--fsproj-request :fsproj/removeFile)
    (message "Removed file from project")))

(defun fsharp-ts-eglot-fsproj-add-file ()
  "Add the current file to the .fsproj."
  (interactive)
  (fsharp-ts-eglot--fsproj-request :fsproj/addFile)
  (message "Added file to project"))

;;;; xref workaround

;; FsAutoComplete sometimes returns a jsonrpc error instead of an
;; empty list when go-to-definition finds nothing (spec violation).
(cl-defmethod xref-backend-definitions :around
  (backend identifier &context (major-mode fsharp-ts-mode))
  "Handle FsAutoComplete returning an error for missing definitions."
  (condition-case nil
      (cl-call-next-method backend identifier)
    (jsonrpc-error nil)))

(cl-defmethod xref-backend-definitions :around
  (backend identifier &context (major-mode fsharp-ts-signature-mode))
  "Handle FsAutoComplete returning an error for missing definitions."
  (condition-case nil
      (cl-call-next-method backend identifier)
    (jsonrpc-error nil)))

;;;; Registration

(defun fsharp-ts-eglot--server-contact (_interactive)
  "Return the server contact for FsAutoComplete.
Ensures the server is installed before returning the command."
  (fsharp-ts-eglot--ensure-server)
  (fsharp-ts-eglot--server-command))

;; Register for both fsharp-ts-mode and fsharp-ts-signature-mode
(add-to-list 'eglot-server-programs
             '((fsharp-ts-mode fsharp-ts-signature-mode) .
               (fsharp-ts-eglot-server . fsharp-ts-eglot--server-contact)))

(provide 'fsharp-ts-eglot)

;;; fsharp-ts-eglot.el ends here
