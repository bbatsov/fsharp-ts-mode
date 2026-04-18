# REPL Integration

`fsharp-ts-repl.el` provides integration with F# Interactive
(`dotnet fsi`). The REPL buffer gets tree-sitter syntax highlighting
for input and regex-based highlighting for output.

## Setup

Enable the REPL minor mode in F# buffers:

```emacs-lisp
(add-hook 'fsharp-ts-mode-hook #'fsharp-ts-repl-minor-mode)
```

## Commands

From a source buffer with `fsharp-ts-repl-minor-mode` active:

| Key       | Command                                  | Description                        |
|-----------|------------------------------------------|------------------------------------|
| `C-c C-z` | `fsharp-ts-repl-switch-to-repl`          | Start or switch to the REPL        |
| `C-c C-c` | `fsharp-ts-repl-send-definition`         | Send definition at point           |
| `C-c C-r` | `fsharp-ts-repl-send-region`             | Send region                        |
| `C-c C-b` | `fsharp-ts-repl-send-buffer`             | Send entire buffer                 |
| `C-c C-l` | `fsharp-ts-repl-load-file`               | Load file via `#load` directive    |
| `C-c C-p` | `fsharp-ts-repl-send-project-references` | Send project references to REPL    |
| `C-c C-i` | `fsharp-ts-repl-interrupt`               | Interrupt the REPL process         |
| `C-c C-k` | `fsharp-ts-repl-clear-buffer`            | Clear the REPL buffer              |

!!! note
    When `fsharp-ts-repl-minor-mode` is active, `C-c C-c` sends the
    definition at point to the REPL instead of running `compile`. Use
    `M-x compile` directly if you need compilation while the REPL minor
    mode is active.

## Expression Terminators

F# Interactive requires `;;` to terminate expressions. fsharp-ts-repl
appends `;;` automatically when it's missing from the code you send,
so you don't need to worry about it.

## Project References

`C-c C-p` (`fsharp-ts-repl-send-project-references`) resolves assembly
references and source files from the nearest `.fsproj` and sends
`#r`/`#load` directives to FSI. This makes project types available in
the REPL without manual setup.

- When [Eglot](eglot.md) is connected, it uses FsAutoComplete for instant resolution
- Without Eglot, it falls back to `dotnet msbuild` (slower but standalone)

Use `M-x fsharp-ts-repl-generate-references-file` to write the directives
to a buffer for inspection instead of sending them.

## Input History

Input history is persisted across sessions. The history file location is
controlled by `fsharp-ts-repl-history-file`.

## Configuration

```emacs-lisp
;; Customize the program (default: "dotnet")
(setq fsharp-ts-repl-program-name "dotnet")

;; Customize arguments (default: '("fsi" "--readline-"))
(setq fsharp-ts-repl-program-args '("fsi" "--readline-"))

;; Disable syntax highlighting for REPL input
(setq fsharp-ts-repl-fontify-input nil)

;; Custom history file location
(setq fsharp-ts-repl-history-file "~/.dotnet/fsi-history")
```
