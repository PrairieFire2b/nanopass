# pass — Nanopass Code Generation and Composition

The `pass` package turns a nanopass language group (produced by `language` /
`meta_parser`) into low-boilerplate pass-authoring APIs. It has two levels:

| Level | What | When |
|-------|------|------|
| **Code generation** | `gen_*` functions → `@syntax.Impl[]`, rendered with `@fmt.impls_to_string` | Build time, output to `.mbt` |
| **Runtime** | `PassM` effect monad + composition combinators | In user code, after generated types exist |

Design rationale lives in `rationale.md` (Semantics/cata) and
`pass_m_rationale.md` (PassM / delayed sub-computations).

## Why code generation, not a generic runtime

Each language group produces a uniquely-typed `Tree[Self_, ...]`. Without
higher-kinded types a single generic runtime cannot express typed operations
over arbitrary tree shapes, so `pass` follows `language::gen`: it generates
exactly-typed products per group. All generators read their structure from
`Language::layout()` (the same `GeneratedLanguageLayout` that `Language::gen`
uses), so pass codegen and AST codegen never drift.

## Code generation APIs

| Generator | Emits | Purpose |
|-----------|-------|---------|
| `gen_surface` | smart constructors + `{Lang}View` + `view()` | Stable surface API |
| `gen_semantics` | `{Lang}Semantics[Repr]`, `identity()`, `cata` | Pure fold / transform |
| `gen_rewrite` | `{Lang}RewriteAlg[Env,St,Log,Err]`, `identity()`, `rewrite_m` | Effectful, scope-sensitive rewrites |
| `gen_rewrite_stub` | `{name}()` returning a spread-override alg | Diff-driven minimal-coverage stub |
| `gen_identity` | `{Lang}::identity(self)` | Trivial identity transform |
| `gen_syntax_kind` | `SyntaxKind` enum (UInt16-backed) | Compact constructor tags |

Every generator takes a `@language.Language` and returns
`@list.List[@syntax.Impl]`. Render with `@fmt.impls_to_string` and write to a
`.mbt` file in the user's package.

### Wrapper construction form

Generated wrappers are tuple structs: `struct Expr(Tree[Expr, Unit, Unit])`.
So values are built by wrapping the bare inner constructor —
`Expr(Int(n))`, `Expr(Ext(If(...)))` — and destructured with
`let Expr(t) = self`. The base language of a group has `TreeExt = Unit`, so its
`Ext(_)` arm is unreachable (`abort`); only derived languages expand their ext
constructors.

## Surface API (`gen_surface`)

Smart constructors and a flat `view` enum so pass authors never touch the
underlying `Tree` / `Ext`:

```mbt nocheck
// Smart constructors: Wrapper(bare-constructor(...))

///|
fn Expr::int(arg0 : Int) -> Expr {
  Expr(Int(arg0))
}

///|
fn Expr::lam(arg0 : LambdaVar, arg1 : Expr, arg2 : Unit) -> Expr {
  Expr(Lam(arg0, arg1, arg2))
}

///|
fn Expr::if_(arg0 : Expr, arg1 : Expr, arg2 : Expr) -> Expr {
  Expr(Ext(If(arg0, arg1, arg2))) // ext constructors lifted flat
}

// Flat view enum + view()

///|
enum ExprView {
  VInt(Int)
  VLam(LambdaVar, Expr, Unit)
  VApp(Expr, Expr)
  VIf(Expr, Expr, Expr)
  // ...
}

///|
fn Expr::view(self : Expr) -> ExprView {
  ...
}
```

## Pure fold / transform (`gen_semantics`)

```mbt nocheck
// 1. Parameterized algebra (Self_ positions → Repr)
struct ExprSemantics[Repr] {
  Int_ : (Int) -> Repr
  Lam_ : (LambdaVar, Repr, Unit) -> Repr
  App_ : (Repr, Repr) -> Repr
  // ext constructors lifted to top-level fields
  If_  : (Repr, Repr, Repr) -> Repr
}

// 2. Canonical identity denotation
fn ExprSemantics::identity() -> ExprSemantics[Expr]

// 3. Generic catamorphism
fn[R] Expr::cata(self : Expr, s : ExprSemantics[R]) -> R
```

`Repr` unifies transform and fold:
- `Repr = Expr` → bottom-up transform
- `Repr = Int` → node count
- `Repr = Set[Var]` → free-variable analysis

Write a pass by spread-overriding only the constructors you care about — no
`MinPass` type, spread-default handles sparse overrides natively:

```mbt nocheck
// Detect whether a `True` appears anywhere
fn has_true() -> TypedExprSemantics[Bool] {
  let id = TypedExprSemantics::identity()   // (won't type-check: identity is Repr=TypedExpr)
  // for analysis use a purpose-built algebra:
  { Int_: fn(_) { false }, True_: fn() { true }, If_: fn(c, t, e) { c || t || e }, .. }
}
let seen = expr.cata(has_true())
```

`cata` is **bottom-up**: children are folded before the handler runs. That is
zero-boilerplate for pure analysis but cannot thread an environment — for that
use `rewrite_m`.

