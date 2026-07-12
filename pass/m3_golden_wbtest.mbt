///|
/// Ground-truth fixture for M3 generated `rewrite_m` + `RewriteAlg`.
///
/// Reuses the `MExpr` / `MTree` shapes from `m1_golden_wbtest.mbt`.
///
/// The key idea (delayed sub-computation): each self-ref subtree is passed to
/// the handler as an UNEXECUTED `PassM[..., MExpr]`, so scope-sensitive passes
/// (e.g. alpha-rename) can extend the environment BEFORE running the child.
///
/// This hand-written golden proves the generated shapes compile and behave.

///|
struct MExprRewriteAlg[Env, St, Log, Err] {
  int_ : (Int) -> PassM[Env, St, Log, Err, MExpr]
  var_ : (MVar) -> PassM[Env, St, Log, Err, MExpr]
  lam_ : (MVar, PassM[Env, St, Log, Err, MExpr], Unit) -> PassM[
    Env,
    St,
    Log,
    Err,
    MExpr,
  ]
  app_ : (
    PassM[Env, St, Log, Err, MExpr],
    PassM[Env, St, Log, Err, MExpr],
  ) -> PassM[Env, St, Log, Err, MExpr]
}

///|
/// identity: run each subtree, then rebuild via smart constructors.
fn[Env, St, Log, Err] MExprRewriteAlg::identity() -> MExprRewriteAlg[
  Env,
  St,
  Log,
  Err,
] {
  {
    int_: fn(n) { PassM::pure(MExpr::int(n)) },
    var_: fn(x) { PassM::pure(MExpr::var(x)) },
    lam_: fn(x, body_m, _e) {
      body_m.map(fn(body) { MExpr::lam(x, body) })
    },
    app_: fn(f_m, a_m) {
      f_m.flat_map(fn(f) { a_m.map(fn(a) { MExpr::app(f, a) }) })
    },
  }
}

///|
/// rewrite_m: destructure wrapper, pass each subtree as a DELAYED rewrite_m call.
fn[Env, St, Log, Err] MExpr::rewrite_m(
  self : MExpr,
  alg : MExprRewriteAlg[Env, St, Log, Err],
) -> PassM[Env, St, Log, Err, MExpr] {
  let MExpr(t) = self
  match t {
    Int(n) => (alg.int_)(n)
    LambdaVar(x) => (alg.var_)(x)
    Lam(x, body, e) => (alg.lam_)(x, body.rewrite_m(alg), e)
    App(f, a) => (alg.app_)(f.rewrite_m(alg), a.rewrite_m(alg))
    Ext(_) => abort("MExpr has no ext constructors")
  }
}

///|
test "M3 golden: identity rewrite_m reproduces the input" {
  let e = MExpr::app(MExpr::lam("x", MExpr::var("x")), MExpr::int(5))
  let alg : MExprRewriteAlg[Unit, Unit, String, String] = MExprRewriteAlg::identity()
  match e.rewrite_m(alg).exec_empty() {
    Ok((out, _, _)) =>
      debug_inspect(
        out,
        content=(
          #|MExpr(App(MExpr(Lam("x", MExpr(LambdaVar("x")), ())), MExpr(Int(5))))
        ),
      )
    Err(_) => panic()
  }
}

///|
/// alpha-rename via generated rewrite_m: override only var_ and lam_.
/// Demonstrates delayed sub-computation: lam_ extends the env BEFORE running
/// the body subtree.
test "M3 golden: alpha-rename overrides only var_ and lam_" {
  let alg : MExprRewriteAlg[Map[MVar, MVar], Int, String, String] = {
    ..MExprRewriteAlg::identity(),
    var_: fn(x) {
      ask_env().map(fn(env : Map[MVar, MVar]) {
        match env.get(x) {
          Some(y) => MExpr::var(y)
          None => MExpr::var(x)
        }
      })
    },
    lam_: fn(x, body_m, _e) {
      get_st().flat_map(fn(n : Int) {
        put_st(n + 1).flat_map(fn(_) {
          let x2 = "\{x}_\{n}"
          local_env(fn(env : Map[MVar, MVar]) {
            let e2 = env.copy()
            e2.set(x, x2)
            e2
          }, body_m).map(fn(body) { MExpr::lam(x2, body) })
        })
      })
    },
  }
  let e : MExpr = MExpr::lam("x", MExpr::lam("x", MExpr::var("x")))
  match e.rewrite_m(alg).exec({}, 0) {
    Ok((out, st, _)) => {
      debug_inspect(
        out,
        content=(
          #|MExpr(Lam("x_0", MExpr(Lam("x_1", MExpr(LambdaVar("x_1")), ())), ()))

        ),
      )
      debug_inspect(st, content="2")
    }
    Err(_) => panic()
  }
}

///|
/// --- Derived-language rewrite_m with ext constructors (True/False/If) ---
///
/// Proves the generated rewrite_m shape for a language whose `TreeExt` is a
/// real ext enum: the ext case expands into a nested `match te { ... }`.

