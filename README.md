# fsharp-ts-mode

[![CI](https://github.com/bbatsov/fsharp-ts-mode/actions/workflows/ci.yml/badge.svg)](https://github.com/bbatsov/fsharp-ts-mode/actions/workflows/ci.yml)
[![MELPA](https://melpa.org/packages/fsharp-ts-mode-badge.svg)](https://melpa.org/#/fsharp-ts-mode)
[![MELPA Stable](https://stable.melpa.org/packages/fsharp-ts-mode-badge.svg)](https://stable.melpa.org/#/fsharp-ts-mode)
[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-red?logo=github)](https://github.com/sponsors/bbatsov)

A tree-sitter-based Emacs major mode for [F#](https://fsharp.org) development.

**Requires Emacs 29.1+** with tree-sitter support.

**[Online documentation](https://bbatsov.github.io/fsharp-ts-mode)**

## Installation

The package is available on [MELPA](https://melpa.org/#/fsharp-ts-mode)
and [MELPA Stable](https://stable.melpa.org/#/fsharp-ts-mode).

```emacs-lisp
(use-package fsharp-ts-mode
  :ensure t)
```

Then install the required tree-sitter grammars:

```
M-x fsharp-ts-mode-install-grammars
```

This installs both the `fsharp` grammar (for `.fs` and `.fsx` files) and
the `fsharp-signature` grammar (for `.fsi` files) from [ionide/tree-sitter-fsharp](https://github.com/ionide/tree-sitter-fsharp).

See the [installation guide](https://bbatsov.github.io/fsharp-ts-mode/installation/)
for alternative installation methods and prerequisites.

## Features

- Syntax highlighting (font-lock) via tree-sitter, organized into 4 levels
- Indentation via tree-sitter
- Imenu support with fully-qualified names
- Navigation (`beginning-of-defun`, `end-of-defun`, `forward-sexp`)
- F# Interactive (REPL) with tree-sitter highlighting for input
- Eglot integration for [FsAutoComplete](https://github.com/fsharp/FsAutoComplete) with auto-install, feature toggles, and custom commands
- Type signature overlays (LineLens)
- Documentation info panel
- Pipeline type hints and inlay hints
- dotnet CLI integration (build, test, run, clean, format, restore, watch mode)
- .NET API documentation lookup at point
- Compilation error parsing for `dotnet build` output
- Prettify symbols (`->` to `→`, `fun` to `λ`, etc.)
- Switch between `.fs` and `.fsi` files with `C-c C-a`
- Shift region left/right for quick re-indentation
- Auto-detect indentation offset from file contents
- Build directory awareness (prompts to switch from `bin/`/`obj/` to source)
- Outline mode integration (Emacs 30+)
- Project name in mode-line
- Bug report helpers

## Quick Start

```emacs-lisp
(use-package fsharp-ts-mode
  :ensure t
  :hook ((fsharp-ts-mode . fsharp-ts-repl-minor-mode)
         (fsharp-ts-mode . fsharp-ts-dotnet-mode)
         (fsharp-ts-mode . eglot-ensure)
         (fsharp-ts-mode . prettify-symbols-mode))
  :config
  (require 'fsharp-ts-eglot)
  (require 'fsharp-ts-lens)
  (require 'fsharp-ts-info)
  (add-hook 'fsharp-ts-mode-hook #'fsharp-ts-lens-mode)
  (add-hook 'fsharp-ts-mode-hook #'fsharp-ts-info-mode)
  (setq fsharp-ts-guess-indent-offset t))
```

See the [online documentation](https://bbatsov.github.io/fsharp-ts-mode/)
for detailed configuration, usage guides, and more.

## Background

This package was inspired by [neocaml](https://github.com/bbatsov/neocaml), my
tree-sitter-based OCaml mode. After spending time in the OCaml community I got
curious about its .NET cousin and wanted a modern Emacs editing experience for
F# as well. I strongly considered naming this package "Fa Dièse" (French for
F sharp -- because naming things after spending time with OCaml does that to
you), but ultimately chickened out and went with the boring-but-obvious
`fsharp-ts-mode`. Naming is hard!

## License

Copyright (C) 2026 Bozhidar Batsov

Distributed under the GNU General Public License, version 3.
