# pass — Nanopass 代码生成与组合

`pass` 包把 nanopass 语言组（由 `language` / `meta_parser` 产出）转化为低样板的 pass 编写 API。分两层：

| 层 | 做什么 | 何时用 |
|----|--------|--------|
| **代码生成** | `gen_*` 函数 → `@syntax.Impl[]`，通过 `@fmt.impls_to_string` 渲染 | 构建时，输出到 `.mbt` |
| **运行时** | `PassM` effect monad + 组合子 | 用户代码中，在生成的类型编译之后 |

设计理由详见 `rationale.md`（Semantics/cata）与 `pass_m_rationale.md`（PassM / 延迟子计算）。

## 为什么是代码生成而非泛型运行时

每个语言组产出唯一类型化的 `Tree[Self_, ...]`。没有 higher-kinded types，一个通用 runtime 无法对任意 Tree 形状表达类型化操作，因此 `pass` 与 `language::gen` 保持同一策略：对每组语言生成精确类型化产物。所有生成器从 `Language::layout()`（`Language::gen` 使用的同一个 `GeneratedLanguageLayout`）读取结构，保证 pass codegen 与 AST codegen 永不漂移。

## 代码生成 API

| 生成器 | 产出 | 用途 |
|--------|------|------|
| `gen_surface` | smart constructors + `{Lang}View` + `view()` | 稳定表面 API |
| `gen_semantics` | `{Lang}Semantics[Repr]`、`identity()`、`cata` | 纯 fold / transform |
| `gen_rewrite` | `{Lang}RewriteAlg[Env,St,Log,Err]`、`identity()`、`rewrite_m` | 有副作用的、流敏感 rewrite |
| `gen_rewrite_stub` | `{name}()` 返回 spread-override alg | Diff 驱动的最小覆盖 stub |
| `gen_identity` | `{Lang}::identity(self)` | 平凡恒等变换 |
| `gen_syntax_kind` | `SyntaxKind` enum（UInt16 backed） | 紧凑构造子 tag |

每个生成器接受 `@language.Language`，返回 `@list.List[@syntax.Impl]`。用 `@fmt.impls_to_string` 渲染后写入用户包的 `.mbt` 文件。

### Wrapper 构造形式

生成的 wrapper 是 tuple struct：`struct Expr(Tree[Expr, Unit, Unit])`。
构造用 `Expr(Int(n))`、`Expr(Ext(If(...)))` 的形式（wrapper 包裹裸构造子）；解构用 `let Expr(t) = self`。语言组基础语言的 `TreeExt = Unit`，其 `Ext(_)` 分支不可达（`abort`）；只有带真实 ext enum 的派生语言才展开 ext 构造子。

## 表面 API（`gen_surface`）

smart constructors 和平面 `view` enum，让 pass 作者不必接触底层 `Tree` / `Ext`：

```mbt nocheck
// smart constructors: Wrapper(裸构造子(...))
fn Expr::int(arg0 : Int) -> Expr { Expr(Int(arg0)) }
fn Expr::lam(arg0 : LambdaVar, arg1 : Expr, arg2 : Unit) -> Expr {
  Expr(Lam(arg0, arg1, arg2))
}
fn Expr::if_(arg0 : Expr, arg1 : Expr, arg2 : Expr) -> Expr {
  Expr(Ext(If(arg0, arg1, arg2)))   // ext 构造子提升为平层
}

// 平面 view enum + view()
enum ExprView {
  VInt(Int)
  VLam(LambdaVar, Expr, Unit)
  VApp(Expr, Expr)
  VIf(Expr, Expr, Expr)
  // ...
}
fn Expr::view(self : Expr) -> ExprView { ... }
```

## 纯 fold / transform（`gen_semantics`）

```mbt nocheck
// 1. 参数化代数结构体（Self_ 位置 → Repr）
struct ExprSemantics[Repr] {
  Int_ : (Int) -> Repr
  Lam_ : (LambdaVar, Repr, Unit) -> Repr
  App_ : (Repr, Repr) -> Repr
  If_  : (Repr, Repr, Repr) -> Repr   // ext 构造子提升为顶层字段
}

// 2. 典范恒等语义
fn ExprSemantics::identity() -> ExprSemantics[Expr]

// 3. 泛型 catamorphism
fn[R] Expr::cata(self : Expr, s : ExprSemantics[R]) -> R
```

`Repr` 统一了变换和折叠：
- `Repr = Expr` → 自底向上变换
- `Repr = Int` → 节点计数
- `Repr = Map[Var, Unit]` → 自由变量分析

只 spread-override 关心的构造子，不需要 `MinPass` 类型：

```mbt nocheck
// 检测是否存在 True 字面量
let has_true : TypedExprSemantics[Bool] = {
  Int_:   fn(_) { false },
  True_:  fn() { true },
  If_:    fn(c, t, e) { c || t || e },
  // ... 其余字段
}
let seen = expr.cata(has_true)
```

