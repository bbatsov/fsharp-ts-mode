# Troubleshooting

## Collecting Debug Information

Run `M-x fsharp-ts-mode-bug-report-info` to collect environment
information including Emacs version, OS, grammar availability, and
eglot status. Include this output when
[filing bug reports](https://github.com/bbatsov/fsharp-ts-mode/issues).

## General Debugging

Set `fsharp-ts--debug` to get more debug information from tree-sitter:

```emacs-lisp
;; Show indentation debug info and enable treesit-inspect-mode
(setq fsharp-ts--debug t)

;; Additionally show font-lock debug info (can get very noisy)
(setq fsharp-ts--debug 'font-lock)
```

When `fsharp-ts--debug` is `t`, `treesit-inspect-mode` is enabled
automatically, showing the current tree-sitter node in the mode-line.

## Missing Syntax Highlighting

If syntax highlighting is missing or incomplete:

1. Check that the grammars are installed: `M-x fsharp-ts-mode-install-grammars`
2. Verify the grammar is loaded: `M-x treesit-language-available-p RET fsharp RET`
3. Check the font-lock level: `C-h v treesit-font-lock-level`

See [Configuration](configuration.md#font-lock-syntax-highlighting) for
details on font-lock levels and feature toggles.

## Tree-sitter ABI Version Mismatch

If you see errors about ABI version incompatibility, the installed
grammar was compiled for a different tree-sitter version than your Emacs.

### macOS (Homebrew)

Homebrew's tree-sitter may be newer than what Emacs was compiled against.
Reinstall the grammars with `M-x fsharp-ts-mode-install-grammars` to
recompile them against your Emacs's tree-sitter.

### Linux

If you installed tree-sitter grammars from your distribution's package
manager, they may target a different ABI. Use
`M-x fsharp-ts-mode-install-grammars` to compile from source instead.

## Conflicting Modes

If `fsharp-mode` is also installed, it may claim F# file extensions.
The last mode registered in `auto-mode-alist` wins. To ensure
fsharp-ts-mode takes priority:

```emacs-lisp
;; Load fsharp-ts-mode after fsharp-mode
(use-package fsharp-ts-mode
  :ensure t
  :after fsharp-mode)

;; Or simply don't load fsharp-mode at all
```

See the [Migration guide](migration.md) for more details on switching.

## FsAutoComplete Not Found

If Eglot can't find FsAutoComplete:

1. **Using fsharp-ts-eglot**: It auto-downloads FSAC. Check
   `fsharp-ts-eglot-server-install-dir` for the installation path.
   See [Eglot (LSP)](eglot.md#enhanced-setup-with-fsharp-ts-eglot).
2. **Manual install**: Ensure `fsautocomplete` is in your `PATH`:
   ```
   dotnet tool install -g fsautocomplete
   ```

### macOS GUI Emacs

If you're running Emacs as a GUI app on macOS, the `PATH` may not
include `~/.dotnet/tools`. Use
[exec-path-from-shell](https://github.com/purcell/exec-path-from-shell)
to inherit your shell's PATH:

```emacs-lisp
(use-package exec-path-from-shell
  :ensure t
  :config
  (exec-path-from-shell-initialize))
```

## Grammar Compilation Errors

If `M-x fsharp-ts-mode-install-grammars` fails with compilation errors,
make sure you have a C compiler installed:

- **macOS**: Install Xcode Command Line Tools (`xcode-select --install`)
- **Linux**: Install `gcc` or `clang` via your package manager
- **Windows**: Install MSYS2 or MinGW

## Stale Byte-Compiled Files

After upgrading fsharp-ts-mode, stale `.elc` files can cause errors.
Recompile:

```
M-x byte-recompile-directory RET /path/to/fsharp-ts-mode RET
```

Or with `use-package`, delete the `elpa/fsharp-ts-mode-*` directory
and reinstall.

## Indentation Issues

F# is indentation-sensitive, so the tree-sitter grammar needs correct
whitespace to parse. If indentation seems wrong:

1. Make sure the preceding code is correctly indented -- the parser needs
   context from previous lines
2. Check `fsharp-ts-indent-offset` matches your project's convention
3. Try `M-x fsharp-ts-mode-guess-indent-offset` to auto-detect
4. Enable debug mode (`(setq fsharp-ts--debug t)`) to see what the
   indentation engine is doing

See the [FAQ](faq.md#why-cant-i-re-indent-completely-unindented-code)
for more on indentation limitations in whitespace-sensitive languages.
