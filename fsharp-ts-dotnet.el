;;; fsharp-ts-dotnet.el --- dotnet CLI interaction for fsharp-ts-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov
;;
;; Author: Bozhidar Batsov <bozhidar@batsov.dev>

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Minor mode for running dotnet CLI commands from fsharp-ts-mode buffers.
;; Provides keybindings for common dotnet operations (build, test, run,
;; clean, format, restore) and navigation to project files.

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

(require 'cl-lib)

(defgroup fsharp-ts-dotnet nil
  "dotnet CLI interaction for fsharp-ts-mode."
  :prefix "fsharp-ts-dotnet-"
  :group 'fsharp-ts
  :link '(url-link :tag "GitHub" "https://github.com/bbatsov/fsharp-ts-mode"))

(defcustom fsharp-ts-dotnet-program "dotnet"
  "The dotnet CLI executable."
  :type 'string
  :safe #'stringp
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-dotnet-project-root-files
  '("*.sln" "*.fsproj" "Directory.Build.props")
  "Glob patterns for files that indicate a dotnet project root.
The first ancestor directory containing any matching file is used
as the project root for dotnet commands."
  :type '(repeat string)
  :package-version '(fsharp-ts-mode . "0.1.0"))

;;;; Project root detection

(defun fsharp-ts-dotnet--project-root ()
  "Find the dotnet project root by walking up from the current directory.
Returns the directory containing a `.sln', `.fsproj', or
`Directory.Build.props' file, or signals an error if none is found."
  (or (fsharp-ts-dotnet--locate-project-root default-directory)
      (error "Not inside a dotnet project (no .sln, .fsproj, or Directory.Build.props found)")))

(defun fsharp-ts-dotnet--locate-project-root (dir)
  "Find the nearest ancestor of DIR containing a dotnet project file."
  (cl-some (lambda (pattern)
             (when-let* ((found (locate-dominating-file
                                 dir
                                 (lambda (d)
                                   (directory-files d nil (wildcard-to-regexp pattern) t)))))
               (file-name-as-directory (expand-file-name found))))
           fsharp-ts-dotnet-project-root-files))

;;;; Running dotnet commands

(defun fsharp-ts-dotnet--run (command &rest args)
  "Run a dotnet COMMAND with ARGS via `compile' in the project root.
When called with a prefix argument, uses `dotnet watch' instead of
`dotnet', enabling automatic rebuild on file changes."
  (let* ((watch current-prefix-arg)
         (default-directory (fsharp-ts-dotnet--project-root))
         (cmd (concat (shell-quote-argument fsharp-ts-dotnet-program)
                      (if watch " watch " " ")
                      (mapconcat #'shell-quote-argument
                                 (cons command args) " "))))
    (compile cmd (and watch t))))

(defun fsharp-ts-dotnet--run-no-watch (command &rest args)
  "Run a dotnet COMMAND with ARGS via `compile' in the project root.
Like `fsharp-ts-dotnet--run' but ignores the prefix argument."
  (let ((current-prefix-arg nil))
    (apply #'fsharp-ts-dotnet--run command args)))

;;;###autoload
(defun fsharp-ts-dotnet-build ()
  "Run `dotnet build' in the project root.
With prefix argument, run `dotnet watch build'."
  (interactive)
  (fsharp-ts-dotnet--run "build"))

;;;###autoload
(defun fsharp-ts-dotnet-test ()
  "Run `dotnet test' in the project root.
With prefix argument, run `dotnet watch test'."
  (interactive)
  (fsharp-ts-dotnet--run "test"))

;;;###autoload
(defun fsharp-ts-dotnet-run ()
  "Run `dotnet run' in the project root.
With prefix argument, run `dotnet watch run'."
  (interactive)
  (fsharp-ts-dotnet--run "run"))

;;;###autoload
(defun fsharp-ts-dotnet-clean ()
  "Run `dotnet clean' in the project root."
  (interactive)
  (fsharp-ts-dotnet--run-no-watch "clean"))

;;;###autoload
(defun fsharp-ts-dotnet-restore ()
  "Run `dotnet restore' in the project root."
  (interactive)
  (fsharp-ts-dotnet--run-no-watch "restore"))

;;;###autoload
(defun fsharp-ts-dotnet-format ()
  "Run `dotnet format' in the project root."
  (interactive)
  (fsharp-ts-dotnet--run-no-watch "format"))

(defvar fsharp-ts-dotnet--command-history nil
  "History for `fsharp-ts-dotnet-command'.")

;;;###autoload
(defun fsharp-ts-dotnet-command (command)
  "Run an arbitrary dotnet COMMAND in the project root.
Prompts for the full command string (without the `dotnet' prefix).
The command string is passed as-is, not shell-quoted."
  (interactive
   (list (read-string "dotnet command: " nil 'fsharp-ts-dotnet--command-history)))
  (let ((default-directory (fsharp-ts-dotnet--project-root)))
    (compile (concat (shell-quote-argument fsharp-ts-dotnet-program) " " command))))

;;;; Navigation

;;;###autoload
(defun fsharp-ts-dotnet-find-project-file ()
  "Find the nearest `.fsproj' file governing the current directory."
  (interactive)
  (let* ((dir (or (and buffer-file-name
                       (file-name-directory buffer-file-name))
                  default-directory))
         (found (locate-dominating-file
                 dir
                 (lambda (d)
                   (directory-files d nil "\\.fsproj\\'" t)))))
    (if found
        (let ((fsproj (car (directory-files found t "\\.fsproj\\'"))))
          (find-file fsproj))
      (user-error "No .fsproj file found above %s" dir))))

;;;###autoload
(defun fsharp-ts-dotnet-find-solution-file ()
  "Find the nearest `.sln' file governing the current directory."
  (interactive)
  (let* ((dir (or (and buffer-file-name
                       (file-name-directory buffer-file-name))
                  default-directory))
         (found (locate-dominating-file
                 dir
                 (lambda (d)
                   (directory-files d nil "\\.sln\\'" t)))))
    (if found
        (let ((sln (car (directory-files found t "\\.sln\\'"))))
          (find-file sln))
      (user-error "No .sln file found above %s" dir))))

;;;; Minor mode

(defvar fsharp-ts-dotnet-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-d b") #'fsharp-ts-dotnet-build)
    (define-key map (kbd "C-c C-d t") #'fsharp-ts-dotnet-test)
    (define-key map (kbd "C-c C-d r") #'fsharp-ts-dotnet-run)
    (define-key map (kbd "C-c C-d c") #'fsharp-ts-dotnet-clean)
    (define-key map (kbd "C-c C-d R") #'fsharp-ts-dotnet-restore)
    (define-key map (kbd "C-c C-d f") #'fsharp-ts-dotnet-format)
    (define-key map (kbd "C-c C-d d") #'fsharp-ts-dotnet-command)
    (define-key map (kbd "C-c C-d p") #'fsharp-ts-dotnet-find-project-file)
    (define-key map (kbd "C-c C-d s") #'fsharp-ts-dotnet-find-solution-file)
    (easy-menu-define fsharp-ts-dotnet-menu map
      "dotnet CLI interaction menu."
      '("dotnet"
        ["Build" fsharp-ts-dotnet-build]
        ["Test" fsharp-ts-dotnet-test]
        ["Run" fsharp-ts-dotnet-run]
        ["Clean" fsharp-ts-dotnet-clean]
        ["Restore" fsharp-ts-dotnet-restore]
        ["Format" fsharp-ts-dotnet-format]
        "---"
        ("Watch (rebuild on changes)"
         ["Build --watch"
          (let ((current-prefix-arg '(4)))
            (call-interactively #'fsharp-ts-dotnet-build))
          :keys "C-u C-c C-d b"]
         ["Test --watch"
          (let ((current-prefix-arg '(4)))
            (call-interactively #'fsharp-ts-dotnet-test))
          :keys "C-u C-c C-d t"]
         ["Run --watch"
          (let ((current-prefix-arg '(4)))
            (call-interactively #'fsharp-ts-dotnet-run))
          :keys "C-u C-c C-d r"])
        "---"
        ["Find .fsproj" fsharp-ts-dotnet-find-project-file]
        ["Find .sln" fsharp-ts-dotnet-find-solution-file]
        "---"
        ["Run Command..." fsharp-ts-dotnet-command]))
    map)
  "Keymap for `fsharp-ts-dotnet-mode'.")

;;;###autoload
(define-minor-mode fsharp-ts-dotnet-mode
  "Minor mode for running dotnet CLI commands from F# buffers.

Provides keybindings for common dotnet operations:

\\{fsharp-ts-dotnet-mode-map}"
  :lighter " dotnet"
  :keymap fsharp-ts-dotnet-mode-map)

(provide 'fsharp-ts-dotnet)

;;; fsharp-ts-dotnet.el ends here
