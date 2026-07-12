# pass 包设计理由

## 1. 为什么是代码生成，而不是泛型运行时

nanocake 生成的 `Tree[Self_, LamE, TreeExt]` 对每组语言有独特的类型参数列表。一个纯泛型运行时库无法在所有树形上表达类型化操作——因为 MoonBit 没有 higher-kinded types。README 的设计理由一节已经指出了这一点：

> A generic runtime library cannot express typed operations over arbitrary tree shapes without higher-kinded types. Code generation produces exactly-typed nanopasses and traversals per language group.

`pass::gen_semantics` 延续了 `language::gen` 的策略：对每组语言生成精确类型化的产物，而不是试图用一个全局高抽象 runtime 覆盖所有情况。

## 2. 为什么 `Semantics[Repr]` 统一 transform 和 fold

在指称语义中，语义域 `D` 是赋值函数的参数。当 `D = Syntax`（AST 自身），赋值就是自同态（transform）。当 `D` 是任意类型，赋值就是 fold。`Repr` 类型参数统一捕获了这一点：

```
[[·]] : Syntax × (Σ → Repr) → Repr
```

旧设计有 `{Name}NanoPass`（字段返回 `Tree`）和 `{Name}FoldNanoPass[R]`（字段返回 `R`）两个结构体。它们结构完全相同，唯一的区别是返回类型。合并为一个 `Semantics[Repr]` 消除了这层重复。

与之对应，`cata[R]` 统一了旧的 `transform()` 和 `fold[R]()` 两个方法——一个泛型方法覆盖两种用例。

## 3. 为什么是 catamorphism，不是手工递归

手工递归的问题是 Keep 在 nanopass 论文（2013）中明确指出过的痛点：

- **遍历与重建样板**：即使只改一两个构造子，每个 nonterminal production 都要写递归 + 重建
- **流敏感 pass 退化**：自动遍历"先把孩子跑完"，导致环境更新丢失，作者被迫手写更多 clause
- **额外返回值**：一个 pass 既要改 AST 又要收集 facts，返回类型越堆越大

catamorphism 用代数方式解耦了"遍历策略"和"构造子语义"：

```mbt
// cata 处理递归（框架代码，生成一次）
fn[R] Expr::cata(self, s: ExprSemantics[R]) -> R {
  match ... {
    App(f, a) => (s.App_)(f.cata(s), a.cata(s))  // 框架决定递归顺序
  }
}

// 用户只写构造子语义（业务代码）
{ ..id, App_: fn(f, a) { ... } }  // 用户不碰递归
```

## 4. 为什么是 record-of-functions，不是 trait

MoonBit 的 trait 不是一等值——不能把 trait 实例作为函数参数传递。如果每个构造子 handler 是一个 trait 方法，就无法表达"传入不同代数给同一 cata"：

```mbt
// ❌ 无法表达：trait 不是值
fn cata(s: impl ExprAlg[R]) -> R

// ✅ record-of-functions 是值，可以传入
fn cata(s: ExprSemantics[R]) -> R
```

`Semantics[Repr]` 是手工的 dictionary-passing 实现，等价于 tagless-final 的表达力，同时兼容 MoonBit 的值语义。如果后续 MoonBit 版本对泛型 trait 的表达力和性能足够，可以在 record-of-functions 之上包一层 trait façade，但核心 handler 应维持静态分派。

## 5. 为什么 spread-default 消除了 MinPass

旧设计有专门的 `{Name}MinPass` 类型和 `to_nanopass()` 适配器，用于"只覆盖 Diff 中指出的 changed/added 构造子"。但 MoonBit 的 record spread 语法原生支持这种模式：

```mbt
let id = ExprSemantics::identity()
{ ..id, App_: fn(f, a) { ... } }  // 只覆盖 App_，其余自动走 id
```

不需要额外的类型、适配器、或 Diff → stub 的代码生成。`identity()` 就是默认值，spread 就是覆盖。

## 6. 为什么 ext 构造子提升到顶层

派生语言的独有构造子（如 `True`、`False`、`If`）在 Tree 内部通过 `Ext(TreeExt)` 间接访问。但如果要求 pass 作者在 handler 里写嵌套 match，就违背了"构造子语义平铺"的目标。

因此 `gen_semantics` 将 ext 构造子提升为 `Semantics[Repr]` 的顶层字段，和共享构造子平级。cata 内部仍然走 `Ext(te) => match te { ... }` 分发，但 pass 作者看到的是统一的平面接口：

```mbt
struct TypedExprSemantics[Repr] {
  Int_ : (Int) -> Repr      // 共享
  Lam_ : (Var, Repr, Type) -> Repr  // 共享
  True_ : () -> Repr        // ext，提升到顶层
  If_ : (Repr, Repr, Repr) -> Repr  // ext，提升到顶层
}
```

## 7. 与 Trees That Grow 和 tagless-final 的关系

这三个概念是互补的，不是替代关系：

