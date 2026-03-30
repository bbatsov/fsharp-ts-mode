# fsharp-ts-mode Design Notes

## The two F# grammars

Unlike OCaml's tree-sitter setup (where the interface grammar inherits all node
types from the base grammar), the F# tree-sitter project provides **two
independent grammars** with overlapping but distinct node types:

- `fsharp` (for `.fs` and `.fsx` files) -- the full language grammar
- `fsharp_signature` (for `.fsi` files) -- a separate grammar for signature files

Key differences:

| Concept | fsharp grammar | fsharp_signature grammar |
|---------|---------------|--------------------------|
| Value/function binding | `function_or_value_defn` | `value_definition` |
| Type name field | `type_name type_name: (...)` | field not available |
| Exception name field | `exception_definition exception_name: (...)` | field not available |
| Module definition | `module_defn` with `identifier` child | different structure |
| Namespace field | `namespace name: (...)` | `namespace (long_identifier)` |
| Keywords as tokens | full set (`of`, `open`, `type`, `exception`, etc.) | subset only |

This means we **cannot use a single set of tree-sitter queries for both
grammars**. Font-lock rules are split into:

1. **Shared rules** that use only node types common to both grammars (comments,
   strings, basic type annotations, brackets, delimiters, identifiers).
2. **Grammar-specific rules** via `fsharp-ts-mode--font-lock-settings-fsharp`
   and `fsharp-ts-mode--font-lock-settings-signature`, each using only node
   types valid for their respective grammar.

The grammar-specific rules use `:override t` so they take precedence over the
shared catch-all `(identifier) @font-lock-variable-use-face` rule.

## Indentation and the offside rule

F# uses significant whitespace (the "offside rule") -- indentation is part of
the syntax, not just formatting. The tree-sitter grammar relies on correct
whitespace to parse correctly, which creates a chicken-and-egg problem for
indentation: the parser needs correct indentation to produce the right tree, but
the indentation engine needs the right tree to indent correctly.

### Consequences

- **Re-indenting completely unindented code doesn't work.** If you paste a block
  of F# with all indentation stripped, `indent-region` will produce incorrect
  results because the parser sees ERROR nodes everywhere. This is a fundamental
  limitation of the grammar, not something we can work around.
- **Round-trip indentation works.** Already-correctly-indented code is preserved
  by `indent-region`. Our tests verify this property.
- **Incremental editing works well.** When you're typing code line by line, the
  parser usually has enough context from the preceding lines to indent the
  current line correctly.

### Trailing comments

The grammar attaches comments to the preceding definition rather than treating
them as independent top-level nodes. A comment between two `let` bindings
becomes a child of the first binding's `function_or_value_defn` node:

```
(function_or_value_defn
  (function_declaration_left ...)
  body: (const (int))
  (line_comment))            ;; <-- attached to the binding above
```

Without special handling, these comments would be indented as part of the
function body. We detect "trailing comments" -- `line_comment` nodes with no
next named sibling -- and align them with the parent definition instead.

### Script files (.fsx)

Script files without an explicit `module` declaration can mix `let` bindings
with bare expressions like `printfn`. The grammar parses bare expressions as
`application_expression` nodes and chains subsequent declarations under them,
creating deeply nested trees. We detect this pattern -- declarations whose
ancestor chain of `application_expression` / `declaration_expression` / `ERROR`
nodes ultimately lives under `file` -- and force them to column 0.

### Shebang lines

The F# grammar doesn't recognize shebang lines (`#!/usr/bin/env dotnet fsi`).
We handle this by detecting the `#!` prefix and setting
`treesit-parser-set-included-ranges` to exclude the first line from parsing.
The parser then sees the file starting from line 2, and everything works
correctly.

### The no-node problem

Empty lines have no tree-sitter node. The indentation engine resolves the parent
to the file's root node, which would always give column 0. We handle this with a
`no-node` rule that:

1. Uses the previous line's indentation as a baseline.
2. Adds `fsharp-ts-indent-offset` if the previous line ends with a
   body-expecting token (`=`, `->`, `then`, `else`, `do`, `begin`, `with`,
   `finally`, `yield`, `return`, etc.).

### Indentation rule ordering

Rules are tried in order, first match wins:

1. Trailing comment detection
2. Block comment continuation
3. Empty line handling (`no-node`)
4. Top-level (column 0 for `file`, `named_module`, `namespace`)
5. Closing delimiters (`)`, `]`, `}`, `end`, `done`)
6. Keyword alignment (`elif`, `else`, `with`, match `|`)
7. Body indentation (functions, types, modules, expressions)
8. Error recovery fallback

### Supertype nodes

The grammar uses "supertype" nodes that exist in the tree but behave
inconsistently in queries.  Some compile but fail at runtime; others work
fine in one grammar but not the other.

**Unqueryable supertypes:** `bool`, `unit`, and `null` inside `const` nodes
compile as queries but fail at runtime.  We match their parent `(const)` with
a text regex instead:

```elisp
(((const) @font-lock-constant-face
  (:match "^\\(true\\|false\\|()\\|null\\)$"
          @font-lock-constant-face)))
```

**Queryable supertypes:** `(_type)` matches all type annotation nodes
(`simple_type`, `generic_type`, `type_argument`, `postfix_type`,
`function_type`, etc.) and works at runtime in the `fsharp` grammar.  We use
it as a catch-all for type highlighting:

```elisp
(_type) @font-lock-type-face
```

However, `(_type)` fails at runtime in the `fsharp_signature` grammar, so the
shared rules use individual patterns (`simple_type`, `function_type`) instead.

## Font-lock levels

Following the Emacs convention for tree-sitter modes:

- **Level 1**: Comments and definitions (function/value/type/member names)
- **Level 2**: Keywords, strings, type annotations
- **Level 3**: Attributes, builtins, constants, numbers, escape sequences
- **Level 4**: Operators, brackets, delimiters, variables, properties, function calls

## Sources of inspiration

- [neocaml](https://github.com/bbatsov/neocaml) -- the sibling OCaml mode this
  project is modeled after
- [ionide/tree-sitter-fsharp](https://github.com/ionide/tree-sitter-fsharp) --
  the F# tree-sitter grammar
- [nvim-treesitter F# queries](https://github.com/nvim-treesitter/nvim-treesitter/tree/master/queries/fsharp) --
  Neovim's F# highlighting queries

## References

- [Emacs tree-sitter documentation](https://www.gnu.org/software/emacs/manual/html_node/elisp/Parsing-Program-Source.html)
- [Parser-based indentation](https://www.gnu.org/software/emacs/manual/html_node/elisp/Parser_002dbased-Indentation.html)
- [Tree-sitter major modes](https://www.gnu.org/software/emacs/manual/html_node/elisp/Tree_002dsitter-Major-Modes.html)
- [Building Emacs Major Modes with Tree-sitter](https://batsov.com/articles/2026/02/27/building-emacs-major-modes-with-treesitter-lessons-learned/)
