;;; fsharp-ts-info.el --- F# documentation info panel -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov
;;
;; Author: Bozhidar Batsov <bozhidar@batsov.dev>

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Provides a persistent documentation panel for F# that shows rich
;; type information for the symbol at point.  Updated automatically
;; on cursor movement (with debounce) or on demand.
;;
;; Requires an active eglot connection to FsAutoComplete, which
;; provides the `fsharp/documentation' custom LSP endpoint.
;;
;; Usage:
;;
;;   (require 'fsharp-ts-info)
;;   ;; Then: M-x fsharp-ts-info-show
;;   ;; Or enable auto-update: M-x fsharp-ts-info-mode

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

(defgroup fsharp-ts-info nil
  "F# documentation info panel."
  :prefix "fsharp-ts-info-"
  :group 'fsharp-ts)

(defcustom fsharp-ts-info-buffer-name "*F# Documentation*"
  "Name of the F# documentation info panel buffer."
  :type 'string
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defcustom fsharp-ts-info-idle-delay 0.5
  "Seconds of idle time before auto-updating the info panel."
  :type 'number
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defvar fsharp-ts-info--idle-timer nil
  "Idle timer for auto-updating the info panel.")

(defvar fsharp-ts-info--last-position nil
  "Last position for which documentation was fetched.
A cons of (BUFFER . POINT) to avoid redundant requests.")

;;;; Rendering

(defun fsharp-ts-info--render-section (heading items)
  "Render a section with HEADING and ITEMS list.
ITEMS are filtered to remove empty strings and compiler-generated names."
  (let ((filtered (seq-filter
                   (lambda (s)
                     (and (stringp s)
                          (not (string-blank-p s))
                          (not (string-prefix-p "<" s))
                          (not (string-match-p "@" s))))
                   (append items nil))))
    (when filtered
      (concat heading "\n"
              (mapconcat #'identity filtered "\n")
              "\n\n"))))

(defun fsharp-ts-info--render (data)
  "Render documentation DATA into a formatted string.
DATA is an alist from the `fsharp/documentation' response."
  (let ((signature (alist-get 'Signature data))
        (comment (alist-get 'Comment data))
        (footer (alist-get 'FooterLines data))
        (constructors (alist-get 'Constructors data))
        (fields (alist-get 'Fields data))
        (functions (alist-get 'Functions data))
        (interfaces (alist-get 'Interfaces data))
        (attributes (alist-get 'Attributes data))
        (declared-types (alist-get 'DeclaredTypes data)))
    (concat
     ;; Signature
     (when (and signature (not (string-empty-p signature)))
       (concat (propertize signature 'face 'font-lock-function-name-face) "\n\n"))
     ;; Documentation comment
     (when (and comment (not (string-empty-p comment)))
       (concat comment "\n\n"))
     ;; Sections
     (fsharp-ts-info--render-section "Declared Types:" declared-types)
     (fsharp-ts-info--render-section "Attributes:" attributes)
     (fsharp-ts-info--render-section "Interfaces:" interfaces)
     (fsharp-ts-info--render-section "Constructors:" constructors)
     (fsharp-ts-info--render-section "Functions:" functions)
     (fsharp-ts-info--render-section "Fields:" fields)
     ;; Footer
     (when footer
       (let ((lines (seq-filter (lambda (s) (and (stringp s) (not (string-blank-p s))))
                                (append footer nil))))
         (when lines
           (concat (mapconcat #'identity lines "\n") "\n")))))))

;;;; Fetching

(defun fsharp-ts-info--fetch ()
  "Fetch documentation for the symbol at point from FsAutoComplete.
Returns the rendered documentation string, or nil."
  (condition-case nil
      (when-let* ((server (eglot-current-server)))
        (let* ((params (eglot--TextDocumentPositionParams))
               (result (jsonrpc-request server :fsharp/documentation params
                                        :timeout 2)))
          (when result
            (let ((data (alist-get 'Data result)))
              (when data
                (fsharp-ts-info--render data))))))
    (error nil)))

;;;; Display

(defun fsharp-ts-info--update ()
  "Update the info panel if point has moved to a new symbol."
  (when (and (derived-mode-p 'fsharp-ts-mode 'fsharp-ts-signature-mode)
             (eglot-current-server)
             (get-buffer-window fsharp-ts-info-buffer-name))
    (let ((current-pos (cons (current-buffer) (point))))
      (unless (equal current-pos fsharp-ts-info--last-position)
        (setq fsharp-ts-info--last-position current-pos)
        (when-let* ((content (fsharp-ts-info--fetch)))
          (with-current-buffer (get-buffer-create fsharp-ts-info-buffer-name)
            (let ((inhibit-read-only t))
              (erase-buffer)
              (insert content)
              (goto-char (point-min)))))))))

;;;###autoload
(defun fsharp-ts-info-show ()
  "Show the F# documentation panel for the symbol at point.
The panel is displayed in a side window and can be kept visible
while navigating code."
  (interactive)
  (unless (eglot-current-server)
    (user-error "No eglot server active -- start one with M-x eglot"))
  (let ((content (fsharp-ts-info--fetch)))
    (if content
        (progn
          (with-current-buffer (get-buffer-create fsharp-ts-info-buffer-name)
            (let ((inhibit-read-only t))
              (erase-buffer)
              (insert content)
              (goto-char (point-min))
              (special-mode)))
          (display-buffer fsharp-ts-info-buffer-name
                          '(display-buffer-in-side-window
                            (side . right)
                            (window-width . 0.4))))
      (message "No documentation available at point"))))

;;;; Minor mode for auto-update

;;;###autoload
(define-minor-mode fsharp-ts-info-mode
  "Minor mode that auto-updates the F# documentation panel on cursor movement.

When enabled, the info panel is updated after `fsharp-ts-info-idle-delay'
seconds of idle time whenever point moves to a new position.  The panel
must be visible (use `fsharp-ts-info-show' to open it first)."
  :lighter " F#-Info"
  (if fsharp-ts-info-mode
      (setq fsharp-ts-info--idle-timer
            (run-with-idle-timer fsharp-ts-info-idle-delay t
                                #'fsharp-ts-info--update))
    (when fsharp-ts-info--idle-timer
      (cancel-timer fsharp-ts-info--idle-timer)
      (setq fsharp-ts-info--idle-timer nil)
      (setq fsharp-ts-info--last-position nil))))

(provide 'fsharp-ts-info)

;;; fsharp-ts-info.el ends here
