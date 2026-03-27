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

### Syntax Highlighting

Syntax highlighting is organized into 4 levels, controlled by
`treesit-font-lock-level` (default: 3):

| Level | Features |
|-------|----------|
| 1 | Comments, definitions (function/value/type/member names) |
| 2 | Keywords, strings, type annotations, DU constructors |
| 3 | Attributes, builtins, constants (`true`/`false`), numbers, escape sequences |
| 4 | Operators, brackets, delimiters, all variables, properties, function calls |

```emacs-lisp
;; Maximum highlighting (includes operators, all variables, function calls)
(setq treesit-font-lock-level 4)
```

You can also toggle individual font-lock features without changing the
level. Each level is a group of named features -- you can enable or
disable them selectively:

```emacs-lisp
;; Enable function call highlighting (level 4) while keeping level 3 default
(add-hook 'fsharp-ts-mode-hook
          (lambda () (treesit-font-lock-recompute-features '(function) nil)))

;; Disable operator highlighting
(add-hook 'fsharp-ts-mode-hook
          (lambda () (treesit-font-lock-recompute-features nil '(operator))))
```

The available feature names for `.fs`/`.fsx` files are: `comment`,
`definition`, `keyword`, `string`, `type`, `attribute`, `builtin`,
`constant`, `escape-sequence`, `number`, `operator`, `bracket`,
`delimiter`, `variable`, `property`, `function`.

**Note:** Signature files (`.fsi`) use a separate tree-sitter grammar with
a reduced set of font-lock rules. Only `comment`, `definition`, `keyword`,
`string`, `type`, `bracket`, `delimiter`, and `variable` are available for
`.fsi` buffers. Face customizations via hooks need to target both modes if
you want them to apply everywhere:

```emacs-lisp
(dolist (hook '(fsharp-ts-mode-hook fsharp-ts-signature-mode-hook))
  (add-hook hook #'my-fsharp-faces))
```

### Face Customization

Tree-sitter modes use the standard `font-lock-*-face` faces. You can
customize them globally or locally for F# buffers:

```emacs-lisp
;; Globally change how function names look
(set-face-attribute 'font-lock-function-name-face nil :weight 'bold)

;; Override faces only in fsharp-ts-mode buffers
(defun my-fsharp-faces ()
  (face-remap-add-relative 'font-lock-keyword-face :foreground "#ff6600")
  (face-remap-add-relative 'font-lock-type-face :foreground "#2aa198"))

(add-hook 'fsharp-ts-mode-hook #'my-fsharp-faces)
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

## Known Limitations

F# is an indentation-sensitive language -- the tree-sitter grammar needs
correct whitespace to parse the code. This has a few practical consequences:

- **Pasting unindented code**: If you paste a block of F# with all indentation
  stripped, `indent-region` won't fix it because the parser can't make sense of
  the flat structure. Paste code with its indentation intact, or re-indent it
  manually.
- **Script files (.fsx)**: Shebang lines (`#!/usr/bin/env dotnet fsi`) are
  handled automatically. Mixing `let` bindings with bare expressions works,
  though the grammar may occasionally produce unexpected results in complex
  scripts.
- **Incremental editing works well**: When you're writing code line by line, the
  parser has enough context from preceding lines to indent correctly.

See [doc/DESIGN.md](doc/DESIGN.md) for technical details on these limitations
and the overall architecture.

## Keybindings

| Key       | Command              | Description                    |
|-----------|----------------------|--------------------------------|
| `C-c C-a` | `ff-find-other-file` | Switch between `.fs` and `.fsi` |
| `C-c C-c` | `compile`            | Run compilation                |

## Migrating from fsharp-mode

[fsharp-mode](https://github.com/fsharp/emacs-fsharp-mode) is the long-standing
Emacs package for F# editing, maintained by the F# Software Foundation.
`fsharp-ts-mode` is a new, independent package built from scratch on top of
tree-sitter. The two can coexist -- only one will be active for a given buffer
based on `auto-mode-alist` ordering.

### What's different

| | fsharp-mode | fsharp-ts-mode |
|---|---|---|
| Syntax highlighting | Regex-based (`font-lock-keywords`) | Tree-sitter queries (structural, 4 levels) |
| Indentation | SMIE + custom heuristics | Tree-sitter indent rules |
| Min Emacs version | 25 | 29.1 (tree-sitter support) |
| REPL (F# Interactive) | Built-in (`inf-fsharp-mode`) | Not included (yet) |
| Eglot/LSP | Via separate `eglot-fsharp` package | Built-in (just `eglot-ensure`) |
| Compilation | `fsc`/`msbuild` patterns | `dotnet build` patterns |
| Imenu | Basic | Fully-qualified names (e.g., `Module.func`) |
| forward-sexp | Syntax-table | Tree-sitter + syntax-table hybrid |
| .fsi support | Same mode | Separate `fsharp-ts-signature-mode` |

### What fsharp-ts-mode doesn't have (yet)

- **F# Interactive (REPL)** -- `fsharp-mode` bundles `inf-fsharp-mode` for
  `comint`-based REPL interaction. `fsharp-ts-mode` doesn't include REPL support
  yet. If you need eval-region / eval-buffer, keep `inf-fsharp-mode` around or
  use a general-purpose solution like
  [comint](https://www.gnu.org/software/emacs/manual/html_node/emacs/Shell.html)
  with `dotnet fsi`.
- **Automatic LSP server installation** -- `eglot-fsharp` auto-downloads
  FsAutoComplete. With `fsharp-ts-mode` you install it yourself
  (`dotnet tool install -g fsautocomplete`), then Eglot picks it up
  automatically.

### Switching over

If you want `fsharp-ts-mode` to take priority, just make sure it's loaded after
`fsharp-mode` (or don't load `fsharp-mode` at all). `fsharp-ts-mode` registers
itself for `.fs`, `.fsx`, and `.fsi` files via `auto-mode-alist`, and the last
registration wins.

```emacs-lisp
;; If you previously had:
(use-package fsharp-mode)

;; Replace with:
(use-package fsharp-ts-mode
  :vc (:url "https://github.com/bbatsov/fsharp-ts-mode" :rev :newest))
```

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
