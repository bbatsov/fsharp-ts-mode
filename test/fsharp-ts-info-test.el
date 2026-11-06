;;; fsharp-ts-info-test.el --- Tests for fsharp-ts-info -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov

;;; Commentary:

;; Tests for documentation rendering and automatic update lifecycle.

;;; Code:

(require 'cl-lib)
(require 'buttercup)
(require 'fsharp-ts-info)

(describe "fsharp-ts-info"
  (describe "rendering"
    (it "renders signature"
      (let ((data '((Signature . "val add : x:int -> y:int -> int"))))
        (expect (fsharp-ts-info--render data)
                :to-match "val add : x:int -> y:int -> int")))

    (it "renders comment"
      (let ((data '((Signature . "val f : unit -> unit")
                    (Comment . "Does something useful."))))
        (expect (fsharp-ts-info--render data)
                :to-match "Does something useful.")))

    (it "renders constructors section"
      (let ((data '((Signature . "type List<'T>")
                    (Constructors . ["new: unit -> List<'T>"
                                     "new: capacity:int -> List<'T>"]))))
        (let ((output (fsharp-ts-info--render data)))
          (expect output :to-match "Constructors:")
          (expect output :to-match "new: unit -> List<'T>"))))

    (it "renders interfaces section"
      (let ((data '((Signature . "type List<'T>")
                    (Interfaces . ["ICollection<'T>" "IEnumerable<'T>"]))))
        (let ((output (fsharp-ts-info--render data)))
          (expect output :to-match "Interfaces:")
          (expect output :to-match "ICollection<'T>"))))

    (it "renders footer lines"
      (let ((data '((Signature . "val f : int")
                    (FooterLines . ["Full name: Foo.Bar" "Assembly: mscorlib"]))))
        (let ((output (fsharp-ts-info--render data)))
          (expect output :to-match "Full name: Foo.Bar")
          (expect output :to-match "Assembly: mscorlib"))))

    (it "filters out empty strings in sections"
      (let ((data '((Signature . "type T")
                    (Fields . ["" "  " "field1: int"]))))
        (let ((output (fsharp-ts-info--render data)))
          (expect output :to-match "field1: int"))))

    (it "filters out compiler-generated names"
      (let ((data '((Signature . "type T")
                    (Functions . ["<compiler-generated>" "real: int -> int"]))))
        (let ((output (fsharp-ts-info--render data)))
          (expect output :not :to-match "<compiler-generated>")
          (expect output :to-match "real: int -> int"))))

    (it "returns empty for empty data"
      (let ((data '()))
        (expect (fsharp-ts-info--render data) :to-equal ""))))

  (describe "section rendering"
    (it "returns nil for empty items"
      (expect (fsharp-ts-info--render-section "Heading:" nil) :to-be nil))

    (it "returns nil for items that are all blank"
      (expect (fsharp-ts-info--render-section "Heading:" '("" "  ")) :to-be nil))))

(describe "fsharp-ts-info timer lifecycle"
  (let (buffers original-timers)
    (before-each
      (setq original-timers (copy-sequence timer-idle-list)
            buffers (list (generate-new-buffer " *fsharp-info-a*")
                          (generate-new-buffer " *fsharp-info-b*"))
            fsharp-ts-info--buffers nil
            fsharp-ts-info--idle-timer nil
            fsharp-ts-info--last-position nil))

    (after-each
      (dolist (buffer buffers)
        (when (buffer-live-p buffer)
          (kill-buffer buffer)))
      ;; Also clean up timers leaked by the old implementation.
      (dolist (timer (copy-sequence timer-idle-list))
        (unless (memq timer original-timers)
          (cancel-timer timer)))
      (setq fsharp-ts-info--buffers nil
            fsharp-ts-info--idle-timer nil
            fsharp-ts-info--last-position nil))

    (it "shares one timer across buffers and repeated enables"
      (with-current-buffer (car buffers)
        (fsharp-ts-info-mode 1))
      (let ((timer fsharp-ts-info--idle-timer))
        (with-current-buffer (car buffers)
          (fsharp-ts-info-mode 1))
        (with-current-buffer (cadr buffers)
          (fsharp-ts-info-mode 1))
        (expect fsharp-ts-info--idle-timer :to-be timer)
        (expect (length fsharp-ts-info--buffers) :to-equal 2)
        (expect (length timer-idle-list)
                :to-equal (1+ (length original-timers)))))

    (it "keeps the timer until the last buffer disables the mode"
      (dolist (buffer buffers)
        (with-current-buffer buffer (fsharp-ts-info-mode 1)))
      (let ((timer fsharp-ts-info--idle-timer))
        (with-current-buffer (car buffers)
          (fsharp-ts-info-mode -1)
          (fsharp-ts-info-mode -1))
        (expect fsharp-ts-info--idle-timer :to-be timer)
        (expect (memq timer timer-idle-list) :to-be-truthy)
        (with-current-buffer (cadr buffers) (fsharp-ts-info-mode -1))
        (expect fsharp-ts-info--idle-timer :to-be nil)
        (expect (memq timer timer-idle-list) :to-be nil)))

    (it "unregisters killed buffers and releases the cached buffer"
      (dolist (buffer buffers)
        (with-current-buffer buffer (fsharp-ts-info-mode 1)))
      (setq fsharp-ts-info--last-position (cons (car buffers) 1))
      (let ((timer fsharp-ts-info--idle-timer))
        (kill-buffer (car buffers))
        (expect fsharp-ts-info--buffers :to-equal (cdr buffers))
        (expect fsharp-ts-info--last-position :to-be nil)
        (expect fsharp-ts-info--idle-timer :to-be timer)
        (kill-buffer (cadr buffers))
        (expect fsharp-ts-info--buffers :to-be nil)
        (expect (memq timer timer-idle-list) :to-be nil)))

    (it "stops updates when the last buffer changes major mode"
      (with-current-buffer (car buffers)
        (fsharp-ts-info-mode 1)
        (let ((timer fsharp-ts-info--idle-timer))
          (fundamental-mode)
          (expect fsharp-ts-info-mode :to-be nil)
          (expect fsharp-ts-info--buffers :to-be nil)
          (expect fsharp-ts-info--idle-timer :to-be nil)
          (expect (memq timer timer-idle-list) :to-be nil))))

    (it "keeps other buffers updating across a major-mode change"
      (dolist (buffer buffers)
        (with-current-buffer buffer (fsharp-ts-info-mode 1)))
      (let ((timer fsharp-ts-info--idle-timer))
        (with-current-buffer (car buffers) (fundamental-mode))
        (expect fsharp-ts-info--buffers :to-equal (cdr buffers))
        (expect fsharp-ts-info--idle-timer :to-be timer)
        (expect (memq timer timer-idle-list) :to-be-truthy)))

    (it "starts a fresh timer after the mode is disabled and re-enabled"
      (with-current-buffer (car buffers)
        (fsharp-ts-info-mode 1)
        (let ((old-timer fsharp-ts-info--idle-timer))
          (fsharp-ts-info-mode -1)
          (fsharp-ts-info-mode 1)
          (expect fsharp-ts-info--idle-timer :not :to-be old-timer)
          (expect (memq old-timer timer-idle-list) :to-be nil)
          (expect (memq fsharp-ts-info--idle-timer timer-idle-list)
                  :to-be-truthy)
          (expect fsharp-ts-info--buffers :to-equal (list (current-buffer))))))

    (it "updates only the selected buffer when its mode is enabled"
      (let (fetched)
        (cl-letf (((symbol-function 'eglot-current-server) (lambda () t))
                  ((symbol-function 'get-buffer-window) (lambda (&rest _) t))
                  ((symbol-function 'fsharp-ts-info--fetch)
                   (lambda () (push (current-buffer) fetched) nil)))
          (save-window-excursion
            (switch-to-buffer (car buffers))
            (setq major-mode 'fsharp-ts-mode)
            (fsharp-ts-info-mode 1)
            ;; An idle callback need not start in the selected buffer.
            (with-current-buffer (cadr buffers)
              (fsharp-ts-info--update))
            (expect fetched :to-equal (list (car buffers)))
            (fsharp-ts-info-mode -1)
            (fsharp-ts-info--update)
            (expect fetched :to-equal (list (car buffers)))))))))

;;; fsharp-ts-info-test.el ends here
