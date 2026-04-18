# Eglot (LSP)

fsharp-ts-mode works with [Eglot](https://github.com/joaotavora/eglot)
(Emacs's built-in LSP client) and
[FsAutoComplete](https://github.com/fsharp/FsAutoComplete) (the F#
language server) for a rich IDE-like experience: completions,
diagnostics, type information, code actions, and more.

## Basic Setup

For minimal setup, install FsAutoComplete manually and enable Eglot:

```shell
dotnet tool install -g fsautocomplete
```

```emacs-lisp
(add-hook 'fsharp-ts-mode-hook #'eglot-ensure)
```

!!! tip
    On macOS, GUI Emacs may not see `~/.dotnet/tools` in its PATH.
    See [Troubleshooting](troubleshooting.md#macos-gui-emacs) for the fix.

## Enhanced Setup with fsharp-ts-eglot

For automatic server installation, custom LSP commands, and feature
toggles, load `fsharp-ts-eglot`:

```emacs-lisp
(require 'fsharp-ts-eglot)
(add-hook 'fsharp-ts-mode-hook #'eglot-ensure)
```

FsAutoComplete will be downloaded automatically on first use -- no
manual installation needed.

### Pinning a Server Version

By default, the latest version is fetched. To pin a specific version:

```emacs-lisp
(setq fsharp-ts-eglot-server-version "0.76.0")
```

### Custom Install Directory

```emacs-lisp
(setq fsharp-ts-eglot-server-install-dir "/path/to/fsautocomplete")
```

## Feature Toggles

Individual FsAutoComplete features can be toggled. These settings take
effect when Eglot connects (restart the server with
`M-x eglot-reconnect` to apply changes).

```emacs-lisp
;; Linter (FSharpLint) -- default: t
(setq fsharp-ts-eglot-linter nil)

;; Unused opens analyzer -- default: t
(setq fsharp-ts-eglot-unused-opens-analyzer nil)

;; Unused declarations analyzer -- default: t
(setq fsharp-ts-eglot-unused-declarations-analyzer nil)

;; Simplify name analyzer -- default: nil
(setq fsharp-ts-eglot-simplify-name-analyzer t)

;; Unnecessary parentheses analyzer -- default: nil
(setq fsharp-ts-eglot-unnecessary-parens-analyzer t)

;; Enable third-party analyzers -- default: nil
(setq fsharp-ts-eglot-enable-analyzers t)

;; Code lenses (reference counts, signatures) -- default: t
(setq fsharp-ts-eglot-code-lenses nil)

;; Inlay hints (types, parameter names) -- default: t
(setq fsharp-ts-eglot-inlay-hints nil)

;; Pipeline type hints -- default: nil
(setq fsharp-ts-eglot-pipeline-hints t)
```

## Custom LSP Commands

These commands use FsAutoComplete-specific LSP endpoints:

| Command                                | Description                                          |
|----------------------------------------|------------------------------------------------------|
| `fsharp-ts-eglot-signature-at-point`   | Display type signature of symbol at point            |
| `fsharp-ts-eglot-f1-help`             | Open MSDN docs for symbol (falls back to .NET search)|
| `fsharp-ts-eglot-generate-doc-comment` | Generate XML doc comment stub for the definition at point |

## .fsproj Manipulation

File ordering matters in F# projects -- the compiler processes files
in the order they appear in the `.fsproj`. These commands manipulate the
current file's position:

| Command                                 | Description                         |
|-----------------------------------------|-------------------------------------|
| `fsharp-ts-eglot-fsproj-move-file-up`   | Move file up in compilation order   |
| `fsharp-ts-eglot-fsproj-move-file-down` | Move file down in compilation order |
| `fsharp-ts-eglot-fsproj-add-file`       | Add current file to the project     |
| `fsharp-ts-eglot-fsproj-remove-file`    | Remove current file from the project|

## Eldoc Integration

When `fsharp-ts-eglot` is loaded, the echo area (the line at the bottom
of the Emacs frame) shows F#-specific type signatures for the symbol at
point via the `fsharp/signature` endpoint, providing richer information
than the standard LSP hover.

## Pipeline Type Hints and Inlay Hints

FsAutoComplete can show intermediate types at each step of `|>` pipeline
chains, as well as parameter names and type annotations as inlay hints.
These use the standard LSP inlay hints protocol and are rendered by
Eglot's built-in `eglot-inlay-hints-mode`:

```emacs-lisp
;; Enable pipeline type hints (off by default)
(setq fsharp-ts-eglot-pipeline-hints t)

;; Enable inlay hints display
(add-hook 'fsharp-ts-mode-hook #'eglot-inlay-hints-mode)
```

This shows types inline as you write pipeline chains:

```fsharp
[1; 2; 3]                        // int list
|> List.map string               // string list
|> String.concat ", "            // string
```

## Type Signature Overlays (LineLens)

`fsharp-ts-lens.el` is a **separate library** that shows inferred type
signatures as overlays after function definitions, similar to Ionide's
LineLens feature. It requires an active Eglot connection.

```emacs-lisp
(require 'fsharp-ts-lens)
(add-hook 'fsharp-ts-mode-hook #'fsharp-ts-lens-mode)
```

Overlays are refreshed on save and can be updated manually with
`M-x fsharp-ts-lens-refresh`.

### Configuration

```emacs-lisp
;; Change the overlay prefix (default: " // ")
(setq fsharp-ts-lens-prefix " // ")

;; Change the overlay face (default: font-lock-comment-face)
(setq fsharp-ts-lens-face 'shadow)
```

## Documentation Info Panel

`fsharp-ts-info.el` is a **separate library** that provides a persistent
side window showing rich type documentation for the symbol at point --
signature, documentation comment, constructors, interfaces, fields,
functions, and attributes. It requires an active Eglot connection.

```emacs-lisp
(require 'fsharp-ts-info)
```

| Command                | Description                                        |
|------------------------|----------------------------------------------------|
| `fsharp-ts-info-show`  | Show documentation for symbol at point (opens side window) |
| `fsharp-ts-info-mode`  | Toggle auto-update as you navigate code            |

### Configuration

```emacs-lisp
;; Change the auto-update delay (default: 0.5 seconds)
(setq fsharp-ts-info-idle-delay 0.5)
```

The panel updates automatically after `fsharp-ts-info-idle-delay` seconds
of idle time when `fsharp-ts-info-mode` is active and the panel window
is visible.
