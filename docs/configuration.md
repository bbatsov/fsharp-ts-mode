# Configuration

This page covers core fsharp-ts-mode settings. For LSP-related
configuration, see [Eglot (LSP)](eglot.md). For REPL settings, see
[REPL Integration](repl.md). For dotnet CLI settings, see
[dotnet CLI](dotnet.md).

## Indentation

The default indentation offset is 4 spaces:

```emacs-lisp
;; Change indentation offset (default: 4)
(setq fsharp-ts-indent-offset 2)
```

To auto-detect the offset from file contents on open:

```emacs-lisp
(setq fsharp-ts-guess-indent-offset t)
```

You can also run `M-x fsharp-ts-mode-guess-indent-offset` manually at
any time.

## Font-Lock (Syntax Highlighting)

Syntax highlighting is organized into 4 levels, controlled by
`treesit-font-lock-level` (default: 3):

| Level | Features                                                                     |
|-------|------------------------------------------------------------------------------|
| 1     | Comments, definitions (function/value/type/member names)                     |
| 2     | Keywords, strings, type annotations, DU constructors                         |
| 3     | Attributes, builtins, constants (`true`/`false`), numbers, escape sequences  |
| 4     | Operators, brackets, delimiters, all variables, properties, function calls   |

```emacs-lisp
;; Maximum highlighting (includes operators, all variables, function calls)
(setq treesit-font-lock-level 4)
```

### Toggling Individual Features

You can enable or disable individual font-lock features without
changing the level:

```emacs-lisp
;; Enable function call highlighting (level 4) while keeping level 3 default
(add-hook 'fsharp-ts-mode-hook
          (lambda () (treesit-font-lock-recompute-features '(function) nil)))

;; Disable operator highlighting
(add-hook 'fsharp-ts-mode-hook
          (lambda () (treesit-font-lock-recompute-features nil '(operator))))
```

Available feature names for `.fs`/`.fsx` files: `comment`, `definition`,
`keyword`, `string`, `type`, `attribute`, `builtin`, `constant`,
`escape-sequence`, `number`, `operator`, `bracket`, `delimiter`,
`variable`, `property`, `function`.

!!! note
    Signature files (`.fsi`) use a separate tree-sitter grammar with a
    reduced set of font-lock rules. Only `comment`, `definition`, `keyword`,
    `string`, `type`, `bracket`, `delimiter`, and `variable` are available
    for `.fsi` buffers.

### Applying to Both Modes

Face customizations via hooks need to target both modes if you want
them to apply to implementation and signature files:

```emacs-lisp
(dolist (hook '(fsharp-ts-mode-hook fsharp-ts-signature-mode-hook))
  (add-hook hook #'my-fsharp-faces))
```

## Face Customization

Tree-sitter modes use the standard `font-lock-*-face` faces (the named
styles Emacs applies to highlighted code). You can customize them
globally or locally:

```emacs-lisp
;; Globally change how function names look
(set-face-attribute 'font-lock-function-name-face nil :weight 'bold)

;; Override faces only in fsharp-ts-mode buffers
(defun my-fsharp-faces ()
  (face-remap-add-relative 'font-lock-keyword-face :foreground "#ff6600")
  (face-remap-add-relative 'font-lock-type-face :foreground "#2aa198"))

(add-hook 'fsharp-ts-mode-hook #'my-fsharp-faces)
```

## Prettify Symbols

Enable `prettify-symbols-mode` to display common operators as Unicode
equivalents (the underlying text is unchanged -- only the display is
affected):

```emacs-lisp
(add-hook 'fsharp-ts-mode-hook #'prettify-symbols-mode)
```

Default replacements include:

| Symbol | Displayed as |
|--------|--------------|
| `->` | `→` |
| `<-` | `←` |
| `>=` | `≥` |
| `<=` | `≤` |
| `<>` | `≠` |
| `fun` | `λ` |

## Project Name in Mode-Line

When the buffer belongs to a `.fsproj` project, the mode-line (the
status bar at the bottom of each window) shows `F#[ProjectName]`.
Disable with:

```emacs-lisp
(setq fsharp-ts-show-project-name nil)
```

## Comment Handling

fsharp-ts-mode auto-continues `///` doc comments and `//` line comments
when you press `RET` at the end of a comment line. This makes writing
multi-line doc comments more convenient.

## Build Directory Awareness

When you open a file under a `bin/` or `obj/` directory, fsharp-ts-mode
prompts you to switch to the corresponding source file instead. This
helps avoid accidentally editing build artifacts.
