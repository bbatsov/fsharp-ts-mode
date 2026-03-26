# fsharp-ts-mode

A tree-sitter-based Emacs major mode for [F#](https://fsharp.org) development.

**Requires Emacs 29.1+** with tree-sitter support.

## Installation

### package-vc (Emacs 30+)

```emacs-lisp
(package-vc-install "https://github.com/bbatsov/fsharp-ts-mode")
```

### use-package with package-vc (Emacs 30+)

```emacs-lisp
(use-package fsharp-ts-mode
  :vc (:url "https://github.com/bbatsov/fsharp-ts-mode" :rev :newest))
```

### Manual

Clone the repository and add it to your `load-path`:

```emacs-lisp
(add-to-list 'load-path "/path/to/fsharp-ts-mode")
(require 'fsharp-ts-mode)
```

## Grammar Installation

Install the required F# tree-sitter grammars:

```
M-x fsharp-ts-mode-install-grammars
```

This installs both the `fsharp` grammar (for `.fs` and `.fsx` files) and
the `fsharp-signature` grammar (for `.fsi` files) from [ionide/tree-sitter-fsharp](https://github.com/ionide/tree-sitter-fsharp).

## Features

- Syntax highlighting (font-lock) via tree-sitter, organized into 4 levels
- Indentation via tree-sitter
- Imenu support with fully-qualified names
- Navigation (`beginning-of-defun`, `end-of-defun`, `forward-sexp`)
- Compilation error parsing for `dotnet build` output
- Prettify symbols (`->` to `→`, `fun` to `λ`, etc.)
- Eglot integration for the [F# Language Server](https://github.com/fsharp/FsAutoComplete)
- Switch between `.fs` and `.fsi` files with `C-c C-a`

## Configuration

```emacs-lisp
;; Change indentation offset (default: 4)
(setq fsharp-ts-indent-offset 2)

;; Enable prettify-symbols-mode
(add-hook 'fsharp-ts-mode-hook #'prettify-symbols-mode)
```

### Eglot

`fsharp-ts-mode` works with Eglot out of the box if you have
[FsAutoComplete](https://github.com/fsharp/FsAutoComplete) installed:

```sh
dotnet tool install -g fsautocomplete
```

Then enable Eglot:

```emacs-lisp
(add-hook 'fsharp-ts-mode-hook #'eglot-ensure)
```

## Keybindings

| Key       | Command              | Description                    |
|-----------|----------------------|--------------------------------|
| `C-c C-a` | `ff-find-other-file` | Switch between `.fs` and `.fsi` |
| `C-c C-c` | `compile`            | Run compilation                |

## License

Copyright (C) 2026 Bozhidar Batsov

Distributed under the GNU General Public License, version 3.
