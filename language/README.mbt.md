# YumeXi/nanocake/language

Define and generate Tree-structured ASTs from annotated MoonBit enum definitions.

## Core Types

### `Language`

```mbt nocheck
///|
pub struct Language {
  name : String
  group : Array[NanoLangDef]
  interface : @meta_parser.Mbti
}
```

A language group consisting of a base language and its extensions.
`group[0]` is the base, subsequent entries are derived languages (via `extends`).

### Errors

```mbt nocheck
///|
pub suberror LangError {
  NoLanguageFound
}
```

## Public Methods

### `Language::def`

```mbt nocheck
pub fn Language::def(
  name? : String = "",
  loc~ : SourceLoc,
  _args_loc~ : ArgsLoc,
) -> Language raise
```

Resolve a source location, parse the file for language definitions, filter by transitive `extends` chain, and resolve the package's `.mbti` interface.

### `Language::gen`

```mbt nocheck
pub fn Language::gen(self : Language) -> @list.List[@syntax.Impl] raise
```

Generate the complete set of `Impl`s for this language group:

1. **Tree** — merged enum combining shared constructors, with `Self_` and type variables for extensions
2. **Struct wrappers** — e.g. `struct Expr(Tree[Expr, Unit, Unit])` tying the knot
3. **Ext enums** — derived-language-only constructors (e.g. `TypedExprExt`)
4. **External terminals** — types referenced by the tree but defined elsewhere, looked up via `.mbti`
5. **Parse/unparse entries** — public Cause-wrapped entrypoints plus raw `SexpError` helpers

The result can be formatted with `@fmt.impls_to_string`.

## Usage Example

Given `poc/lang_def.mbt`:

```mbt check
///|
test "define and generate a language" {
  let l = @language.Language::from_file(
    name="Lambda",
    path="poc/lang_def.mbt",
    mod="YumeXi/nanocake",
  )
  let impls = l.gen()
  let output = @fmt.impls_to_string(impls).trim_end().to_owned() + "\n"
  inspect(
    output,
    content=(
      #|///|
      #|enum Tree[Self_, LamE, TreeExt] {
      #|  /// Terminals
      #|  Int(Int)
      #|  LambdaVar(LambdaVar)
      #|  /// Nonterminals
      #|  Lam(LambdaVar, Self_, LamE)
      #|  App(Self_, Self_)
      #|  Ext(TreeExt)
      #|}
      #|
      #|///|
      #|struct Expr(Tree[Expr, Unit, Unit])
      #|
      #|///|
      #|struct TypedExpr(Tree[TypedExpr, Type, TypedExprExt[TypedExpr]])
      #|
      #|///|
      #|enum TypedExprExt[Self_] {
      #|  /// Terminals
      #|  True
      #|  False
      #|  /// Nonterminals
      #|  If(cond~ : Self_, Self_, Self_)
      #|}
      #|
      #|///|
      #|pub typealias String as LambdaVar
      #|
      #|///|
      #|pub enum Type {
      #|  Bool
      #|  Int
      #|  Arrow(Type, Type)
      #|}
      #|
      #|///|
      #|pub fn parse_Lambda(sexp : @sexp.Sexp) -> Expr raise @sexp.Cause {
      #|  @sexp.with_context("parse Lambda", () => parse_Lambda_raw(sexp))
      #|}
      #|
      #|///|
      #|fn parse_Lambda_raw(_sexp : @sexp.Sexp) -> Expr raise @sexp.SexpError {
      #|  raise  @sexp.GeneratedCode(message="parse Lambda is not generated yet")
      #|}
      #|
      #|///|
      #|pub fn unparse_Lambda(value : Expr) -> @sexp.SexpDoc raise @sexp.Cause {
      #|  @sexp.with_context("unparse Lambda", () => unparse_Lambda_raw(value))
      #|}
      #|
      #|///|
      #|fn unparse_Lambda_raw(_value : Expr) -> @sexp.SexpDoc raise @sexp.SexpError {
      #|  raise  @sexp.GeneratedCode(message="unparse Lambda is not generated yet")
      #|}
      #|
      #|///|
      #|pub fn parse_SimplyTypedLambda(sexp : @sexp.Sexp) -> TypedExpr raise @sexp.Cause {
      #|  @sexp.with_context("parse SimplyTypedLambda", () => {
      #|    parse_SimplyTypedLambda_raw(sexp)
      #|  })
      #|}
      #|
      #|///|
      #|fn parse_SimplyTypedLambda_raw(_sexp : @sexp.Sexp) -> TypedExpr raise @sexp.SexpError {
      #|  raise  
      #|    @sexp.GeneratedCode(message="parse SimplyTypedLambda is not generated yet")
      #|}
      #|
      #|///|
      #|pub fn unparse_SimplyTypedLambda(value : TypedExpr) -> @sexp.SexpDoc raise @sexp.Cause {
      #|  @sexp.with_context("unparse SimplyTypedLambda", () => {
      #|    unparse_SimplyTypedLambda_raw(value)
      #|  })
      #|}
      #|
      #|///|
      #|fn unparse_SimplyTypedLambda_raw(_value : TypedExpr) -> @sexp.SexpDoc raise @sexp.SexpError {
      #|  raise  @sexp.GeneratedCode(
      #|    message="unparse SimplyTypedLambda is not generated yet",
      #|  )
      #|}
      #|


    ),
  )
}
```

## Error Handling

```mbt nocheck
///|
pub suberror LangError {
  NoLanguageFound // no language definitions matched the given name
}
```
