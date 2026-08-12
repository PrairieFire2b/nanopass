///|
/// M2: pure fold usage patterns via generated `cata` + `identity`.
///
/// These are the recommended shapes for ANALYSIS passes: no effects, just a
/// fold algebra `Sem[R]` where `R` is the analysis result. `identity()` is not
/// needed here (that is for transforms); analysis overrides every field with
/// the analysis semantics.
///
/// Two canonical examples, both compilable:
///   1. free-variable collection  (R = Map[MVar, Unit] used as a set) on MExpr
///   2. existence check           (R = Bool) over ext constructors on MTypedExpr
///
/// Reuses `MExpr` / `MExprSem` / `MTypedExpr` from the golden fixtures.

///|
/// 1. Free-variable collection: fold to the set of free variables.
///    Var contributes {x}; Lam(x, body) removes x from body's set.
test "M2 fold: free-variable collection over MExpr" {
  let free_vars : MExprSem[Map[MVar, Unit]] = {
    int_: fn(_) { {} },
    var_: fn(x) {
      let s : Map[MVar, Unit] = {}
      s.set(x, ())
      s
    },
    lam_: fn(x, body) {
      let s = body.copy()
      s.remove(x)
      s
    },
    app_: fn(f, a) {
      let s = f.copy()
      a.each(fn(v, _) { s.set(v, ()) })
      s
    },
  }
  // (\x. x) y  -- free vars: {y}
  let e = MExpr::app(MExpr::lam("x", MExpr::var("x")), MExpr::var("y"))
  let fv = e.cata(free_vars)
  inspect(fv.contains("x"), content="false")
  inspect(fv.contains("y"), content="true")
  inspect(fv.size(), content="1")
}

///|
/// A fold algebra over MTypedExpr, including ext constructors. This mirrors what
/// `gen_semantics` emits: ext constructors are flat top-level fields.
struct MTypedSem[R] {
  int_ : (Int) -> R
  var_ : (MVar) -> R
  lam_ : (MVar, MType, R) -> R
  app_ : (R, R) -> R
  true_ : () -> R
  false_ : () -> R
  if_ : (R, R, R) -> R
}

///|
fn[R] MTypedExpr::cata(self : MTypedExpr, s : MTypedSem[R]) -> R {
  let MTypedExpr(t) = self
  match t {
    Int(n) => (s.int_)(n)
    LambdaVar(x) => (s.var_)(x)
    Lam(x, body, ty) => (s.lam_)(x, ty, body.cata(s))
    App(f, a) => (s.app_)(f.cata(s), a.cata(s))
    Ext(te) =>
      match te {
        True => (s.true_)()
        False => (s.false_)()
        If(cond~, a1, a2) => (s.if_)(cond.cata(s), a1.cata(s), a2.cata(s))
      }
  }
}

///|
/// 2. Existence check: does the tree contain a `True` literal?
///    Pure boolean algebra; only `true_` returns true, everything else ORs
///    its children.
test "M2 fold: existence check (contains True) over MTypedExpr" {
  let has_true : MTypedSem[Bool] = {
    int_: fn(_) { false },
    var_: fn(_) { false },
    lam_: fn(_, _, b) { b },
    app_: fn(f, a) { f || a },
    true_: fn() { true },
    false_: fn() { false },
    if_: fn(c, t, e) { c || t || e },
  }
  // if (false) then 1 else true  -- contains True in the else branch
  let e1 = MTypedExpr::if_(
    MTypedExpr::false_(),
    MTypedExpr::int(1),
    MTypedExpr::true_(),
  )
  inspect(e1.cata(has_true), content="true")
  // app(1, 0)  -- no True anywhere
  let e2 = MTypedExpr::app(MTypedExpr::int(1), MTypedExpr::int(0))
  inspect(e2.cata(has_true), content="false")
}
