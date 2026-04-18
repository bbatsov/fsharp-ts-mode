# Installation

## Prerequisites

- **Emacs 29.1** or later with tree-sitter support
- A **C compiler** (gcc or clang) -- needed to compile tree-sitter grammars from source
- The [.NET SDK](https://dotnet.microsoft.com/download) (for `dotnet fsi`, `dotnet build`, etc.)

## Package Installation

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

fsharp-ts-mode requires two tree-sitter grammars from [ionide/tree-sitter-fsharp](https://github.com/ionide/tree-sitter-fsharp):

- **`fsharp`** -- for `.fs` and `.fsx` files (full language)
- **`fsharp-signature`** -- for `.fsi` files (interface/signature files)

Install both with:

```
M-x fsharp-ts-mode-install-grammars
```

This downloads the grammar sources and compiles them with your system's
C compiler. If you see compilation errors, make sure `gcc` or `clang`
is installed and on your PATH.

!!! note
    If the grammars are missing when you open an F# file, fsharp-ts-mode will
    prompt you to install them automatically.

!!! tip
    If you previously had `fsharp-mode` installed, you may want to remove or
    unload it to avoid file association conflicts. See
    [Troubleshooting](troubleshooting.md#conflicting-modes) for details.

## Next Steps

Head to [Getting Started](usage.md) for a walkthrough of what works
out of the box and how to enable optional features like the REPL and
LSP integration.
