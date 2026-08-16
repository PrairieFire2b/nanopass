# `.cake` Metadata MVP

Nanocake can describe nanopass metadata in a sidecar S-expression while keeping
the enum and field types in ordinary MoonBit source. This is the first MVP of
the DSL. It replaces metadata attributes, not MoonBit's type declarations.

## Example

```lisp
(nanocake
  (version 1)
  (source lang_def.mbt)
  (nonterminal Type)
  (language Lambda
    (type Expr)
    (entry Expr)
    (meta LambdaVar)
    (production Lam
      (form (lambda $0 $1)))
    (production App
      (form ($0 $1))
      (form-only)))
  (language SimplyTypedLambda
    (type TypedExpr)
    (extends Lambda)
    (entry TypedExpr)))
```

The referenced `lang_def.mbt` contains normal MoonBit enums. The sidecar owns
language identity, inheritance, entry points, external nonterminals, and
constructor surface metadata.

## Supported Forms

- `(version 1)`
- `(source path)`
- `(nonterminal Type)`
- `(language Name ...)`
- `(type Expr)`
- `(extends Parent)`
- `(layer Name)`
- `(entry Expr)`
- `(meta Name)`
- `(remove Constructor ...)`
- `(production Constructor ...)`
- `(form pattern)`
- `(form-only)`
- `(context Name)`
- `(parse-by hook)` and `(unparse-by hook)`

Patterns are structural S-expressions. `$0`, `$1`, and `$name` become positional
or named `FormPattern` nodes. Quoted strings, `;` comments, nested lists, and
the escapes `\"`, `\\`, `\n`, `\r`, and `\t` are supported.

## API

```mbt nocheck
let langs = @meta_parser.find_languages_by_spec_file("language.cake")
let language = @language.Language::from_spec(
  name="Lambda",
  path="language.cake",
  mod="user/compiler",
  pkg="src/language",
)
```

The lowering path is:

```text
.cake -> SpecNode -> NanoSpec -> NanoLangDef[] -> layout/code generators
```

Sidecar metadata is preserved when inheritance retargets constructors. A child
language may omit an inherited constructor; its parent form and hook metadata
continue to the expanded layout.

## MVP Limits

- The sidecar does not define MoonBit enums, structs, generic types, derives, or
  visibility.
- Attribute and sidecar metadata must not be mixed for one language.
- Only positional and named placeholders are lowered in this MVP.
- `inline`, `infix`, and `name` shorthands are intentionally omitted; write a
  structural `(form ...)` instead.
- The current public loader accepts a path explicitly; it does not auto-discover
  sidecars.

The existing attribute frontend remains supported. The two frontends converge on
the same `NanoLangDef` validation and generation pipeline.
