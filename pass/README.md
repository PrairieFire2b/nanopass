# pass — Nanopass Code Generation and Composition

## Two Levels

| Level | What | When |
|-------|------|------|
| **Code generation** | `gen_semantics`, `gen_identity` → `@syntax.Impl[]` | Build time, output to `.mbt` via `@fmt.impls_to_string` |
| **Runtime composition** | `compose`, `pipeline`, `when`, `fixpoint` + types | In user code, after generated types exist |

## Code Generation

### `gen_semantics(lang) -> List[Impl]`

Generates the following APIs for each language:

```mbt nocheck
// 1. Parameterized algebra struct
struct {Lang}Semantics[Repr] {
  int_ : (Int) -> Repr
  lam_ : (Var, Repr, Unit) -> Repr     // Self_ positions → Repr
  ...
}

// 2. Canonical identity denotation
fn {Lang}Semantics::identity() -> {Lang}Semantics[{Lang}]

// 3. Generic catamorphism
fn[R] {Lang}::cata(self, s: {Lang}Semantics[R]) -> R
```

`Repr` unifies transform and fold:
- `Repr = {Lang}` → bottom-up transform
- `Repr = Int` → node count
- `Repr = OtherType` → analysis / translation

### `gen_identity(lang) -> List[Impl]`

Generates `fn {Lang}::identity(self) -> {Lang}` — identity transform.

## Writing Passes

After running the generators and writing output to files, users write:

```mbt nocheck
// Override one constructor, keep identity for the rest
fn constant_fold() -> ExprSemantics[Expr] {
  let id = ExprSemantics::identity()
  { ..id, app_: fn(f, a) { ... } }
}

let result = expr.cata(constant_fold())
```

No `MinPass` type needed — spread-default handles sparse overrides natively.

## Runtime Types

```mbt nocheck
///|
pub enum PassDirection {
  BottomUp
  TopDown
}

///|
pub enum ExtStrategy {
  Keep
  Fail
}

///|
pub struct PassMeta {
  name : String
  from_lang : String
  to_lang : String
  direction : PassDirection
}

///|
pub struct NamedPass[In, Out] {
  meta : PassMeta
  run : (In) -> Out
}
```

## Composition

| Function | Signature | What |
|----------|-----------|------|
| `compose` | `(A→B, B→C) → A→C` | Sequential composition |
| `pipeline` | `Array[NamedPass[In,In]], In → In` | Run passes in order |
| `when` | `(In→Bool, NamedPass[In,In]) → NamedPass[In,In]` | Conditional pass |
| `fixpoint` | `NamedPass[In,In], In, Int → In` | Repeat until stable (needs `In : Eq`) |

## Attribute

```mbt nocheck
pub fn parse_pass_meta(attr : Attribute) -> PassMeta
```

Parses `#nanopass.pass(name="...", from="...", to="...", direction="bottom-up")`.
