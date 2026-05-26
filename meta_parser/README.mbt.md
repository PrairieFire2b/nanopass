# YumeXi/nanopass/meta_parser

Parse MoonBit source files annotated with `#nanopass.language(...)` and `#nanopass.nonterminal` attributes to extract language definitions (terminals, nonterminals, type declarations), and diff two language versions.

## Workflow

1. Annotate an enum with `#nanopass.language(name="...")` to declare a language.
2. Constructors that reference the enum's own type are automatically detected as nonterminals.
3. Mark external enum types with `#nanopass.nonterminal`; any constructor referencing such a type gets it added as a nonterminal.
  - **NOTE**: Constructors referencing external nonterminals are also recognized as nonterminals 
4. Call `find_languages` or `find_languages_by_file` to collect all `NanoLangDef`s from a file.
5. Use `NanoLangDef::diff` to compare two language definitions and obtain a structured `Diff`.
  - **NOTE**: Only comparisons between languages ​​that share the same base language are expected.

## Core Types

### `NanoLangDef`

A language definition extracted from a single annotated enum.

- `name : String` — language name (from `#nanopass.language(name="...")`)
- `extends : String?` — optional parent language (from `extends="..."`)
- `nonterminals : Array[NonTerminal]` — self-referencing constructors and referenced external types
- `terminals : Array[Terminal]` — constructors that are neither self-referencing nor reference external nonterminals
- `type_decl : @syntax.TypeDecl` — the raw parsed enum AST node

### `NonTerminal`

```mbt nocheck
pub enum NonTerminal {
  Constructor(@syntax.ConstrDecl)  // a nonterminal constructor
  TypeDecl(@syntax.TypeDecl)       // an external type marked #nanopass.nonterminal
}
```

### `Terminal`

```mbt nocheck
pub struct Terminal(@syntax.ConstrDecl)  // a leaf / non-recursive constructor
```

### `Diff`

Result of comparing two `NanoLangDef`s via `NanoLangDef::diff`.

- `origin : NanoLangDef` — the base language
- `deriv : NanoLangDef` — the compared language
- `added_nonterminals : Array[NonTerminal]` — nonterminals only in `deriv`
- `removed_nonterminals : Array[NonTerminal]` — nonterminals only in `origin`
- `changed_nonterminals : Array[Modified[NonTerminal]]` — same-name constructors with different parameter types
- `added_terminals : Array[Terminal]` — terminals only in `deriv`
- `removed_terminals : Array[Terminal]` — terminals only in `origin`
- `changed_terminals : Array[Modified[Terminal]]` — same-name terminals with different parameter types

`Diff` implements `Show` as compact enum-like format with `+`/`-` prefixes.

### `SourceLocRepr`

Resolved source location with module, package, and file path information.

- `file_path() -> String` — relative file path (e.g. `"poc/lang_def.mbt"`)

## Key Functions

### `find_languages(src: SourceLocRepr) -> Array[NanoLangDef] raise`

Parse the file referenced by a `SourceLocRepr` and return all language definitions found in it.

### `find_languages_by_file(path: String) -> Array[NanoLangDef] raise`

Convenience overload that takes a file path string directly.

### `NanoLangDef::diff(self, other: NanoLangDef) -> Diff`

Compare two language definitions.

### `resolve(loc: SourceLoc) -> SourceLocRepr`

Resolve a `SourceLoc` into a `SourceLocRepr` with module and package information.

### `resolve_mbti(loc_repr: SourceLocRepr) -> Mbti raise`

Load and parse the `pkg.generated.mbti` interface file for the package containing the given source location.

## Usage Example

Given a source file `lang_def.mbt`:

```mbt nocheck
#nanopass.language(name="Lambda")
pub(all) enum Expr {
  Int(Int)
  Var(String)
  Lam(Var, Expr)
  App(Expr, Expr)
}

#nanopass.nonterminal
pub enum Type {
  Bool; Int; Arrow(Type, Type)
}

#nanopass.language(name="STLC", extends="Lambda")
enum TypedExpr {
  True; False; Int(Int); Var(String)
  If(TypedExpr, TypedExpr)
  Lam(Var, Type, TypedExpr)
  App(TypedExpr)
}
```

Parse and diff:

```mbt check
test "parse and diff two language definitions" {
  let langs = @meta_parser.find_languages_by_file("poc/lang_def.mbt")
  inspect(langs.length(), content="2")

  // First language: Lambda
  inspect(langs[0].name, content="Lambda")
  inspect(langs[1].name, content="SimplyTypedLambda")

  // Diff Lambda → SimplyTypedLambda
  let diff = langs[0].diff(langs[1])
  inspect(diff.added_terminals.length(), content="2")
  inspect(diff.changed_nonterminals.length(), content="1")

  // Show output
  let shown = diff.to_string()
  let expected =
    #|enum TypedExpr {
    #|  Int(Int)
    #|  Var(Var)
    #|+ True
    #|+ False
    #|  App(TypedExpr, TypedExpr)
    #|- Lam(Var, Expr)
    #|+ Lam(Var, Type, TypedExpr)
    #|+ If(TypedExpr, TypedExpr, TypedExpr)
    #|}
    #|+ Type { Bool, Int, Arrow(Type, Type) }
    #|
  inspect(shown, content=expected)
}
```

## Error Handling

```mbt nocheck
pub(all) suberror NanopassParseError {
  InvalidAttribute(String)  // malformed #nanopass.language attribute
  InvalidMbti(Json)         // failed to parse .mbti interface file
}
```
