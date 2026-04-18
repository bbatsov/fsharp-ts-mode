# dotnet CLI

`fsharp-ts-dotnet.el` provides a minor mode for running dotnet CLI
commands from F# buffers. All commands run in the project root
(detected by walking up to the nearest `.sln`, `.fsproj`, or
`Directory.Build.props`).

## Setup

```emacs-lisp
(add-hook 'fsharp-ts-mode-hook #'fsharp-ts-dotnet-mode)
```

!!! note "Keybinding overlap"
    When `fsharp-ts-dotnet-mode` is active, the `C-c C-d` prefix is
    used for dotnet commands. This shadows the base mode's `C-c C-d`
    binding for `.NET API docs lookup`. Use
    `M-x fsharp-ts-mode-doc-at-point` instead, or bind it to a
    different key.

## Commands

All keybindings use the `C-c C-d` prefix:

| Key           | Command                               | Description               |
|---------------|---------------------------------------|---------------------------|
| `C-c C-d b`   | `fsharp-ts-dotnet-build`             | Build project             |
| `C-c C-d t`   | `fsharp-ts-dotnet-test`              | Run tests                 |
| `C-c C-d r`   | `fsharp-ts-dotnet-run`               | Run project               |
| `C-c C-d c`   | `fsharp-ts-dotnet-clean`             | Clean build output        |
| `C-c C-d R`   | `fsharp-ts-dotnet-restore`           | Restore NuGet packages    |
| `C-c C-d f`   | `fsharp-ts-dotnet-format`            | Format code               |
| `C-c C-d n`   | `fsharp-ts-dotnet-new`               | New project from template |
| `C-c C-d d`   | `fsharp-ts-dotnet-command`           | Run arbitrary command     |
| `C-c C-d p`   | `fsharp-ts-dotnet-find-project-file` | Find nearest `.fsproj`    |
| `C-c C-d s`   | `fsharp-ts-dotnet-find-solution-file`| Find nearest `.sln`       |

## Watch Mode

Use `C-u` prefix (the universal argument) with build, test, or run to
switch to `dotnet watch` variants:

- `C-u C-c C-d b` runs `dotnet watch build`
- `C-u C-c C-d t` runs `dotnet watch test`
- `C-u C-c C-d r` runs `dotnet watch run`

The watch process stays alive in a buffer and rebuilds automatically on
file changes.

## Project Templates

`C-c C-d n` (`fsharp-ts-dotnet-new`) presents a searchable list of
available F# templates. The template list is cached; use `C-u C-c C-d n`
to refresh the cache.

## Project Root Detection

The project root is found by walking up from the current file looking
for the first ancestor directory containing any file matching these
patterns:

- `*.sln` -- solution files
- `*.fsproj` -- project files
- `Directory.Build.props` -- MSBuild directory props

Customize the patterns:

```emacs-lisp
(setq fsharp-ts-dotnet-project-root-files '("*.sln" "*.fsproj" "Directory.Build.props"))
```

## Configuration

```emacs-lisp
;; Custom dotnet executable path (default: "dotnet")
(setq fsharp-ts-dotnet-program "/usr/local/bin/dotnet")
```

See also: [REPL Integration](repl.md) for interactive F# usage,
[Eglot (LSP)](eglot.md) for language server features.
