# PassM 设计理由

## 1. 为什么需要 PassM

手写编译器 pass 时，以下模式反复出现：

- **环境线程**：`Lam` 需要扩展环境后递归 body，`Let` 需要先跑 rhs 再扩环境跑 body
- **fresh name**：alpha-renaming、closure conversion 都自己 thread `next_id`
- **错误传播**：每个递归层手写 `match result { Ok(x) => ..., Err(e) => Err(e) }`
- **日志/诊断**：trace、计数、警告在每个递归层穿入 logger
- **额外返回值**：一个 pass 既要改 AST 又要收集 facts，返回类型越堆越大

`PassM` 用一个统一的 effect kernel 把四种效果（Reader + State + Writer + Result）封装进一个类型：

```mbt
pub(all) struct PassM[Env, St, Log, Err, A] {
  _run : (Env, St) -> Result[(A, St, Array[Log]), Err]
}
```

## 2. 四种效果

| 效果 | 类型参数 | 操作 | 典型用途 |
|------|---------|------|---------|
| **Reader** | `Env` | `ask_env`, `local_env` | 变量绑定环境、配置 |
| **State** | `St` | `get_st`, `put_st`, `modify_st` | fresh-name 计数器、累积 facts |
| **Writer** | `Log` | `emit` | trace、诊断、警告 |
| **Result** | `Err` | `from_result`, `on_err`, `map_err` | 类型错误、作用域错误 |

四项效果打包在一个类型里，而不是拆成多个独立类型。原因是 pass 往往同时需要两三样——比如 alpha-renaming 同时需要 env（查名字）和 state（fresh counter）。拆开会导致嵌套和类型爆炸。

## 3. 延迟子计算

这是设计中最重要的决定。在 `cata` + `Semantics[Repr]` 模型中，handler 拿到的子树参数是**已经算好的 `Repr` 值**——框架先递归，再把结果交给 handler。

但 flow-sensitive pass 需要**自己控制何时、以什么环境执行子树**。典型场景是 `Lam`：

```mbt
// cata 风格: body 已经是 Repr，环境信息已丢失
Lam(x, body_result, _lam_e) => (s.lam_)(x, body_result)

// PassM 风格: body 是延迟计算，handler 先扩环境再执行
Lam(x, body_m, _lam_e) =>
  fresh_like(x).flat_map(fn(x2) {
    local_env(fn(env) { env.set(x, x2) }, body_m).map(fn(body) {
      Expr::lam(x2, body)
    })
  })
```

这正是 Keep 在 dissertation 里指出的纳米 pass 核心难点：自动遍历"先把孩子跑完"导致环境更新丢失，延迟子计算把控制权还给构造子语义。

## 4. 为什么是 record-of-fun
MoonBit 的 trait 不是一等值——不能把 trait 实例作为函数参数传递。`PassM` 的 `_run` 字段是一个闭包，`pure`/`map`/`flat_map` 通过构造新闭包来组合计算。这是手工的 dictionary-passing 实现。

如果 MoonBit 后续支持 first-class trait 或 existential types，可以在上层包一个 trait façade，但核心应维持 record-of-functions + 静态分派。ctions，不是 trait


## 5. 为什么不用 String Builder / 可变 Log

Writer 的 `Log` 通过 `Array[Log]` 累积，`flat_map` 时连接两个数组。选择 `Array` 是因为 MoonBit 标准库对它有良好支持（`+` 拼接、字面量语法）。

性能敏感的 pass（如高频 trace）可以用 `Unit` 填 `Log` 参数跳过 writer，或者未来提供一个基于 mutable `@logger` 的变体。

## 6. 类型参数顺序

`PassM[Env, St, Log, Err, A]` 的五参数顺序遵循"环境 → 状态 → 输出 → 错误 → 值"的直觉：

- `Env` 和 `St` 是最外层上下文
- `Log` 和 `Err` 是 effect 输出
- `A` 是计算产物

这个顺序与 monad transformer 栈 `ReaderT Env (StateT St (WriterT Log (ExceptT Err Identity))) A` 对应，但不要求用户理解 transformer 概念。

## 7. 与 `Semantics[Repr]` + `cata` 的关系

两者是互补的，不是替代关系：

| 维度 | `cata + Semantics` | `PassM` |
|------|-------------------|---------|
| 解决的问题 | 遍历 + 重建样板 | 环境 / 状态 / 错误 / 日志样板 |
| 递归 | 框架自动处理 | handler 自己决定顺序 |
| 子树参数 | 已求值的 `Repr` | 延迟计算的 `PassM[..., A]` |
| 适用场景 | 纯 fold、简单 transform | scope-sensitive、stateful、effectful pass |

长期看，`gen_semantics` 可以生成带 `PassM` 参数的 `Semantics` 变体——即 deep research 报告中设想的 `ExprRewriteAlg[Env, St, Log, Err]`，其中子树参数类型为 `PassM[Env, St, Log, Err, Expr]` 而非 `Expr`。

## 8. 使用注意事项

- **类型标注**：当前 MoonBit 不支持显式类型参数调用（`f[T1, T2]` 会被解析为索引），因此 `ask_env`、`emit` 等无参函数依赖类型推断。建议在变量上标注完整 `PassM[...]` 类型。
- **性能**：每次 `flat_map` 创建新闭包并连接日志数组。对热点 pass，可考虑 `Unit` 填充 `Log` 参数跳过 writer。
- **State 不跟随 local_env 回滚**：`local_env` 只 scopes Reader。State 变化是全局可见的。这是刻意设计——需要隔离 State 的场景应用 `put_st` 手动保存/恢复。
