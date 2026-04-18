;;; fsharp-ts-lens.el --- Type signature overlays for F# -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov
;;
;; Author: Bozhidar Batsov <bozhidar@batsov.dev>

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Displays inferred type signatures as overlays after function
;; definitions, similar to Ionide's LineLens feature.  Requires
;; an active eglot connection to FsAutoComplete.
;;
;; Usage:
;;
;;   (require 'fsharp-ts-lens)
;;   M-x fsharp-ts-lens-mode

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
(require 'seq)

(defun fsharp-ts-lens--file-uri (file)
  "Return a file URI for FILE.
Uses `eglot-path-to-uri' when available (Emacs 30+), otherwise
constructs the URI directly."
  (if (fboundp 'eglot-path-to-uri)
      (eglot-path-to-uri file)
    (concat "file://" (expand-file-name file))))

(defgroup fsharp-ts-lens nil
  "Type signature overlays for F#."
  :prefix "fsharp-ts-lens-"
  :group 'fsharp-ts)

(defcustom fsharp-ts-lens-prefix " // "
  "String prepended to signature overlays."
  :type 'string
  :package-version '(fsharp-ts-mode . "0.1.0"))

(defface fsharp-ts-lens-face
  '((t :inherit font-lock-comment-face))
  "Face for type signature overlays."
  :package-version '(fsharp-ts-mode . "0.1.0"))

;;;; Overlay management

(defvar-local fsharp-ts-lens--overlays nil
  "List of active lens overlays in the current buffer.")

(defun fsharp-ts-lens--clear ()
  "Remove all lens overlays from the current buffer."
  (mapc #'delete-overlay fsharp-ts-lens--overlays)
  (setq fsharp-ts-lens--overlays nil))

(defun fsharp-ts-lens--add-overlay (line signature)
  "Add a signature overlay at the end of LINE showing SIGNATURE."
  (save-excursion
    (goto-char (point-min))
    (forward-line (1- line))
    (let* ((eol (line-end-position))
           (ov (make-overlay eol eol nil t t))
           (text (propertize (concat fsharp-ts-lens-prefix signature)
                             'face 'fsharp-ts-lens-face)))
      (overlay-put ov 'after-string text)
      (overlay-put ov 'fsharp-ts-lens t)
      (push ov fsharp-ts-lens--overlays))))

;;;; Symbol filtering

(defconst fsharp-ts-lens--interesting-glyphs '("Fc" "M" "F" "P")
  "GlyphChar values for symbols that should show signatures.
Fc = function/value, M = method, F = field, P = property.")

(defconst fsharp-ts-lens--skip-enclosing '("I" "R" "D" "En" "E")
  "EnclosingEntity values to skip.
I = interface, R = record, D = DU, En = enum, E = exception.")

(defun fsharp-ts-lens--interesting-p (symbol)
  "Return non-nil if SYMBOL should get a signature overlay."
  (let ((glyph (alist-get 'GlyphChar symbol))
        (enclosing (alist-get 'EnclosingEntity symbol))
        (is-abstract (alist-get 'IsAbstract symbol)))
    (and (member glyph fsharp-ts-lens--interesting-glyphs)
         (not is-abstract)
         (not (member enclosing fsharp-ts-lens--skip-enclosing)))))

(defun fsharp-ts-lens--collect-positions (response)
  "Extract interesting symbol positions from a lineLens RESPONSE.
Returns a list of (LINE . COLUMN) conses."
  (let ((positions nil)
        (seen-lines (make-hash-table)))
    (dolist (group (append response nil))
      (let ((decl (alist-get 'Declaration group))
            (nested (alist-get 'Nested group)))
        ;; Top-level declarations
        (when (and decl
                   (equal (alist-get 'GlyphChar decl) "Fc")
                   (alist-get 'IsTopLevel decl))
          (let* ((body (alist-get 'BodyRange decl))
                 (start (alist-get 'Start body))
                 (line (1+ (alist-get 'Line start)))
                 (col (alist-get 'Column start)))
            (unless (gethash line seen-lines)
              (puthash line t seen-lines)
              (push (cons line col) positions))))
        ;; Nested symbols
        (dolist (sym (append nested nil))
          (when (fsharp-ts-lens--interesting-p sym)
            (let* ((body (alist-get 'BodyRange sym))
                   (start (alist-get 'Start body))
                   (line (1+ (alist-get 'Line start)))
                   (col (alist-get 'Column start)))
              (unless (gethash line seen-lines)
                (puthash line t seen-lines)
                (push (cons line col) positions)))))))
    (nreverse positions)))

;;;; Fetching

(defun fsharp-ts-lens--fetch-symbols ()
  "Fetch lineLens data for the current buffer from FSAC."
  (condition-case nil
      (when-let* ((server (eglot-current-server))
                  (uri (fsharp-ts-lens--file-uri (buffer-file-name))))
        (let ((result (jsonrpc-request
                       server :fsharp/lineLens
                       (list :Project (list :uri uri))
                       :timeout 10)))
          (alist-get 'Data result)))
    (error nil)))

(defun fsharp-ts-lens--fetch-signature (line column)
  "Fetch the signature string at LINE and COLUMN from FSAC."
  (condition-case nil
      (when-let* ((server (eglot-current-server))
                  (uri (fsharp-ts-lens--file-uri (buffer-file-name))))
        (let ((result (jsonrpc-request
                       server :fsharp/signature
                       (list :textDocument (list :uri uri)
                             :position (list :line (1- line)
                                             :character column))
                       :timeout 2)))
          (when (and result (stringp result) (not (string-empty-p result)))
            result)))
    (error nil)))

;;;; Refresh

(defun fsharp-ts-lens-refresh ()
  "Refresh type signature overlays in the current buffer."
  (interactive)
  (unless (eglot-current-server)
    (when (called-interactively-p 'interactive)
      (user-error "No eglot server active")))
  (fsharp-ts-lens--clear)
  (when-let* ((symbols (fsharp-ts-lens--fetch-symbols))
              (positions (fsharp-ts-lens--collect-positions symbols)))
    (dolist (pos positions)
      (when-let* ((sig (fsharp-ts-lens--fetch-signature (car pos) (cdr pos))))
        (fsharp-ts-lens--add-overlay (car pos) sig)))
    (when (called-interactively-p 'interactive)
      (message "Showing %d type signatures" (length fsharp-ts-lens--overlays)))))

;;;; Minor mode

(defvar fsharp-ts-lens--after-save-hook nil
  "Whether the after-save hook is installed.")

;;;###autoload
(define-minor-mode fsharp-ts-lens-mode
  "Minor mode showing type signatures as overlays after definitions.

Overlays are refreshed when the file is saved and when the mode
is activated.  Use `fsharp-ts-lens-refresh' to update manually.

Requires an active eglot connection to FsAutoComplete."
  :lighter " F#-Lens"
  (if fsharp-ts-lens-mode
      (progn
        (add-hook 'after-save-hook #'fsharp-ts-lens-refresh nil t)
        (when (eglot-current-server)
          (fsharp-ts-lens-refresh)))
    (remove-hook 'after-save-hook #'fsharp-ts-lens-refresh t)
    (fsharp-ts-lens--clear)))

(provide 'fsharp-ts-lens)

;;; fsharp-ts-lens.el ends here
