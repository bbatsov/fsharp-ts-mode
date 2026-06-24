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
| `C-c C-n` | `fsharp-ts-repl-send-definition-and-step`| Send definition, then move to next |
| `C-c C-r` | `fsharp-ts-repl-send-region`             | Send region                        |
| `C-c C-b` | `fsharp-ts-repl-send-buffer`             | Send entire buffer                 |
| `C-c C-l` | `fsharp-ts-repl-load-file`               | Load file via `#load` directive    |
| `C-c C-p` | `fsharp-ts-repl-send-project-references` | Send project references to REPL    |
| `C-c C-i` | `fsharp-ts-repl-interrupt`               | Interrupt the REPL process         |
| `C-c C-k` | `fsharp-ts-repl-clear-buffer`            | Clear the REPL buffer              |

`M-x fsharp-ts-repl-require` references a NuGet package via a
`#r "nuget: ..."` directive, and `M-x fsharp-ts-repl-restart` kills and
relaunches the toplevel (preserving its flavor). Both are also on the
**F# REPL** menu, and the REPL buffer itself has a menu for switching
back to the source, interrupting, restarting, and clearing.

## Per-Project REPLs

Each project gets its own dedicated F# Interactive buffer (named after the
project, e.g. `*F# Interactive: MyApp*`), so source files always send to the
toplevel for their own project. The project is detected via
[`project.el`](usage.md), falling back to the nearest directory with a
solution or `.fsproj` file. Buffers outside any project share the base
`*F# Interactive*` buffer.

## REPL Flavor

`fsharp-ts-repl-flavor` selects which toplevel to launch:

- `dotnet` (default): the modern `dotnet fsi`, using `fsharp-ts-repl-program-name`
  and `fsharp-ts-repl-program-args`.
- `fsharpi`: the standalone `fsharpi`/`fsi` toplevel (Mono and legacy installs).

Set it globally or per project via a `.dir-locals.el` file. Changing the flavor
and switching to the REPL offers to restart a running toplevel with the new
flavor.

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

;; Use the standalone fsharpi toplevel instead of `dotnet fsi'
(setq fsharp-ts-repl-flavor 'fsharpi)

;; Disable syntax highlighting for REPL input
(setq fsharp-ts-repl-fontify-input nil)

;; Custom history file location
(setq fsharp-ts-repl-history-file "~/.dotnet/fsi-history")
```
