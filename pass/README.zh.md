# pass — Nanopass 代码生成与组合

## 两层模型

| 层 | 做什么 | 何时用 |
|----|--------|--------|
| **代码生成** | `gen_semantics`、`gen_identity` → `@syntax.Impl[]` | 构建时，通过 `@fmt.impls_to_string` 输出到 `.mbt` |
| **运行时组合** | `compose`、`pipeline`、`when`、`fixpoint` + 类型 | 用户代码中，在生成的类型编译之后 |

## 代码生成 API

### `gen_semantics(lang) -> List[Impl]`

替代旧的 `gen_transform` + `gen_fold` + `gen_minimal_pass`。**每种语言**生成三样东西：

```mbt
// 1. 参数化代数结构体
struct {Lang}Semantics[Repr] {
  Int_ : (Int) -> Repr
  Lam_ : (Var, Repr, Unit) -> Repr     // Self_ 位置 → Repr
  ...
}

// 2. 典范恒等语义
fn {Lang}Semantics::identity() -> {Lang}Semantics[{Lang}]

// 3. 泛型 catamorphism
fn[R] {Lang}::cata(self, s: {Lang}Semantics[R]) -> R
```

`Repr` 统一了变换和折叠：
- `Repr = {Lang}` → 自底向上变换
- `Repr = Int` → 节点计数
- `Repr = OtherType` → 分析 / 跨语言翻译

### `gen_identity(lang) -> List[Impl]`

生成 `fn {Lang}::identity(self) -> {Lang}` — 恒等变换。

## 写 pass 的模式

运行生成器、将输出写入文件后，用户代码：

```mbt
// 只覆盖一个构造子，其余走 identity
fn constant_fold() -> ExprSemantics[Expr] {
  let id = ExprSemantics::identity()
  { ..id, App_: fn(f, a) { ... } }
}

let result = expr.cata(constant_fold())
```

不需要 `MinPass` 类型——spread-default 原生支持稀疏覆盖。

## 运行时类型

```mbt
pub enum PassDirection { BottomUp; TopDown }

pub enum ExtStrategy { Keep; Fail }

pub struct PassMeta {
  name : String
  from_lang : String
  to_lang : String
  direction : PassDirection
}

pub struct NamedPass[In, Out] {
  meta : PassMeta
  run : (In) -> Out
}
```

## 组合函数

| 函数 | 签名 | 作用 |
|------|------|------|
| `compose` | `(A→B, B→C) → A→C` | 顺序组合 |
| `pipeline` | `Array[NamedPass[In,In]], In → In` | 按序执行 |
| `when` | `(In→Bool, NamedPass[In,In]) → NamedPass[In,In]` | 条件执行 |
| `fixpoint` | `NamedPass[In,In], In, Int → In` | 不动点迭代（需 `In : Eq`） |

## 属性解析

```mbt
pub fn parse_pass_meta(attr : Attribute) -> PassMeta
```

解析 `#nanopass.pass(name="...", from="...", to="...", direction="bottom-up")`。
