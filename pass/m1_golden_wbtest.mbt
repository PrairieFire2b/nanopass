///|
/// Ground-truth fixture for M1 surface-API codegen.
///
/// This mirrors exactly what `Language::gen()` emits for the `Lambda` /
/// `SimplyTypedLambda` group (see `language/gen_wbtest.mbt`):
///
///   enum Tree[Self_, LamE, TreeExt] { Int(Int); LambdaVar(LambdaVar); ... }
///   struct Expr(Tree[Expr, Unit, Unit])
///   struct TypedExpr(Tree[TypedExpr, Type, TypedExprExt[TypedExpr]])
///   enum TypedExprExt[Self_] { True; False; If(...) }
///
/// The point of materialising it here is that pass-generated surface APIs
/// (smart constructors, `view()`) must actually COMPILE against these shapes,
/// not merely match a string snapshot. This file is the hand-written "golden"
/// target that the M1 generator must reproduce.

///|
typealias String as MVar

///|
enum MTree[Self_, LamE, TreeExt] {
  Int(Int)
  LambdaVar(MVar)
  Lam(MVar, Self_, LamE)
  App(Self_, Self_)
  Ext(TreeExt)
} derive(Debug)

///|
struct MExpr(MTree[MExpr, Unit, Unit]) derive(Debug)

///|
enum MTypedExt[Self_] {
  True
  False
  If(cond~ : Self_, Self_, Self_)
} derive(Debug)

///|
struct MTypedExpr(MTree[MTypedExpr, MType, MTypedExt[MTypedExpr]]) derive(Debug)

///|
enum MType {
  TBool
  TInt
} derive(Debug)

///|
/// --- Target smart constructors that M1 should generate for `MExpr` ---

///|
fn MExpr::int(n : Int) -> MExpr {
  MExpr(Int(n))
}

///|
fn MExpr::var(x : MVar) -> MExpr {
  MExpr(LambdaVar(x))
}

///|
fn MExpr::lam(x : MVar, body : MExpr) -> MExpr {
  MExpr(Lam(x, body, ()))
}

///|
fn MExpr::app(f : MExpr, a : MExpr) -> MExpr {
  MExpr(App(f, a))
}

///|
/// --- Target smart constructors for `MTypedExpr` incl. ext constructors ---

///|
fn MTypedExpr::true_() -> MTypedExpr {
  MTypedExpr(Ext(True))
}

///|
fn MTypedExpr::if_(
  c : MTypedExpr,
  t : MTypedExpr,
  e : MTypedExpr,
) -> MTypedExpr {
  MTypedExpr(Ext(If(cond=c, t, e)))
}

///|
/// Golden for labelled-field view case: destructure `If(cond~, a1, a2)` and
/// rebuild referencing the SAME names. This is the shape the generator must
/// emit for constructors with labelled parameters.
enum MTypedView {
  MVIf(MTypedExpr, MTypedExpr, MTypedExpr)
  MVOther
} derive(Debug)

///|
fn MTypedExpr::view_probe(self : MTypedExpr) -> MTypedView {
  let MTypedExpr(t) = self
  match t {
    Ext(te) =>
      match te {
        If(cond~, a1, a2) => MVIf(cond, a1, a2)
        _ => MVOther
      }
    _ => MVOther
  }
}

///|
test "M1 golden: labelled ext field destructure and rebuild" {
  let e = MTypedExpr::if_(
    MTypedExpr::true_(),
    MTypedExpr(Int(1)),
    MTypedExpr(Int(0)),
  )
  match e.view_probe() {
    MVIf(c, _, _) => debug_inspect(c, content="MTypedExpr(Ext(True))")
    MVOther => panic()
  }
}

///|
test "M1 golden: smart constructors build wrapped Tree values" {
  let e = MExpr::app(MExpr::lam("x", MExpr::var("x")), MExpr::int(5))
  debug_inspect(
    e,
    content=(
      #|MExpr(App(MExpr(Lam("x", MExpr(LambdaVar("x")), ())), MExpr(Int(5))))
    ),
  )
}

///|
test "M1 golden: ext smart constructors build Ext-wrapped values" {
  let e = MTypedExpr::if_(
    MTypedExpr::true_(),
    MTypedExpr(Int(1)),
    MTypedExpr(Int(0)),
  )
  debug_inspect(
    e,
    content=(
      #|MTypedExpr(Ext(If(cond=MTypedExpr(Ext(True)), MTypedExpr(Int(1)), MTypedExpr(Int(0)))))
    ),
  )
}

///|
/// --- Target `view()` flat enum + accessor that M1 should generate ---
///
/// `view()` flattens `Wrapper(Tree(...))` and `Wrapper(Tree(Ext(...)))` into a
/// single flat enum so pass authors never match on the nested `Tree`/`Ext`
/// structure directly.

///|
enum MExprView {
  VInt(Int)
  VVar(MVar)
  VLam(MVar, MExpr)
  VApp(MExpr, MExpr)
} derive(Debug)

///|
fn MExpr::view(self : MExpr) -> MExprView {
  let MExpr(t) = self
  match t {
    Int(n) => VInt(n)
    LambdaVar(x) => VVar(x)
    Lam(x, body, _) => VLam(x, body)
    App(f, a) => VApp(f, a)
    Ext(_) => abort("MExpr has no ext constructors")
  }
}

///|
test "M1 golden: view() flattens wrapped Tree into a flat enum" {
  let e = MExpr::lam("x", MExpr::app(MExpr::var("x"), MExpr::int(3)))
  match e.view() {
    VLam(x, _) => debug_inspect(x, content="\"x\"")
    _ => panic()
  }
}

///|
/// --- Target catamorphism form that M1's construction-form fix must support ---
///
/// This is the shape `gen_semantics` must emit against a tuple-struct wrapper:
/// destructure with `let MExpr(t) = self`, then rebuild via smart constructors.

///|
struct MExprSem[R] {
  int_ : (Int) -> R
  var_ : (MVar) -> R
  lam_ : (MVar, R) -> R
  app_ : (R, R) -> R
}

///|
fn[R] MExpr::cata(self : MExpr, s : MExprSem[R]) -> R {
  let MExpr(t) = self
  match t {
    Int(n) => (s.int_)(n)
    LambdaVar(x) => (s.var_)(x)
    Lam(x, body, _) => (s.lam_)(x, body.cata(s))
    App(f, a) => (s.app_)(f.cata(s), a.cata(s))
    Ext(_) => abort("MExpr has no ext constructors")
  }
}

///|
test "M1 golden: cata folds over wrapped Tree via let-destructure" {
  // Count the number of Int/Var leaves.
  let count_leaves : MExprSem[Int] = {
    int_: fn(_) { 1 },
    var_: fn(_) { 1 },
    lam_: fn(_, b) { b },
    app_: fn(f, a) { f + a },
  }
  let e = MExpr::app(MExpr::lam("x", MExpr::var("x")), MExpr::int(5))
  inspect(e.cata(count_leaves), content="2")
}
