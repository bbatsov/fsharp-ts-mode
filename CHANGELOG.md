# Changelog

## main (unreleased)

### New features

- Enhanced Eglot integration (`fsharp-ts-eglot.el`): auto-download FsAutoComplete
  with version pinning, custom server class with individual feature toggles
  (analyzers, inlay hints, code lenses, pipeline hints, linter), type signature
  at point, MSDN F1 help, XML doc comment generation, and `.fsproj` file
  manipulation (move up/down, add, remove).
- Imenu now includes Namespace and Case (union/enum) entries with fully-qualified names.
- Font-lock: highlight wildcard pattern `_`, CE builder names (`async`, `task`, etc.),
  preprocessor directives (`#if`/`#else`/`#endif`), pipe-left `<|` function target,
  and anonymous record brackets `{|`/`|}`.
- Font-lock: comprehensive type annotation highlighting via `(_type)` catch-all --
  covers generic types (`IComparer<'T>`), type arguments (`'T`, `'Key`), postfix
  types (`'T array`), and all other type syntax.
- Font-lock: dot-expression highlighting -- module/type parts in base position get
  type-face, field accesses get property-face, and function calls through dot
  expressions (e.g., `System.String.Join`) get function-call-face.
- Eldoc integration: show F#-specific type signatures in the echo area via
  `fsharp/signature` endpoint when eglot is active.
- Unnecessary parentheses analyzer toggle (`fsharp-ts-eglot-unnecessary-parens-analyzer`).
- `dotnet new` command (`C-c C-d n`) with completing-read over available F#
  templates. Template list is cached; `C-u` refreshes.
- Project name in mode-line (`F#[ProjectName]`), toggleable via
  `fsharp-ts-show-project-name`.
- Auto-continue `///` doc comments and `//` comments on newline.
- REPL: send project references (`C-c C-p`) resolves `#r`/`#load` directives
  from the nearest `.fsproj`. Uses FSAC via eglot when available, falls back to
  `dotnet msbuild`. Also `fsharp-ts-repl-generate-references-file` for
  inspection.
- Documentation info panel (`fsharp-ts-info.el`): persistent side window showing
  rich type documentation (signature, comments, constructors, interfaces, fields,
  functions, attributes) for the symbol at point. Auto-updates via
  `fsharp-ts-info-mode`. Uses `fsharp/documentation` FSAC endpoint.
- FSDN search by type signature (`fsharp-ts-mode-search-by-signature`).
- Prompt to install tree-sitter grammars when missing on mode activation.
- Support `.fsscript` file extension for F# scripts.

### Bug fixes

- Fix inconsistent font-lock on qualified paths (e.g.,
  `Microsoft.FSharp.Primitives.Basics.Array.subUnchecked` no longer alternates
  faces). Removed the `^[A-Z]` heuristic for DU constructors in expressions
  which caused false positives.

## 0.1.0 (2026-03-27)

### New features

- Font-lock (syntax highlighting) via tree-sitter, organized into 4 levels.
- Indentation via tree-sitter with support for all major F# constructs.
- Imenu with fully-qualified names (e.g., `Module.func`).
- Navigation: `beginning-of-defun`, `end-of-defun`, `forward-sexp`.
- F# Interactive (REPL) integration with tree-sitter input highlighting.
- dotnet CLI minor mode: build, test, run, clean, restore, format, watch mode.
- .NET API documentation lookup at point (`C-c C-d`).
- Compilation error parsing for `dotnet build` output.
- Prettify symbols (`->` to `→`, `fun` to `λ`, etc.).
- Eglot integration for FsAutoComplete.
- Switch between `.fs` and `.fsi` files (`C-c C-a`).
- Shift region left/right (`C-c <` / `C-c >`).
- Auto-detect indentation offset from file contents.
- Build directory awareness (prompt to switch from `bin/`/`obj/` to source).
- Outline mode integration (Emacs 30+).
- Shebang line handling for `.fsx` scripts.
- Bug report helpers with environment info collection.
- GitHub issue templates.
