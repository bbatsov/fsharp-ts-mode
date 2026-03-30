;;; fsharp-ts-info-test.el --- Tests for fsharp-ts-info -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Bozhidar Batsov

;;; Commentary:

;; Tests for the documentation info panel rendering.

;;; Code:

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

;;; fsharp-ts-info-test.el ends here
