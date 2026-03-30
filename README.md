# fsharp-ts-mode

[![CI](https://github.com/bbatsov/fsharp-ts-mode/actions/workflows/ci.yml/badge.svg)](https://github.com/bbatsov/fsharp-ts-mode/actions/workflows/ci.yml)
[![MELPA](https://melpa.org/packages/fsharp-ts-mode-badge.svg)](https://melpa.org/#/fsharp-ts-mode)
[![MELPA Stable](https://stable.melpa.org/packages/fsharp-ts-mode-badge.svg)](https://stable.melpa.org/#/fsharp-ts-mode)
[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-red?logo=github)](https://github.com/sponsors/bbatsov)

A tree-sitter-based Emacs major mode for [F#](https://fsharp.org) development.

**Requires Emacs 29.1+** with tree-sitter support.

## Installation

### MELPA

The package is available on [MELPA](https://melpa.org/#/fsharp-ts-mode)
and [MELPA Stable](https://stable.melpa.org/#/fsharp-ts-mode).

```
M-x package-install RET fsharp-ts-mode RET
```

Or with `use-package`:

```emacs-lisp
(use-package fsharp-ts-mode
  :ensure t)
```

### package-vc (Emacs 30+)

To install the development version directly from GitHub:

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
- F# Interactive (REPL) with tree-sitter highlighting for input
- .NET API documentation lookup at point
- Compilation error parsing for `dotnet build` output
- Prettify symbols (`->` to `→`, `fun` to `λ`, etc.)
- Eglot integration for the [F# Language Server](https://github.com/fsharp/FsAutoComplete)
- Switch between `.fs` and `.fsi` files with `C-c C-a`
- Shift region left/right for quick re-indentation
- Auto-detect indentation offset from file contents
- dotnet CLI integration (build, test, run, clean, format, restore, watch mode)
- Build directory awareness (prompts to switch from `bin/`/`obj/` to source)
- Outline mode integration (Emacs 30+)
- Bug report helpers

## Configuration

```emacs-lisp
;; Change indentation offset (default: 4)
(setq fsharp-ts-indent-offset 2)

;; Auto-guess the indent offset from file contents (default: nil)
(setq fsharp-ts-guess-indent-offset t)

;; Enable prettify-symbols-mode
(add-hook 'fsharp-ts-mode-hook #'prettify-symbols-mode)
```

### Syntax Highlighting

Syntax highlighting is organized into 4 levels, controlled by
`treesit-font-lock-level` (default: 3):

| Level | Features                                                                    |
|-------|-----------------------------------------------------------------------------|
| 1     | Comments, definitions (function/value/type/member names)                    |
| 2     | Keywords, strings, type annotations, DU constructors                       |
| 3     | Attributes, builtins, constants (`true`/`false`), numbers, escape sequences|
| 4     | Operators, brackets, delimiters, all variables, properties, function calls |

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

`fsharp-ts-mode` works with Eglot out of the box. For basic usage, install
[FsAutoComplete](https://github.com/fsharp/FsAutoComplete) manually and
enable Eglot:

```emacs-lisp
(add-hook 'fsharp-ts-mode-hook #'eglot-ensure)
```

For a richer experience, load `fsharp-ts-eglot` which provides automatic
server installation, custom LSP commands, and fine-grained feature toggles:

```emacs-lisp
(require 'fsharp-ts-eglot)
(add-hook 'fsharp-ts-mode-hook #'eglot-ensure)
```

FsAutoComplete will be downloaded automatically on first use. To pin a
specific version instead of always fetching the latest:

```emacs-lisp
(setq fsharp-ts-eglot-server-version "0.76.0")
```

#### LSP feature toggles

Individual FsAutoComplete features can be toggled via defcustoms:

```emacs-lisp
;; Disable the linter
(setq fsharp-ts-eglot-linter nil)

;; Enable pipeline type hints (off by default)
(setq fsharp-ts-eglot-pipeline-hints t)

;; Disable inlay hints
(setq fsharp-ts-eglot-inlay-hints nil)

;; Enable the simplify-name analyzer
(setq fsharp-ts-eglot-simplify-name-analyzer t)
```

Available toggles: `fsharp-ts-eglot-linter`,
`fsharp-ts-eglot-unused-opens-analyzer`,
`fsharp-ts-eglot-unused-declarations-analyzer`,
`fsharp-ts-eglot-simplify-name-analyzer`,
`fsharp-ts-eglot-enable-analyzers`,
`fsharp-ts-eglot-code-lenses`,
`fsharp-ts-eglot-inlay-hints`,
`fsharp-ts-eglot-pipeline-hints`.

#### Custom LSP commands

| Key / Command                          | Description                                         |
|----------------------------------------|-----------------------------------------------------|
| `fsharp-ts-eglot-signature-at-point`   | Display type signature of symbol at point            |
| `fsharp-ts-eglot-f1-help`             | Open MSDN docs for symbol (falls back to .NET search)|
| `fsharp-ts-eglot-generate-doc-comment` | Generate XML doc comment stub                        |

#### .fsproj manipulation

File ordering matters in F# projects. These commands manipulate the current
file's position in the `.fsproj`:

| Command                                | Description                              |
|----------------------------------------|------------------------------------------|
| `fsharp-ts-eglot-fsproj-move-file-up`  | Move file up in compilation order        |
| `fsharp-ts-eglot-fsproj-move-file-down`| Move file down in compilation order      |
| `fsharp-ts-eglot-fsproj-add-file`      | Add current file to the project          |
| `fsharp-ts-eglot-fsproj-remove-file`   | Remove current file from the project     |

#### Eldoc integration

When `fsharp-ts-eglot` is loaded, the echo area shows F#-specific type
signatures for the symbol at point (via `fsharp/signature`), providing richer
information than the standard LSP hover.

#### Project name in mode-line

The mode-line shows `F#[ProjectName]` when the buffer belongs to a `.fsproj`
project. Disable with `(setq fsharp-ts-show-project-name nil)`.

### F# Interactive (REPL)

`fsharp-ts-repl.el` provides integration with `dotnet fsi`. The REPL buffer
gets tree-sitter syntax highlighting for input (via `comint-fontify-input-mode`)
and regex-based highlighting for output.

```emacs-lisp
;; Enable the REPL minor mode in F# buffers
(add-hook 'fsharp-ts-mode-hook #'fsharp-ts-repl-minor-mode)
```

From a source buffer with `fsharp-ts-repl-minor-mode` active:

| Key       | Command                         | Description                    |
|-----------|---------------------------------|--------------------------------|
| `C-c C-z` | `fsharp-ts-repl-switch-to-repl` | Start or switch to the REPL    |
| `C-c C-c` | `fsharp-ts-repl-send-definition`| Send definition at point       |
| `C-c C-r` | `fsharp-ts-repl-send-region`    | Send region                    |
| `C-c C-b` | `fsharp-ts-repl-send-buffer`    | Send entire buffer             |
| `C-c C-l` | `fsharp-ts-repl-load-file`      | Load file via `#load` directive|
| `C-c C-i` | `fsharp-ts-repl-interrupt`      | Interrupt the REPL process     |
| `C-c C-k` | `fsharp-ts-repl-clear-buffer`   | Clear the REPL buffer          |

The `;;` expression terminator is appended automatically when missing. Input
history is persisted across sessions.

```emacs-lisp
;; Customize the REPL command (default: "dotnet" with args "fsi" "--readline-")
(setq fsharp-ts-repl-program-name "/path/to/fsi")
(setq fsharp-ts-repl-program-args '("--readline-"))
```

### Indentation Helpers

F# is indentation-sensitive, so shifting blocks of code is a common operation.

| Key       | Command                             | Description              |
|-----------|-------------------------------------|--------------------------|
| `C-c >`   | `fsharp-ts-mode-shift-region-right` | Indent region by one level |
| `C-c <`   | `fsharp-ts-mode-shift-region-left`  | Dedent region by one level |

Both commands accept a prefix argument to shift by multiple levels (e.g.,
`C-u 2 C-c >` shifts right by 2 levels).

`M-x fsharp-ts-mode-guess-indent-offset` scans the buffer and sets
`fsharp-ts-indent-offset` to match the file's convention. Set
`fsharp-ts-guess-indent-offset` to `t` to run this automatically on file open.

### Documentation Lookup

| Key       | Command                       | Description                              |
|-----------|-------------------------------|------------------------------------------|
| Key       | Command                                | Description                              |
|-----------|----------------------------------------|------------------------------------------|
| `C-c C-d` | `fsharp-ts-mode-doc-at-point`         | Look up symbol at point in .NET API docs |

This opens the [Microsoft .NET API reference](https://learn.microsoft.com/en-us/dotnet/api/)
with a search for the identifier at point. Works for any .NET type or function,
not just FSharp.Core.

`M-x fsharp-ts-mode-browse-fsharp-docs` opens the [F# documentation](https://fsharp.org/docs/)
home page.

`M-x fsharp-ts-mode-search-by-signature` searches the
[FSDN](https://fsdn.azurewebsites.net/) database by type signature -- useful
for finding functions when you know the type you need (e.g., `string -> int`).

### dotnet CLI Integration

`fsharp-ts-dotnet.el` provides a minor mode for running dotnet commands from
F# buffers. All commands run in the project root (detected by walking up to the
nearest `.sln`, `.fsproj`, or `Directory.Build.props`).

```emacs-lisp
;; Enable the dotnet minor mode in F# buffers
(add-hook 'fsharp-ts-mode-hook #'fsharp-ts-dotnet-mode)
```

All keybindings use the `C-c C-d` prefix:

| Key           | Command                              | Description             |
|---------------|--------------------------------------|-------------------------|
| `C-c C-d b`   | `fsharp-ts-dotnet-build`            | Build project           |
| `C-c C-d t`   | `fsharp-ts-dotnet-test`             | Run tests               |
| `C-c C-d r`   | `fsharp-ts-dotnet-run`              | Run project             |
| `C-c C-d c`   | `fsharp-ts-dotnet-clean`            | Clean build output      |
| `C-c C-d R`   | `fsharp-ts-dotnet-restore`          | Restore NuGet packages  |
| `C-c C-d f`   | `fsharp-ts-dotnet-format`           | Format code             |
| `C-c C-d n`   | `fsharp-ts-dotnet-new`              | New project from template|
| `C-c C-d d`   | `fsharp-ts-dotnet-command`          | Run arbitrary command   |
| `C-c C-d p`   | `fsharp-ts-dotnet-find-project-file`| Find nearest `.fsproj`  |
| `C-c C-d s`   | `fsharp-ts-dotnet-find-solution-file`| Find nearest `.sln`    |

**Watch mode**: Use `C-u` prefix with build, test, or run to switch to
`dotnet watch` (e.g., `C-u C-c C-d b` runs `dotnet watch build`). The watch
process stays alive in a comint buffer and rebuilds on file changes.

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

Base mode (always active in F# buffers):

| Key       | Command                             | Description                     |
|-----------|-------------------------------------|---------------------------------|
| `C-c C-a` | `ff-find-other-file`                | Switch between `.fs` and `.fsi` |
| `C-c C-c` | `compile`                           | Run compilation                 |
| `C-c C-d` | `fsharp-ts-mode-doc-at-point`       | Look up symbol in .NET docs     |
| `C-c >`   | `fsharp-ts-mode-shift-region-right` | Indent region                   |
| `C-c <`   | `fsharp-ts-mode-shift-region-left`  | Dedent region                   |

REPL minor mode (when `fsharp-ts-repl-minor-mode` is active):

| Key       | Command                          | Description              |
|-----------|----------------------------------|--------------------------|
| `C-c C-z` | `fsharp-ts-repl-switch-to-repl`  | Start or switch to REPL  |
| `C-c C-c` | `fsharp-ts-repl-send-definition` | Send definition at point |
| `C-c C-r` | `fsharp-ts-repl-send-region`     | Send region              |
| `C-c C-b` | `fsharp-ts-repl-send-buffer`     | Send buffer              |
| `C-c C-l` | `fsharp-ts-repl-load-file`       | Load file (`#load`)      |
| `C-c C-i` | `fsharp-ts-repl-interrupt`       | Interrupt REPL           |
| `C-c C-k` | `fsharp-ts-repl-clear-buffer`    | Clear REPL buffer        |

## Migrating from fsharp-mode

[fsharp-mode](https://github.com/fsharp/emacs-fsharp-mode) is the long-standing
Emacs package for F# editing, maintained by the F# Software Foundation.
`fsharp-ts-mode` is a new, independent package built from scratch on top of
tree-sitter. The two can coexist -- only one will be active for a given buffer
based on `auto-mode-alist` ordering.

### What's different

|                     | fsharp-mode                        | fsharp-ts-mode                                                   |
|---------------------|------------------------------------|------------------------------------------------------------------|
| Syntax highlighting | Regex-based (`font-lock-keywords`) | Tree-sitter queries (structural, 4 levels)                       |
| Indentation         | SMIE + custom heuristics           | Tree-sitter indent rules                                         |
| Min Emacs version   | 25                                 | 29.1 (tree-sitter support)                                       |
| REPL                | Built-in (`inf-fsharp-mode`)       | Built-in (`fsharp-ts-repl`) with tree-sitter input highlighting  |
| Eglot/LSP           | Via separate `eglot-fsharp`        | Built-in (`fsharp-ts-eglot`) with auto-install + custom commands |
| Compilation         | `fsc`/`msbuild` patterns           | `dotnet build` patterns                                          |
| Imenu               | Basic                              | Fully-qualified names (e.g., `Module.func`)                      |
| forward-sexp        | Syntax-table                       | Tree-sitter + syntax-table hybrid                                |
| .fsi support        | Same mode                          | Separate `fsharp-ts-signature-mode`                              |

### What fsharp-ts-mode doesn't have (yet)

- **TRAMP / remote server support** -- `eglot-fsharp` wraps the server
  command for remote access via TRAMP. `fsharp-ts-eglot` doesn't handle
  this yet.

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
  :ensure t)
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
