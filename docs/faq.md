# FAQ

## What version of Emacs do I need?

Emacs **29.1** or later with tree-sitter support. Emacs 30+ is
recommended for additional features like outline mode integration and
`package-vc` (installing packages directly from Git repositories).

## How do I install the tree-sitter grammars?

Run `M-x fsharp-ts-mode-install-grammars`. This installs both the
`fsharp` grammar (for `.fs`/`.fsx` files) and the `fsharp-signature`
grammar (for `.fsi` files). You'll need a C compiler (`gcc` or `clang`)
installed.

If the grammars are missing when you open an F# file, fsharp-ts-mode
will prompt you to install them.

## Can I use lsp-mode instead of Eglot?

Yes. While `fsharp-ts-eglot` provides enhanced integration with Eglot
specifically, the basic tree-sitter features (syntax highlighting,
indentation, navigation) work independently of any LSP client. You can
use [lsp-mode](https://github.com/emacs-lsp/lsp-mode) with
[FsAutoComplete](https://github.com/fsharp/FsAutoComplete) if you
prefer -- you just won't get the
[custom commands and feature toggles](eglot.md#feature-toggles) from
`fsharp-ts-eglot`.

## How do I change the indentation width?

```emacs-lisp
(setq fsharp-ts-indent-offset 2)
```

Or set `fsharp-ts-guess-indent-offset` to `t` to auto-detect from file
contents. See [Configuration](configuration.md#indentation) for details.

## Can I use fsharp-mode and fsharp-ts-mode together?

They can coexist, but only one will be active for a given buffer. The
last mode registered in `auto-mode-alist` wins. See the
[Migration guide](migration.md) for details.

## Why are there two separate modes?

F# has two distinct file types: implementation files (`.fs`) and
signature files (`.fsi`). The
[ionide/tree-sitter-fsharp](https://github.com/ionide/tree-sitter-fsharp)
project provides separate grammars for each, with different node types.
fsharp-ts-mode uses `fsharp-ts-mode` for `.fs`/`.fsx` and
`fsharp-ts-signature-mode` for `.fsi` to handle these differences
properly.

## Why can't I re-indent completely unindented code?

F# is an indentation-sensitive language -- the tree-sitter grammar needs
correct whitespace to parse. If you paste code with all indentation
stripped, `indent-region` can't fix it because the parser can't determine
the structure from flat code.

**Workarounds:**

- Paste code with its indentation intact
- Re-indent manually line by line (the parser picks up context from
  previously indented lines)
- Use `C-c >` / `C-c <` to shift entire regions once the structure is
  roughly correct

This is a fundamental limitation of tree-sitter-based indentation for
whitespace-sensitive languages, not specific to fsharp-ts-mode.

## Are there other known limitations?

A few, all related to F#'s indentation sensitivity:

- **Script files (`.fsx`)**: Mixing `let` bindings with bare expressions
  works, but the grammar may occasionally produce unexpected results in
  complex scripts. Shebang lines (`#!/usr/bin/env dotnet fsi`) are
  handled automatically.
- **Incremental editing works well**: When you're writing code line by
  line, the parser has enough context from preceding lines to indent
  correctly. The limitation mainly affects bulk operations on code that's
  already lost its indentation.

See [doc/DESIGN.md](https://github.com/bbatsov/fsharp-ts-mode/blob/main/doc/DESIGN.md)
for technical details on the architecture and these limitations.

## The dotnet minor mode shadows my `C-c C-d` doc-at-point binding. How do I fix this?

When `fsharp-ts-dotnet-mode` is active, it uses `C-c C-d` as a prefix
for dotnet commands (e.g., `C-c C-d b` for build). This shadows the
base mode's `C-c C-d` binding for `fsharp-ts-mode-doc-at-point`.

You can access doc-at-point via `M-x fsharp-ts-mode-doc-at-point`, or
bind it to a different key:

```emacs-lisp
(define-key fsharp-ts-base-mode-map (kbd "C-c d") #'fsharp-ts-mode-doc-at-point)
```

## How do I get type information in the echo area?

Load `fsharp-ts-eglot` and enable Eglot. The
[eldoc integration](eglot.md#eldoc-integration) automatically shows
F#-specific type signatures via the `fsharp/signature` endpoint.

## How do I file a bug report?

Run `M-x fsharp-ts-mode-bug-report-info` to collect environment
information (Emacs version, OS, grammar status, eglot status), then
open an issue on [GitHub](https://github.com/bbatsov/fsharp-ts-mode/issues).

## What's the relationship to neocaml?

fsharp-ts-mode was inspired by [neocaml](https://github.com/bbatsov/neocaml),
a tree-sitter-based OCaml mode by the same author. They share similar
architecture and design principles but are completely independent
packages.
