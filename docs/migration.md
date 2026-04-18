# Migration from fsharp-mode

[fsharp-mode](https://github.com/fsharp/emacs-fsharp-mode) is the
long-standing Emacs package for F# editing, maintained by the F#
Software Foundation. `fsharp-ts-mode` is a new, independent package
built from scratch on top of tree-sitter.

The two can coexist -- only one will be active for a given buffer based
on `auto-mode-alist` ordering.

## What's Different

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

## What You Gain

- Structural syntax highlighting that understands F#'s grammar
- Better indentation for complex constructs (computation expressions, pattern matching, etc.)
- Rich [Eglot integration](eglot.md) with auto-install, feature toggles, and custom commands
- [Type signature overlays](eglot.md#type-signature-overlays-linelens) (LineLens)
- [Documentation info panel](eglot.md#documentation-info-panel)
- [dotnet CLI integration](dotnet.md) with watch mode
- Pipeline type hints
- Project name in mode-line

## What fsharp-ts-mode Doesn't Have (Yet)

- **TRAMP / remote server support** -- `eglot-fsharp` wraps the server
  command for remote access via TRAMP. `fsharp-ts-eglot` doesn't handle
  this yet.

## Switching Over

If you want `fsharp-ts-mode` to take priority, make sure it's loaded
after `fsharp-mode` (or don't load `fsharp-mode` at all).
`fsharp-ts-mode` registers itself for `.fs`, `.fsx`, `.fsscript`, and
`.fsi` files via `auto-mode-alist`, and the last registration wins.

```emacs-lisp
;; If you previously had:
(use-package fsharp-mode)

;; Replace with:
(use-package fsharp-ts-mode
  :ensure t)
```

## File Associations

fsharp-ts-mode registers two separate modes:

- `fsharp-ts-mode` for `.fs`, `.fsx`, and `.fsscript` files
- `fsharp-ts-signature-mode` for `.fsi` files

This is different from fsharp-mode, which uses a single mode for all
F# file types. The separate modes allow for grammar-specific font-lock
rules and behavior.

!!! warning
    If you have manual `auto-mode-alist` entries for F# file extensions
    in your config, remove them to avoid conflicts.

## Eglot: eglot-fsharp vs fsharp-ts-eglot

If you were using `eglot-fsharp` from fsharp-mode, you can replace it
with `fsharp-ts-eglot`:

```emacs-lisp
;; Before (with fsharp-mode):
(require 'eglot-fsharp)

;; After (with fsharp-ts-mode):
(require 'fsharp-ts-eglot)
```

`fsharp-ts-eglot` provides the same auto-install functionality plus
additional features like [custom LSP commands](eglot.md#custom-lsp-commands),
[feature toggles](eglot.md#feature-toggles), and
[.fsproj manipulation](eglot.md#fsproj-manipulation).

See the [Installation guide](installation.md) to get started, or the
full [Eglot documentation](eglot.md) for LSP configuration details.
