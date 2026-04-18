# Getting Started

## Notation

Throughout these docs, keybindings use standard Emacs notation:

| Notation | Meaning |
|----------|---------|
| `C-`     | Hold Control |
| `M-`     | Hold Alt (or Option on macOS) |
| `C-c C-d b` | Hold Control, press `c`, then hold Control and press `d`, then press `b` |
| `C-u`    | Universal prefix argument (modifies the next command) |
| `M-x`    | Open the command prompt (run any command by name) |
| `RET`    | Press Enter/Return |

## Prerequisites

To get the most out of fsharp-ts-mode, you'll want:

- [.NET SDK](https://dotnet.microsoft.com/download) -- for `dotnet fsi`, `dotnet build`, etc.
- [FsAutoComplete](https://github.com/fsharp/FsAutoComplete) -- the F# language server (auto-installed by `fsharp-ts-eglot`)

## What Works Out of the Box

Once [installed](installation.md), opening any `.fs`, `.fsx`, or `.fsi`
file activates fsharp-ts-mode (or `fsharp-ts-signature-mode` for `.fsi`).
The following features work immediately:

- **Syntax highlighting** via tree-sitter
- **Indentation** via tree-sitter
- **Imenu** (symbol index) with fully-qualified names
- **Navigation** (`C-M-a` / `C-M-e` to move between definitions, `C-M-f` / `C-M-b` for balanced expressions)
- **Switch** between `.fs` and `.fsi` files (`C-c C-a`)
- **Compile** (`C-c C-c`) with error parsing for `dotnet build`
- **.NET API docs** lookup at point (`C-c C-d`)
- **Shift region** left/right (`C-c >` / `C-c <`)
- **Build directory awareness** -- prompts to switch when visiting files under `bin/` or `obj/`

## Opt-in Features

Some features require loading additional libraries or enabling minor
modes. Here's what's available and how to set it up:

### F# Interactive (REPL)

Adds keybindings for sending code to `dotnet fsi`. See
[REPL Integration](repl.md) for details.

```emacs-lisp
(add-hook 'fsharp-ts-mode-hook #'fsharp-ts-repl-minor-mode)
```

### dotnet CLI commands

Adds keybindings for build, test, run, and other dotnet operations.
See [dotnet CLI](dotnet.md) for the full command list.

```emacs-lisp
(add-hook 'fsharp-ts-mode-hook #'fsharp-ts-dotnet-mode)
```

### Eglot/LSP with FsAutoComplete

Provides completions, diagnostics, type information, and many
[advanced LSP features](eglot.md). FsAutoComplete is downloaded
automatically on first use.

```emacs-lisp
(require 'fsharp-ts-eglot)
(add-hook 'fsharp-ts-mode-hook #'eglot-ensure)
```

### Type signature overlays (LineLens)

Shows inferred type signatures as inline overlays after definitions.
Requires an active Eglot connection. See
[LineLens](eglot.md#type-signature-overlays-linelens).

```emacs-lisp
(require 'fsharp-ts-lens)
(add-hook 'fsharp-ts-mode-hook #'fsharp-ts-lens-mode)
```

### Documentation info panel

Auto-updating side window with rich type documentation. Requires an
active Eglot connection. See
[Documentation Info Panel](eglot.md#documentation-info-panel).

```emacs-lisp
(require 'fsharp-ts-info)
(add-hook 'fsharp-ts-mode-hook #'fsharp-ts-info-mode)
```

### Other opt-in features

```emacs-lisp
;; Prettify symbols (-> to →, fun to λ, etc.)
(add-hook 'fsharp-ts-mode-hook #'prettify-symbols-mode)

;; Code folding (Emacs 30+)
(add-hook 'fsharp-ts-mode-hook #'outline-minor-mode)

;; Auto-detect indentation from file contents
(setq fsharp-ts-guess-indent-offset t)
```

## Recommended Configuration

Here's a complete setup that enables all major features:

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

!!! tip
    You don't need everything at once. Start with the base mode, add
    Eglot when you want LSP features, and add the REPL and dotnet
    modes as you need them.

## Typical Workflow

A typical F# editing session looks like this:

1. Open a `.fs` file -- fsharp-ts-mode activates automatically
2. Eglot connects to FsAutoComplete (if configured), giving you completions, diagnostics, and type info
3. Edit code with tree-sitter-powered highlighting and indentation
4. Use `C-c C-z` to send code to the REPL for interactive exploration
5. Use `C-c C-d b` to build, `C-c C-d t` to run tests (requires `fsharp-ts-dotnet-mode`)

!!! note "Keybinding overlap"
    When `fsharp-ts-dotnet-mode` is active, the `C-c C-d` prefix is
    used for dotnet commands, which shadows the base mode's `C-c C-d`
    binding for `.NET API docs lookup`. Use `M-x fsharp-ts-mode-doc-at-point`
    instead, or bind it to a different key.

    Similarly, when `fsharp-ts-repl-minor-mode` is active, `C-c C-c`
    sends the definition at point to the REPL instead of running `compile`.
    Use `M-x compile` directly if needed.

## Useful Commands

### Base mode (always active)

| Key       | Command                             | Description                     |
|-----------|-------------------------------------|---------------------------------|
| `C-c C-a` | `ff-find-other-file`                | Switch between `.fs` and `.fsi` |
| `C-c C-c` | `compile`                           | Run compilation                 |
| `C-c C-d` | `fsharp-ts-mode-doc-at-point`       | Look up symbol in .NET docs     |
| `C-c >`   | `fsharp-ts-mode-shift-region-right` | Indent region by one level      |
| `C-c <`   | `fsharp-ts-mode-shift-region-left`  | Dedent region by one level      |

See also: [Code Navigation](navigation.md) for movement commands,
[REPL Integration](repl.md) for REPL commands,
[dotnet CLI](dotnet.md) for build commands.

### Documentation lookup

| Command                                | Description                                      |
|----------------------------------------|--------------------------------------------------|
| `fsharp-ts-mode-doc-at-point`          | Look up symbol at point in .NET API docs         |
| `fsharp-ts-mode-browse-fsharp-docs`    | Open the F# documentation home page              |
| `fsharp-ts-mode-search-by-signature`   | Search FSDN by type signature (e.g., `string -> int`) |

### Indentation helpers

Both shift commands accept a prefix argument to shift by multiple levels
(e.g., `C-u 2 C-c >` shifts right by 2 levels).

`M-x fsharp-ts-mode-guess-indent-offset` scans the buffer and sets
`fsharp-ts-indent-offset` to match the file's convention. Set
`fsharp-ts-guess-indent-offset` to `t` to run this automatically on file open.

## Known Limitations

F# is an indentation-sensitive language -- the tree-sitter grammar needs
correct whitespace to parse the code. See the
[FAQ](faq.md#why-cant-i-re-indent-completely-unindented-code) for details
on how this affects editing.

## Companion Packages

These packages work well alongside fsharp-ts-mode:

- [eglot](https://github.com/joaotavora/eglot) -- LSP client (built into Emacs 29+)
- [corfu](https://github.com/minad/corfu) or [company](https://company-mode.github.io/) -- completion UI
- [flymake](https://www.gnu.org/software/emacs/manual/html_node/flymake/) -- inline diagnostics (works with eglot)
- [which-key](https://github.com/justbur/emacs-which-key) -- keybinding discovery
- [expreg](https://github.com/casouri/expreg) -- structural selection using tree-sitter