`cata` 是**自底向上**的：子节点折叠完才调用 handler。对纯分析零样板，但无法线程环境——流敏感 pass 请用 `rewrite_m`。

## 有副作用的 rewrite（`gen_rewrite` + `PassM`）

关键设计：handler 收到的子树是**延迟子计算**（`PassM[..., Expr]`），而非已经算好的值。Handler 自己决定何时、以什么环境执行子树。

```mbt nocheck
// Self_ 位置变为延迟 PassM 子计算
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

Alpha-renaming：只覆盖 `Var_` 和 `Lam_`，先扩环境**再**执行 body：

```mbt nocheck
let rename = {
  ..ExprRewriteAlg::identity(),
  Var_: fn(x) { ask_env().map(fn(env) { Expr::var(env.get_or(x, x)) }) },
  Lam_: fn(x, body_m, e) {
    fresh(x).flat_map(fn(x2) {
      local_env(fn(env) { env.set(x, x2) }, body_m)   // body_m 在新环境中执行
        .map(fn(body) { Expr::lam(x2, body, e) })
    })
  },
}
let out = expr.rewrite_m(rename).exec(Map::new(), 0)
```

## Diff 驱动的最小覆盖 stub（`gen_rewrite_stub`）

只暴露从基础语言到派生语言中 changed / added 的构造子（来自 `NanoLangDef::diff`），其余走 spread identity：

```mbt nocheck
fn[Env, St, Log, Err] simplify() -> TypedExprRewriteAlg[Env, St, Log, Err] {
  let base = TypedExprRewriteAlg::identity()
  TypedExprRewriteAlg::{
    ..base,
    Lam_: base.Lam_,     // changed ← 替换为真实 handler
    If_: base.If_,       // added
    True_: base.True_,   // added
    False_: base.False_, // added
  }
}
```

`changed_and_added_fields(diff)` 返回覆盖集合（例如 Lambda → SimplyTypedLambda 为 `[Lam_, If_, True_, False_]`）。

## `PassM` effect monad

`PassM[Env, St, Log, Err, A]` = Reader + State + Writer + Result：

```mbt nocheck
pub(all) struct PassM[Env, St, Log, Err, A] {
  _run : (Env, St) -> Result[(A, St, Array[Log]), Err]
}
```

| Effect | 参数 | 操作 |
|--------|------|------|
| Reader | `Env` | `ask_env`, `local_env` |
| State | `St` | `get_st`, `put_st`, `modify_st` |
| Writer | `Log` | `emit`, `traced` |
| Result | `Err` | `from_result`, `on_err`, `map_err` |

核心组合子：`pure`、`map`、`flat_map`。执行：`exec(env, st)`、`exec_env(env)`（state = Unit）、`exec_empty()`（env & state 均为 Unit）。均返回 `Result[(A, St, Array[Log]), Err]`。

注意：`local_env` 只 scope Reader——State 变更是全局可见的，这是刻意设计。需要 State 隔离时，用 `put_st` 手动保存/恢复。

## 组合函数

纯组合子（针对 `NamedPass[In, Out]`）：

| 函数 | 签名 | 作用 |
|------|------|------|
| `compose` | `(A→B, B→C) → A→C` | 顺序组合 |
| `pipeline` | `Array[NamedPass[In,In]], In → In` | 按序执行 |
| `when` | `(In→Bool, NamedPass[In,In]) → NamedPass[In,In]` | 条件执行 |
| `fixpoint` | `NamedPass[In,In], In, Int → In` | 不动点迭代（需 `In : Eq`） |

有副作用组合子（针对 `(In) -> PassM[...]`）：

| 函数 | 签名 | 作用 |
|------|------|------|
| `pipeline_m` | `Array[(In)→PassM[...,In]], In → PassM[...,In]` | 串联有副作用步骤；Err 短路，Log 聚合 |
| `when_m` | `((In)→Bool, (In)→PassM[...,In]) → (In)→PassM[...,In]` | 条件有副作用步骤 |
| `traced` | `(Log, PassM[...,A]) → PassM[...,A]` | 执行前 emit 一条日志 |

```mbt nocheck
let step = fn(e : Expr) { e.rewrite_m(rename) }
let out = pipeline_m([step, when_m(needs_fold, fold_step)], expr)
            .exec(env0, 0)
```

## 运行时类型

```mbt nocheck
pub enum PassDirection { BottomUp; TopDown }
pub enum ExtStrategy   { Keep; Fail }

pub struct PassMeta {
  name : String
  from_lang : String
  to_lang : String
  direction : PassDirection
}

pub struct NamedPass[In, Out] {
  meta : PassMeta
  run  : (In) -> Out
}
```

## 属性解析

```mbt nocheck
pub fn parse_pass_meta(attr : Attribute) -> PassMeta
```

解析 `#nanopass.pass(name="...", from="...", to="...", direction="bottom-up")`。
