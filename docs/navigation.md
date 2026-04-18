# Code Navigation

fsharp-ts-mode provides tree-sitter-powered navigation commands that
use standard Emacs keybindings. If you're familiar with navigating
code in other Emacs modes, the same keys work here -- but backed by
tree-sitter's structural understanding of F#.

## Definition Navigation

Jump between top-level definitions (`let` bindings, type definitions,
member definitions, module declarations):

| Key       | Command              | Description                                      |
|-----------|----------------------|--------------------------------------------------|
| `C-M-a`   | `beginning-of-defun` | Jump to the start of the current/previous definition |
| `C-M-e`   | `end-of-defun`       | Jump to the end of the current definition        |

These are useful for quickly moving through a file by function or type.
Press `C-M-a` repeatedly to step backward through definitions.

## Sexp Navigation

Move over balanced expressions -- parenthesized groups, bracket
expressions, or other syntactic units:

| Key       | Command        | Description                                     |
|-----------|----------------|-------------------------------------------------|
| `C-M-f`   | `forward-sexp` | Move forward over the next balanced expression  |
| `C-M-b`   | `backward-sexp`| Move backward over the previous balanced expression |

fsharp-ts-mode uses a hybrid approach: tree-sitter for structural
navigation and the syntax table for delimiter matching (parentheses,
brackets, braces). This handles both code-level and delimiter-level
movement.

## File Toggle

| Key       | Command              | Description                     |
|-----------|----------------------|---------------------------------|
| `C-c C-a` | `ff-find-other-file` | Switch between `.fs` and `.fsi` |

Toggles between implementation (`.fs`) and signature (`.fsi`) files.
Useful when you're working on a module's public API alongside its
implementation. The search patterns are configured via
`fsharp-ts-other-file-alist`.

## Imenu (Symbol Index)

Imenu is Emacs's built-in facility for jumping to definitions by name.
fsharp-ts-mode generates **fully-qualified names**, so `func` inside
`MyModule` appears as `MyModule.func`.

Imenu categories:

- **Namespace** -- namespace declarations
- **Module** -- module declarations
- **Type** -- type definitions (classes, records, unions, interfaces)
- **Case** -- union and enum cases
- **Exception** -- exception declarations
- **Value** -- `let` bindings at module level
- **Member** -- class/type members

Use `M-x imenu` to jump to a symbol, or use a completion framework
like [consult](https://github.com/minad/consult) (`M-x consult-imenu`)
for a searchable list.

## Outline Mode (Emacs 30+)

fsharp-ts-mode integrates with `outline-minor-mode` for code folding.
This lets you collapse and expand definitions to get an overview of a
file's structure:

```emacs-lisp
(add-hook 'fsharp-ts-mode-hook #'outline-minor-mode)
```

Fold/unfold with the standard outline keybindings (under `C-c @`), or
use `M-x outline-cycle` for interactive toggling.

## which-func-mode

Shows the name of the current definition in the mode-line (the status
bar at the bottom of each window):

```emacs-lisp
(add-hook 'fsharp-ts-mode-hook #'which-func-mode)
```

See also: [Configuration](configuration.md) for customizing
font-lock and indentation behavior.