## Effectful rewrites (`gen_rewrite` + `PassM`)

The key to scope-sensitive passes: handlers receive **delayed
sub-computations** (`PassM[..., Expr]`), not already-evaluated children. The
handler decides *when* and *in what environment* to run each subtree.

```mbt nocheck
// Sub-tree positions become delayed PassM computations
struct ExprRewriteAlg[Env, St, Log, Err] {
  Int_ : (Int) -> @pass.PassM[Env, St, Log, Err, Expr]
  Lam_ : (LambdaVar, @pass.PassM[Env, St, Log, Err, Expr], Unit)
         -> @pass.PassM[Env, St, Log, Err, Expr]
  App_ : (@pass.PassM[Env, St, Log, Err, Expr], @pass.PassM[Env, St, Log, Err, Expr])
         -> @pass.PassM[Env, St, Log, Err, Expr]
}

fn[Env, St, Log, Err] ExprRewriteAlg::identity() -> ExprRewriteAlg[Env, St, Log, Err]
fn[Env, St, Log, Err] Expr::rewrite_m(
  self : Expr, alg : ExprRewriteAlg[Env, St, Log, Err],
) -> @pass.PassM[Env, St, Log, Err, Expr]
```

Alpha-renaming — override only `Var_` and `Lam_`, extend the environment
*before* running the body:

```mbt nocheck
let rename = {
  ..ExprRewriteAlg::identity(),
  Var_: fn(x) { ask_env().map(fn(env) { Expr::var(env.get_or(x, x)) }) },
  Lam_: fn(x, body_m, e) {
    fresh(x).flat_map(fn(x2) {
      local_env(fn(env) { env.set(x, x2) }, body_m)   // body_m runs in the new env
        .map(fn(body) { Expr::lam(x2, body, e) })
    })
  },
}
let out = expr.rewrite_m(rename).exec(Map::new(), 0)
```

## Diff-driven stubs (`gen_rewrite_stub`)

Generate a rewrite alg that only exposes the constructors that changed or were
added between base and derived language (from `NanoLangDef::diff`); everything
else stays `identity()` via spread:

```mbt nocheck
fn[Env, St, Log, Err] simplify() -> TypedExprRewriteAlg[Env, St, Log, Err] {
  let base = TypedExprRewriteAlg::identity()
  TypedExprRewriteAlg::{
    ..base,
    Lam_: base.Lam_,     // changed
    If_: base.If_,       // added   ← replace with your handler
    True_: base.True_,   // added
    False_: base.False_, // added
  }
}
```

`changed_and_added_fields(diff)` returns the covering set (e.g.
`[Lam_, If_, True_, False_]` for `Lambda → SimplyTypedLambda`).

## `PassM` effect monad

`PassM[Env, St, Log, Err, A]` = Reader + State + Writer + Result:

```mbt nocheck
///|
pub(all) struct PassM[Env, St, Log, Err, A] {
  _run : (Env, St) -> Result[(A, St, Array[Log]), Err]
}
```

| Effect | Params | Operations |
|--------|--------|-----------|
| Reader | `Env` | `ask_env`, `local_env` |
| State | `St` | `get_st`, `put_st`, `modify_st` |
| Writer | `Log` | `emit`, `traced` |
| Result | `Err` | `from_result`, `on_err`, `map_err` |

Core combinators: `pure`, `map`, `flat_map`. Execution: `exec(env, st)`,
`exec_env(env)` (state = Unit), `exec_empty()` (env & state = Unit). All return
`Result[(A, St, Array[Log]), Err]`.

`local_env` scopes the Reader only — State changes are global by design. Save /
restore state manually if you need isolation.

## Composition

Pure combinators (over `NamedPass[In, Out]`):

| Function | Signature | What |
|----------|-----------|------|
| `compose` | `(A→B, B→C) → A→C` | Sequential composition |
| `pipeline` | `Array[NamedPass[In,In]], In → In` | Run passes in order |
| `when` | `(In→Bool, NamedPass[In,In]) → NamedPass[In,In]` | Conditional pass |
| `fixpoint` | `NamedPass[In,In], In, Int → In` | Repeat until stable (`In : Eq`) |

Effectful combinators (over `(In) -> PassM[...]`):

| Function | Signature | What |
|----------|-----------|------|
| `pipeline_m` | `Array[(In) → PassM[...,In]], In → PassM[...,In]` | Sequence effectful steps; Err short-circuits, Log accumulates |
| `when_m` | `((In)→Bool, (In)→PassM[...,In]) → (In)→PassM[...,In]` | Conditional effectful step |
| `traced` | `(Log, PassM[...,A]) → PassM[...,A]` | Emit a log entry before running |

```mbt nocheck
///|
let step = fn(e : Expr) { e.rewrite_m(rename) }

///|
let out = pipeline_m([step, when_m(needs_fold, fold_step)], expr).exec(env0, 0)
```

## Runtime types

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

## Attribute

```mbt nocheck
pub fn parse_pass_meta(attr : Attribute) -> PassMeta
```

Parses `#nanopass.pass(name="...", from="...", to="...", direction="bottom-up")`.
