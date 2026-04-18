# fsharp-ts-mode

[![MELPA](https://melpa.org/packages/fsharp-ts-mode-badge.svg)](https://melpa.org/#/fsharp-ts-mode)
[![MELPA Stable](https://stable.melpa.org/packages/fsharp-ts-mode-badge.svg)](https://stable.melpa.org/#/fsharp-ts-mode)
[![CI](https://github.com/bbatsov/fsharp-ts-mode/actions/workflows/ci.yml/badge.svg)](https://github.com/bbatsov/fsharp-ts-mode/actions/workflows/ci.yml)
[![Docs](https://github.com/bbatsov/fsharp-ts-mode/actions/workflows/docs.yml/badge.svg)](https://bbatsov.github.io/fsharp-ts-mode)

A tree-sitter-based Emacs major mode for [F#](https://fsharp.org), a
functional-first programming language running on .NET.

**Requires Emacs 29.1+** with tree-sitter support.

## Features

- Syntax highlighting via tree-sitter, organized into 4 configurable levels
- Indentation via tree-sitter with support for all major F# constructs
- Imenu (symbol index) with fully-qualified names (e.g., `Module.func`)
- Navigation (`beginning-of-defun`, `end-of-defun`, `forward-sexp`)
- [F# Interactive (REPL)](repl.md) with tree-sitter input highlighting and persistent history
- [Eglot/LSP integration](eglot.md) with automatic FsAutoComplete installation, custom commands, and feature toggles
- [dotnet CLI integration](dotnet.md) -- build, test, run, clean, format, restore, watch mode
- Type signature overlays ([LineLens](eglot.md#type-signature-overlays-linelens)) -- inline inferred types after definitions
- [Documentation info panel](eglot.md#documentation-info-panel) -- persistent side window with rich type documentation
- Pipeline type hints and inlay hints via LSP
- .NET API documentation lookup at point
- Compilation error parsing for `dotnet build` output
- Prettify symbols (`->` to `→`, `fun` to `λ`, etc.)
- Switch between `.fs` and `.fsi` files with `C-c C-a`
- Shift region left/right for quick re-indentation
- Auto-detect indentation offset from file contents
- Build directory awareness -- prompts to switch from `bin/`/`obj/` to source
- Outline mode integration (Emacs 30+)
- Project name in mode-line (`F#[ProjectName]`)
- Bug report helpers with environment info collection

## Why tree-sitter?

Traditional Emacs major modes rely on regular expressions for syntax
highlighting and heuristic-based indentation. This works reasonably
well for many languages, but F# presents unique challenges:

- **Indentation-sensitive syntax** -- whitespace is semantically meaningful
- **Complex syntax** -- computation expressions, type providers, active patterns
- **Rich type system** -- generic types, type annotations, discriminated unions

Tree-sitter provides a full incremental parser that understands F#'s
actual grammar. This gives fsharp-ts-mode structural awareness that
regex-based modes can't achieve -- more accurate highlighting, better
indentation, and reliable navigation.

See the [Migration guide](migration.md) for a detailed comparison with
the older regex-based `fsharp-mode`.

## Background

This package was inspired by [neocaml](https://github.com/bbatsov/neocaml), my
tree-sitter-based OCaml mode. After spending time in the OCaml community I got
curious about its .NET cousin and wanted a modern Emacs editing experience for
F# as well.

## Funding

fsharp-ts-mode is free software and will always be free. If you find it useful,
consider supporting its development via [GitHub Sponsors](https://github.com/sponsors/bbatsov).

## License

Copyright (C) 2026 Bozhidar Batsov

Distributed under the GNU General Public License, version 3.