///|
fn MTypedExpr::int(n : Int) -> MTypedExpr {
  MTypedExpr(Int(n))
}

///|
fn MTypedExpr::app(f : MTypedExpr, a : MTypedExpr) -> MTypedExpr {
  MTypedExpr(App(f, a))
}

///|
fn MTypedExpr::false_() -> MTypedExpr {
  MTypedExpr(Ext(False))
}

///|
struct MTypedRewriteAlg[Env, St, Log, Err] {
  int_ : (Int) -> PassM[Env, St, Log, Err, MTypedExpr]
  app_ : (
    PassM[Env, St, Log, Err, MTypedExpr],
    PassM[Env, St, Log, Err, MTypedExpr],
  ) -> PassM[Env, St, Log, Err, MTypedExpr]
  true_ : () -> PassM[Env, St, Log, Err, MTypedExpr]
  false_ : () -> PassM[Env, St, Log, Err, MTypedExpr]
  if_ : (
    PassM[Env, St, Log, Err, MTypedExpr],
    PassM[Env, St, Log, Err, MTypedExpr],
    PassM[Env, St, Log, Err, MTypedExpr],
  ) -> PassM[Env, St, Log, Err, MTypedExpr]
}

///|
fn[Env, St, Log, Err] MTypedRewriteAlg::identity() -> MTypedRewriteAlg[
  Env,
  St,
  Log,
  Err,
] {
  {
    int_: fn(n) { PassM::pure(MTypedExpr::int(n)) },
    app_: fn(f_m, a_m) {
      f_m.flat_map(fn(f) { a_m.map(fn(a) { MTypedExpr::app(f, a) }) })
    },
    true_: fn() { PassM::pure(MTypedExpr::true_()) },
    false_: fn() { PassM::pure(MTypedExpr::false_()) },
    if_: fn(c_m, t_m, e_m) {
      c_m.flat_map(fn(c) {
        t_m.flat_map(fn(t) { e_m.map(fn(e) { MTypedExpr::if_(c, t, e) }) })
      })
    },
  }
}

///|
fn[Env, St, Log, Err] MTypedExpr::rewrite_m(
  self : MTypedExpr,
  alg : MTypedRewriteAlg[Env, St, Log, Err],
) -> PassM[Env, St, Log, Err, MTypedExpr] {
  let MTypedExpr(t) = self
  match t {
    Int(n) => (alg.int_)(n)
    App(f, a) => (alg.app_)(f.rewrite_m(alg), a.rewrite_m(alg))
    Ext(te) =>
      match te {
        True => (alg.true_)()
        False => (alg.false_)()
        If(cond=cond, a1, a2) =>
          (alg.if_)(cond.rewrite_m(alg), a1.rewrite_m(alg), a2.rewrite_m(alg))
      }
    _ => abort("unhandled")
  }
}

///|
test "M3 golden: derived-language rewrite_m expands ext constructors" {
  let alg : MTypedRewriteAlg[Unit, Unit, String, String] = MTypedRewriteAlg::identity()
  let e = MTypedExpr::if_(
    MTypedExpr::true_(),
    MTypedExpr::int(1),
    MTypedExpr::int(0),
  )
  match e.rewrite_m(alg).exec_empty() {
    Ok((out, _, _)) =>
      debug_inspect(
        out,
        content=(
          #|MTypedExpr(Ext(If(cond=MTypedExpr(Ext(True)), MTypedExpr(Int(1)), MTypedExpr(Int(0)))))
        ),
      )
    Err(_) => panic()
  }
}

///|
/// --- M4 golden: Diff-driven minimal-coverage stub shape ---
///
/// A stub binds `identity()` once, then spreads it and re-lists ONLY the
/// changed/added constructors as identity placeholders for the user to fill in.
/// This proves the `let base = identity(); { ..base, f: base.f }` shape compiles.
fn[Env, St, Log, Err] mtyped_stub() -> MTypedRewriteAlg[Env, St, Log, Err] {
  let base = MTypedRewriteAlg::identity()
  // Overridable: true_/false_/if_ are the "added" ext constructors.
  MTypedRewriteAlg::{ ..base, true_: base.true_, false_: base.false_, if_: base.if_ }
}

///|
test "M4 golden: stub with identity placeholders round-trips" {
  let alg : MTypedRewriteAlg[Unit, Unit, String, String] = mtyped_stub()
  let e = MTypedExpr::if_(
    MTypedExpr::true_(),
    MTypedExpr::int(1),
    MTypedExpr::int(0),
  )
  match e.rewrite_m(alg).exec_empty() {
    Ok((out, _, _)) =>
      debug_inspect(
        out,
        content=(
          #|MTypedExpr(Ext(If(cond=MTypedExpr(Ext(True)), MTypedExpr(Int(1)), MTypedExpr(Int(0)))))
        ),
      )
    Err(_) => panic()
  }
}