| 概念 | 解决的问题 | 在 nanocake 中的位置 |
|------|-----------|---------------------|
| **Trees That Grow** | AST 的**数据扩展性**：给旧构造子补字段、给树补新构造子 | `language::gen` → `Tree[Self_, LamE, TreeExt]` |
| **tagless-final** | **解释器扩展性**：同一套构造子接口上追加新解释器 | `pass::gen_semantics` → `Semantics[Repr]` |
| **catamorphism** | **遍历样板消除**：递归策略与构造子语义解耦 | `Expr::cata[R]` |

nanocake 的演进路线不是"从 TTG 跳到纯 tagless"，而是：**保留 TTG 风格的 generated AST 作为数据层，把 tagless-final 变成 pass 层的接口风格，把 catamorphism 作为 pass 层的运行模型。** 这样既不推翻 `language::gen` 已经做对的事，也精准消掉了编译器 pass 中最恼人的那类样板：遍历、重建、环境线程、以及"只改一点点却得写满所有构造子"。

## 8. 未做和未来的事

当前 `pass` 包是纯代码生成 + 运行组合子。以下设计已论证但尚未实现：

- **作用式 PassM**（Reader + State + Writer + Result）：解决环境线程、fresh name、错误传播的样板。子树参数设计为延迟计算，让 `Lam`/`Let` 的 handler 自己决定何时执行子树。
- **Rewrite[T] / changed 标记**：只有子树变化时才重建节点，减少无意义分配。
- **Diff 驱动的最小覆盖检查**：编译期验证用户确实只覆盖了变化/新增的构造子。
- **增量 / 缓存**：pass 依赖图、脏区域、缓存键。

## 9. 为什么需要 TopDown：以 alpha-rename 为例

`cata` 是 BottomUp 的——框架先对子节点递归，再将结果交给 handler。这保证了纯 fold/transform 的零样板，但对**流敏感**（flow-sensitive）pass 无能为力。

考虑一个具体场景：alpha-renaming，确保每个 binding 有唯一名字。

```mbt
// 输入：两个嵌套的 Lam，binder 都叫 "x"
Lam("x", Lam("x", Var("x")))

// 期望输出：内层 Var("x") 解析到内层 binder → "x_1"
Lam("x_0", Lam("x_1", Var("x_1")))

// 正确做法：遇到 Lam 时，先生成 fresh name，扩展 env，再递归 body
//   Lam(x, body): x2 = fresh(x); env' = env.set(x, x2); rename_in(env', body)
```

**为什么 BottomUp cata 做不到：**

cata 生成的代码是 `Lam(x, body_rec) => s.Lam_(x, body_rec)`——`body_rec` 是已经递归完的结果。handler 拿到的是 `Var("x_1")`（内层已被处理），但当下一次外层 `Lam` 扩展 env 时，它无法区分哪个 `Var` 已经解析到了哪个作用域。更根本地说，cata 的 handler **不知道** body 里有哪些自由变量、它们在哪个作用域被绑定——递归顺序使这些信息不可达。

**PassM 的解决方案（实现于 `pass_m_test.mbt`）：**

```
Lam(x, body) => {
  let body_m = rename(body)           // 延迟子计算——不立即执行
  fresh_name(x).flat_map(fn(x2) {
    emit("rename {x} -> {x2}").flat_map(fn(_) {
      local_env(fn(env) { extend_env(env, x, x2) }, body_m)
        .map(fn(new_body) { Lam(x2, new_body) })
    })
  })
}
```

核心思路：`body_m` 是 `PassM[Env, St, Log, Err, Expr]`，一个**还没执行**的计算。handler 可以先产生 fresh name、扩展 Reader 环境，**再**通过 `local_env` 执行 body 的子 pass。`Var` 的处理只需 `ask_env` 查表即可。

四种 effect 各司其职：

| Effect | 类型 | 在 alpha-rename 中的作用 |
|--------|------|--------------------------|
| Reader | `Map[Var, Var]` | `Var(x)` → 查表得到新名字 |
| State | `Int` | fresh name 计数器，每次 `fresh_name` 递增 |
| Writer | `String` | 记录每个 `"rename x → x_n"` |
| Result | `String` | 预留错误传播（如 unbound variable） |

关键行为验证（两个测试）：

1. **嵌套同名 binder** — `Lam("x", Lam("x", Var("x")))` → `Lam("x_0", Lam("x_1", Var("x_1")))`。内层的 `Var("x")` 正确解析为 `"x_1"`，因为执行内层 body 时 env 是 `{x→x_1}`。

2. **Let 遮蔽** — `let x = 1 in (let x = x in x)` → `let x_0 = 1 in (let x_1 = x_0 in x_1)`。内层 `let` 的 rhs 在**外层** env 中执行，`Var("x") → "x_0"`；body 在**内层** env 中执行，`Var("x") → "x_1"`。

这些测试验证了 `local_env` 的作用域隔离——environment 的变更只影响子计算，外层环境不受污染。这与 Keep 在 dissertation 中描述的纳米 pass 核心难点对应：自动遍历"先把孩子跑完"导致环境更新丢失，延迟子计算把控制权还给构造子语义。
