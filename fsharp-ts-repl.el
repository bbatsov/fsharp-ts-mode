;;; fsharp-ts-repl.el --- F# Interactive (REPL) integration -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov
;;
;; Author: Bozhidar Batsov <bozhidar@batsov.dev>

;; This file is not part of GNU Emacs.

;;; Commentary:

;; This library provides integration with F# Interactive (dotnet fsi)
;; for the fsharp-ts-mode package.  It offers a comint-based REPL with
;; tree-sitter syntax highlighting for input, and a minor mode for
;; sending code from source buffers.

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

(require 'comint)
(require 'json)
(require 'pulse)
(require 'seq)
(require 'fsharp-ts-mode)

(declare-function eglot-current-server "eglot")
(declare-function jsonrpc-request "jsonrpc")

(defgroup fsharp-ts-repl nil
  "F# Interactive (REPL) integration for fsharp-ts-mode."
  :prefix "fsharp-ts-repl-"
  :group 'fsharp-ts)

(defcustom fsharp-ts-repl-program-name "dotnet"
  "Program name for invoking F# Interactive."
  :type 'string
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-repl-program-args '("fsi" "--readline-")
  "Command line arguments for `fsharp-ts-repl-program-name'.

The default invokes `dotnet fsi --readline-'.  The `--readline-' flag
disables the built-in readline support which conflicts with comint's
own line editing.

If you have a standalone `dotnet-fsi' or `fsi' binary, set
`fsharp-ts-repl-program-name' accordingly and adjust this list."
  :type '(repeat string)
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-repl-buffer-name "*F# Interactive*"
  "Base name of the F# Interactive REPL buffer.
Per-project REPLs derive their name from this (e.g. \"*F# Interactive: proj*\")."
  :type 'string
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-repl-flavor 'dotnet
  "Which F# Interactive `fsharp-ts-repl' launches.
- `dotnet': the modern .NET F# Interactive, using `fsharp-ts-repl-program-name'
  and `fsharp-ts-repl-program-args' (the default `dotnet fsi --readline-').
- `fsharpi': the standalone `fsharpi'/`fsi' toplevel (Mono and legacy installs).

Set this globally or per project via a `.dir-locals.el' file; the REPL reads
it when it starts."
  :type '(choice (const :tag "dotnet fsi" dotnet)
                 (const :tag "fsharpi" fsharpi))
  :safe (lambda (v) (memq v '(dotnet fsharpi)))
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-repl-history-file
  (expand-file-name "fsharp-ts-repl-history" user-emacs-directory)
  "File to persist F# REPL input history across sessions.
Set to nil to disable history persistence."
  :type '(choice (file :tag "History file")
                 (const :tag "Disable" nil))
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-repl-history-size 1000
  "Maximum number of input history entries to persist."
  :type 'integer
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-repl-fontify-input t
  "When non-nil, fontify REPL input using tree-sitter via `fsharp-ts-mode'.
This uses `comint-fontify-input-mode' (Emacs 29.1+) to provide full
syntax highlighting for F# code you type in the REPL, while REPL
output keeps its own highlighting.

Set to nil to use only the basic REPL font-lock keywords for input."
  :type 'boolean
  :package-version '(fsharp-ts-mode . "0.1.0"))

;;;; REPL prompt

(defconst fsharp-ts-repl--prompt-regexp
  "^> "
  "Regexp matching the F# Interactive prompt.
The default `dotnet fsi' prompt is \"> \".")

;;;; Source buffer tracking

(defvar-local fsharp-ts-repl--source-buffer nil
  "Source buffer from which the REPL was last invoked.
Used by `fsharp-ts-repl-switch-to-source' to return to the source buffer.")

;;;; Per-project REPL buffers
;;
;; Each project gets its own dedicated REPL, so source files send to the
;; toplevel for their project.  The buffer name is derived from
;; `fsharp-ts-repl-buffer-name' plus the project identifier; buffers outside
;; any project share the base name.

(defun fsharp-ts-repl--project-id ()
  "Return a short identifier for the current buffer's project, or nil.
Uses `project.el' when available, falling back to the directory that
contains an F# solution or project file."
  (when-let* ((root (or (and (fboundp 'project-current)
                             (when-let* ((proj (project-current)))
                               (project-root proj)))
                        (locate-dominating-file
                         default-directory
                         (lambda (d)
                           (directory-files d nil "\\.\\(slnx?\\|fsproj\\)\\'" t))))))
    (file-name-nondirectory (directory-file-name root))))

(defun fsharp-ts-repl--buffer ()
  "Return the name of the REPL buffer for the current context.
In a REPL buffer, that is the buffer itself.  In a source buffer, it is
the per-project REPL derived from `fsharp-ts-repl-buffer-name' and the
project identifier (or the base name when there is no project)."
  (cond
   ((derived-mode-p 'fsharp-ts-repl-mode) (buffer-name))
   ((fsharp-ts-repl--project-id)
    (let ((base (if (string-suffix-p "*" fsharp-ts-repl-buffer-name)
                    (substring fsharp-ts-repl-buffer-name 0 -1)
                  fsharp-ts-repl-buffer-name)))
      (format "%s: %s*" base (fsharp-ts-repl--project-id))))
   (t fsharp-ts-repl-buffer-name)))

(defvar-local fsharp-ts-repl--flavor nil
  "The flavor (toplevel kind) of this REPL buffer.
One of the symbols accepted by `fsharp-ts-repl-flavor'.")

(defvar-local fsharp-ts-repl--command-line nil
  "The (PROGRAM . ARGS) this REPL buffer was started with.
Recorded so `fsharp-ts-repl-restart' can relaunch the same toplevel.")

(defun fsharp-ts-repl--command ()
  "Return (PROGRAM . ARGS) for the current `fsharp-ts-repl-flavor'.
The `dotnet' flavor uses `fsharp-ts-repl-program-name' and
`fsharp-ts-repl-program-args'; `fsharpi' uses the standalone toplevel."
  (pcase fsharp-ts-repl-flavor
    ('fsharpi (cons "fsharpi" nil))
    (_ (cons fsharp-ts-repl-program-name fsharp-ts-repl-program-args))))

(defun fsharp-ts-repl--start-command (bufname command flavor)
  "Start a REPL in BUFNAME running COMMAND for FLAVOR, and return the buffer.
COMMAND is a (PROGRAM . ARGS) pair.  Records FLAVOR and COMMAND
buffer-locally so the REPL can be restarted as the same toplevel."
  (let ((buffer (apply #'make-comint-in-buffer "F# Interactive" bufname
                       (car command) nil (cdr command))))
    (with-current-buffer buffer
      (fsharp-ts-repl-mode)
      (setq fsharp-ts-repl--flavor flavor)
      (setq fsharp-ts-repl--command-line command)
      (setq mode-name (format "F#-REPL[%s]" flavor)))
    buffer))

(defun fsharp-ts-repl--kill (bufname)
  "Kill the REPL process running in BUFNAME, if any."
  (when (comint-check-proc bufname)
    (let ((proc (get-buffer-process bufname)))
      (when proc
        (set-process-query-on-exit-flag proc nil)
        (delete-process proc)))))

;;;; REPL mode

(defvar fsharp-ts-repl-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map comint-mode-map)
    (define-key map (kbd "C-c C-z") #'fsharp-ts-repl-switch-to-source)
    (easy-menu-define fsharp-ts-repl-mode-menu map "F# REPL Menu"
      '("F# REPL"
        ["Switch to Source" fsharp-ts-repl-switch-to-source
         :help "Switch back to the source buffer that last invoked the REPL"]
        "--"
        ["Interrupt" fsharp-ts-repl-interrupt
         :help "Interrupt the F# Interactive process"]
        ["Restart" fsharp-ts-repl-restart
         :help "Kill and restart F# Interactive"]
        ["Clear Buffer" fsharp-ts-repl-clear-buffer
         :help "Erase the REPL buffer contents"]
        "--"
        ["Customize F# REPL..." (customize-group 'fsharp-ts-repl)
         :help "Customize the F# REPL settings"]))
    map)
  "Keymap for `fsharp-ts-repl-mode'.")

(defvar fsharp-ts-repl-font-lock-keywords
  `(;; Errors
    ("^\\(.+?\\)(\\([0-9]+\\),\\([0-9]+\\)): error .+" (1 'compilation-error) (2 'compilation-line-number) (3 'compilation-column-number))
    ("^\\(.+?\\)(\\([0-9]+\\),\\([0-9]+\\)): warning .+" (1 'compilation-warning) (2 'compilation-line-number) (3 'compilation-column-number))
    ;; val bindings in output
    ("^\\(val\\) \\([^ :]+\\) *:" (1 font-lock-keyword-face) (2 font-lock-variable-name-face))
    ;; type results
    ("^\\(type\\) \\([^ =]+\\)" (1 font-lock-keyword-face) (2 font-lock-type-face))
    ;; module results
    ("^\\(module\\) \\([^ =]+\\)" (1 font-lock-keyword-face) (2 font-lock-type-face))
    ;; exception results
    ("^\\(exception\\) \\([^ ]+\\)" (1 font-lock-keyword-face) (2 font-lock-type-face))
    ;; prompt
    (,fsharp-ts-repl--prompt-regexp . font-lock-comment-face))
  "Font-lock keywords for the F# Interactive REPL buffer.
Highlights prompts, errors, warnings, and toplevel response values.")

(define-derived-mode fsharp-ts-repl-mode comint-mode "F#-REPL"
  "Major mode for interacting with F# Interactive.

\\{fsharp-ts-repl-mode-map}"
  (setq comint-prompt-regexp fsharp-ts-repl--prompt-regexp)
  (setq comint-prompt-read-only t)
  (setq comint-input-sender #'fsharp-ts-repl--input-sender)
  (setq comint-process-echoes nil)
  ;; Strip ANSI escape sequences
  (ansi-color-for-comint-mode-on)
  ;; Comment settings for the REPL buffer
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local font-lock-defaults '(fsharp-ts-repl-font-lock-keywords t))

  ;; Input history persistence
  (when fsharp-ts-repl-history-file
    (setq comint-input-ring-file-name fsharp-ts-repl-history-file)
    (setq comint-input-ring-size fsharp-ts-repl-history-size)
    (setq comint-input-ignoredups t)
    (comint-read-input-ring t)
    (add-hook 'kill-buffer-hook #'comint-write-input-ring nil t))

  ;; Prettify symbols
  (setq-local prettify-symbols-alist fsharp-ts-mode-prettify-symbols-alist)

  ;; Tree-sitter fontification for REPL input
  (when fsharp-ts-repl-fontify-input
    (setq-local comint-indirect-setup-function #'fsharp-ts-mode)
    (comint-fontify-input-mode)))

;;;; Input handling

(defun fsharp-ts-repl--input-sender (proc input)
  "Send INPUT to PROC, appending `;;' terminator if missing.
F# Interactive requires `;;' to terminate an expression.  Only checks
the end of input (ignoring trailing whitespace) to avoid false positives
from `;;' inside strings."
  (let* ((trimmed (string-trim-right input))
         (terminated (string-suffix-p ";;" trimmed)))
    (comint-send-string proc (if terminated
                                 (concat input "\n")
                               (concat input ";;\n")))))

;;;; Starting and switching

;;;###autoload
(defun fsharp-ts-repl-start ()
  "Start an F# Interactive process for the current buffer's project.
If a REPL for the project is already running, switch to its buffer."
  (interactive)
  (let ((bufname (fsharp-ts-repl--buffer)))
    (if (comint-check-proc bufname)
        (pop-to-buffer bufname)
      (pop-to-buffer
       (fsharp-ts-repl--start-command bufname (fsharp-ts-repl--command)
                                      fsharp-ts-repl-flavor)))))

(defun fsharp-ts-repl-switch-to-source ()
  "Switch from the REPL back to the source buffer that last invoked it."
  (interactive)
  (if (and fsharp-ts-repl--source-buffer
           (buffer-live-p fsharp-ts-repl--source-buffer))
      (pop-to-buffer fsharp-ts-repl--source-buffer)
    (message "No source buffer to return to")))

;;;###autoload
(defun fsharp-ts-repl-switch-to-repl ()
  "Switch to the F# REPL, saving the current buffer as the source.
If a REPL is already running, switch to it; otherwise start a new one.
Use \\[fsharp-ts-repl-switch-to-source] in the REPL to return."
  (interactive)
  (let* ((source (current-buffer))
         (bufname (fsharp-ts-repl--buffer))
         (running (comint-check-proc bufname))
         (running-flavor (and running
                              (buffer-local-value 'fsharp-ts-repl--flavor
                                                  (get-buffer bufname)))))
    (cond
     ;; A REPL with a different toplevel is running; offer to restart it with
     ;; the requested flavor (this is how a changed `fsharp-ts-repl-flavor'
     ;; takes effect).
     ((and running (not (eq running-flavor fsharp-ts-repl-flavor))
           (y-or-n-p (format "An existing %s REPL is running for this project; \
restart it as %s? " running-flavor fsharp-ts-repl-flavor)))
      (fsharp-ts-repl--kill bufname)
      (fsharp-ts-repl-start))
     (running (pop-to-buffer bufname))
     (t (fsharp-ts-repl-start)))
    (with-current-buffer bufname
      (setq fsharp-ts-repl--source-buffer source))))

;;;; Sending code

(defun fsharp-ts-repl--process ()
  "Return the REPL process for the current context, or nil if not running."
  (get-buffer-process (fsharp-ts-repl--buffer)))

(defun fsharp-ts-repl--ensure-running ()
  "Start an F# REPL for the current buffer's project if one is not running."
  (unless (comint-check-proc (fsharp-ts-repl--buffer))
    (save-window-excursion
      (fsharp-ts-repl-start))))

;;;###autoload
(defun fsharp-ts-repl-send-region (start end)
  "Send the region between START and END to the F# REPL."
  (interactive "r")
  (let ((text (buffer-substring-no-properties start end)))
    (fsharp-ts-repl--ensure-running)
    (fsharp-ts-repl--input-sender (fsharp-ts-repl--process) text)
    (pulse-momentary-highlight-region start end)))

;;;###autoload
(defun fsharp-ts-repl-send-buffer ()
  "Send the entire buffer to the F# REPL."
  (interactive)
  (fsharp-ts-repl-send-region (point-min) (point-max)))

;;;###autoload
(defun fsharp-ts-repl-send-definition ()
  "Send the current definition to the F# REPL."
  (interactive)
  (if-let* ((node (treesit-defun-at-point))
            (start (treesit-node-start node))
            (end (treesit-node-end node)))
      (fsharp-ts-repl-send-region start end)
    (user-error "No definition at point")))

;;;###autoload
(defun fsharp-ts-repl-load-file (file)
  "Load FILE into the F# REPL via the `#load' directive."
  (interactive (list (buffer-file-name)))
  (unless file
    (user-error "Buffer is not visiting a file"))
  (fsharp-ts-repl--ensure-running)
  (fsharp-ts-repl--input-sender (fsharp-ts-repl--process)
                                 (format "#load %S" file)))

;;;; Project references

(defvar fsharp-ts-repl--excluded-references
  '("FSharp.Core" "mscorlib" "System.Private.CoreLib" "netstandard")
  "Assembly names to exclude from #r directives (FSI loads these itself).")

(defun fsharp-ts-repl--find-fsproj ()
  "Find the .fsproj for the current buffer."
  (when-let* ((file (buffer-file-name))
              (dir (file-name-directory file))
              (proj-dir (locate-dominating-file
                         dir (lambda (d)
                               (directory-files d nil "\\.fsproj\\'" t)))))
    (car (directory-files proj-dir t "\\.fsproj\\'"))))

(defun fsharp-ts-repl--msbuild-get-items (fsproj target item)
  "Run `dotnet msbuild' on FSPROJ with TARGET and return ITEM entries.
Each entry is an alist parsed from the JSON output.  Returns nil on failure."
  (let* ((cmd (format "dotnet msbuild %s %s -getItem:%s"
                      (shell-quote-argument fsproj)
                      (if target (format "-t:%s" target) "")
                      item))
         (output (shell-command-to-string cmd)))
    (condition-case nil
        (let* ((json-object-type 'alist)
               (json-array-type 'list)
               (parsed (json-read-from-string output))
               (items (alist-get 'Items parsed)))
          (alist-get (intern item) items))
      (error nil))))

(defun fsharp-ts-repl--resolve-via-fsac (fsproj)
  "Try to get project data for FSPROJ from FsAutoComplete via eglot.
Returns a plist (:references REFS :sources SOURCES) or nil if FSAC
is not available or doesn't have project data."
  (condition-case nil
      (when (and (fboundp 'eglot-current-server) (eglot-current-server))
        (let* ((params (list :Project (list :uri (concat "file://" fsproj))))
               (result (jsonrpc-request (eglot-current-server)
                                        :fsharp/project params
                                        :timeout 5)))
          (when result
            (let* ((refs (mapcar (lambda (r) (if (stringp r) r (alist-get 'FullPath r)))
                                 (append (alist-get 'References result) nil)))
                   (sources (mapcar (lambda (s) (if (stringp s) s (alist-get 'FullPath s)))
                                    (append (alist-get 'Files result) nil)))
                   (filtered-refs
                    (seq-filter (lambda (path)
                                  (not (seq-some
                                        (lambda (excl)
                                          (string-match-p (regexp-quote excl) path))
                                        fsharp-ts-repl--excluded-references)))
                                refs)))
              (when (or filtered-refs sources)
                (list :references filtered-refs :sources sources))))))
    (error nil)))

(defun fsharp-ts-repl--resolve-via-msbuild (fsproj)
  "Resolve references and source files for FSPROJ via dotnet msbuild.
Returns a plist (:references REFS :sources SOURCES)."
  (message "Resolving project references via dotnet msbuild...")
  (let* ((ref-items (fsharp-ts-repl--msbuild-get-items
                     fsproj "ResolveAssemblyReferences" "ReferencePath"))
         (src-items (fsharp-ts-repl--msbuild-get-items fsproj nil "Compile"))
         (refs (delq nil
                     (mapcar (lambda (item)
                               (let ((path (alist-get 'FullPath item))
                                     (name (alist-get 'Filename item)))
                                 (when (and path
                                            (not (member name
                                                         fsharp-ts-repl--excluded-references)))
                                   path)))
                             ref-items)))
         (sources (delq nil
                        (mapcar (lambda (item) (alist-get 'FullPath item))
                                src-items))))
    (list :references refs :sources sources)))

(defun fsharp-ts-repl--resolve-project-refs (fsproj)
  "Resolve references and source files for FSPROJ.
Tries FsAutoComplete via eglot first (instant if available), then
falls back to `dotnet msbuild' (slower but works without LSP).
Returns a plist (:references REFS :sources SOURCES)."
  (message "Resolving project references for %s..." (file-name-nondirectory fsproj))
  (or (fsharp-ts-repl--resolve-via-fsac fsproj)
      (fsharp-ts-repl--resolve-via-msbuild fsproj)))

(defun fsharp-ts-repl--format-directives (project-data)
  "Format PROJECT-DATA as FSI #r and #load directives."
  (let ((refs (plist-get project-data :references))
        (sources (plist-get project-data :sources)))
    (concat
     (when refs
       (concat "// Assembly references\n"
               (mapconcat (lambda (r) (format "#r @\"%s\"" r)) refs "\n")
               "\n\n"))
     (when sources
       (concat "// Source files\n"
               (mapconcat (lambda (s) (format "#load @\"%s\"" s)) sources "\n")
               "\n")))))

;;;###autoload
(defun fsharp-ts-repl-send-project-references ()
  "Send the current project's references and source files to the REPL.
Resolves assembly references and source files from the nearest `.fsproj'
via `dotnet msbuild', then sends `#r' and `#load' directives to FSI."
  (interactive)
  (let* ((fsproj (or (fsharp-ts-repl--find-fsproj)
                     (user-error "No .fsproj found for current buffer")))
         (data (fsharp-ts-repl--resolve-project-refs fsproj))
         (directives (fsharp-ts-repl--format-directives data))
         (ref-count (length (plist-get data :references)))
         (src-count (length (plist-get data :sources))))
    (when (string-empty-p directives)
      (user-error "No references or sources found in %s" fsproj))
    (fsharp-ts-repl--ensure-running)
    (let ((proc (fsharp-ts-repl--process)))
      ;; Send each directive individually to avoid overwhelming FSI
      (dolist (line (split-string directives "\n" t))
        (unless (string-prefix-p "//" line)
          (comint-send-string proc (concat line "\n"))))
      (comint-send-string proc ";;\n"))
    (message "Sent %d references and %d source files to FSI" ref-count src-count)))

;;;###autoload
(defun fsharp-ts-repl-generate-references-file ()
  "Generate a references.fsx buffer with #r and #load directives.
Resolves assembly references and source files from the nearest `.fsproj'
via `dotnet msbuild'."
  (interactive)
  (let* ((fsproj (or (fsharp-ts-repl--find-fsproj)
                     (user-error "No .fsproj found for current buffer")))
         (data (fsharp-ts-repl--resolve-project-refs fsproj))
         (directives (fsharp-ts-repl--format-directives data))
         (buf-name (format "*%s-references.fsx*"
                           (file-name-sans-extension
                            (file-name-nondirectory fsproj)))))
    (when (string-empty-p directives)
      (user-error "No references or sources found in %s" fsproj))
    (with-current-buffer (get-buffer-create buf-name)
      (erase-buffer)
      (insert (format "// Generated from %s\n\n" fsproj))
      (insert directives)
      (fsharp-ts-mode)
      (goto-char (point-min)))
    (pop-to-buffer buf-name)))

;;;; REPL management

(defun fsharp-ts-repl-clear-buffer ()
  "Clear the F# REPL buffer for the current context."
  (interactive)
  (with-current-buffer (fsharp-ts-repl--buffer)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (comint-send-input))))

(defun fsharp-ts-repl-interrupt ()
  "Interrupt the F# REPL process for the current context."
  (interactive)
  (when (comint-check-proc (fsharp-ts-repl--buffer))
    (interrupt-process (fsharp-ts-repl--process))))

;;;###autoload
(defun fsharp-ts-repl-restart ()
  "Restart F# Interactive for the current buffer's project.
Kill the running process, if any, and start a fresh one in the same
buffer, preserving the toplevel flavor it was launched with."
  (interactive)
  (let* ((bufname (fsharp-ts-repl--buffer))
         (buf (get-buffer bufname))
         (flavor (and buf (buffer-local-value 'fsharp-ts-repl--flavor buf)))
         (command (and buf (buffer-local-value 'fsharp-ts-repl--command-line buf))))
    (fsharp-ts-repl--kill bufname)
    (if (and command flavor)
        (pop-to-buffer (fsharp-ts-repl--start-command bufname command flavor))
      (fsharp-ts-repl-start))))

;;;; Minor mode for source buffers

(defvar fsharp-ts-repl-minor-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-z") #'fsharp-ts-repl-switch-to-repl)
    (define-key map (kbd "C-c C-c") #'fsharp-ts-repl-send-definition)
    (define-key map (kbd "C-c C-r") #'fsharp-ts-repl-send-region)
    (define-key map (kbd "C-c C-b") #'fsharp-ts-repl-send-buffer)
    (define-key map (kbd "C-c C-l") #'fsharp-ts-repl-load-file)
    (define-key map (kbd "C-c C-p") #'fsharp-ts-repl-send-project-references)
    (define-key map (kbd "C-c C-i") #'fsharp-ts-repl-interrupt)
    (define-key map (kbd "C-c C-k") #'fsharp-ts-repl-clear-buffer)

    (easy-menu-define fsharp-ts-repl-minor-mode-menu map "F# REPL Menu"
      '("F# REPL"
        ["Start/Switch to REPL" fsharp-ts-repl-switch-to-repl]
        "--"
        ["Send Definition" fsharp-ts-repl-send-definition]
        ["Send Region" fsharp-ts-repl-send-region]
        ["Send Buffer" fsharp-ts-repl-send-buffer]
        ["Load File" fsharp-ts-repl-load-file]
        ["Send Project References" fsharp-ts-repl-send-project-references]
        ["Generate References File" fsharp-ts-repl-generate-references-file]
        "--"
        ["Interrupt REPL" fsharp-ts-repl-interrupt
         :enable (comint-check-proc (fsharp-ts-repl--buffer))]
        ["Restart REPL" fsharp-ts-repl-restart]
        ["Clear REPL Buffer" fsharp-ts-repl-clear-buffer
         :enable (comint-check-proc (fsharp-ts-repl--buffer))]))
    map)
  "Keymap for F# Interactive source buffer integration.")

;;;###autoload
(define-minor-mode fsharp-ts-repl-minor-mode
  "Minor mode for interacting with F# Interactive from source buffers.

\\{fsharp-ts-repl-minor-mode-map}"
  :init-value nil
  :lighter " FSI"
  :keymap fsharp-ts-repl-minor-mode-map
  :group 'fsharp-ts-repl)

(provide 'fsharp-ts-repl)

;;; fsharp-ts-repl.el ends here
