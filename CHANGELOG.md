# Changelog

## main (unreleased)

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
