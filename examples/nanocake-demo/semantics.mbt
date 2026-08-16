// `ExprSemantics` and `cata` are the API shape emitted by `@pass.gen_semantics`.

///|
struct ExprSemantics[Repr] {
  int_ : (Int) -> Repr
  symbol_ : (String) -> Repr
  add_ : (Repr, Repr) -> Repr
  mul_ : (Repr, Repr) -> Repr
}

///|
fn[R] Expr::cata(self : Expr, semantics : ExprSemantics[R]) -> R {
  let Expr(tree) = self
  match tree {
    Int(value) => (semantics.int_)(value)
    Var(name) => (semantics.symbol_)(name)
    Add(left, right) =>
      (semantics.add_)(left.cata(semantics), right.cata(semantics))
    Mul(left, right) =>
      (semantics.mul_)(left.cata(semantics), right.cata(semantics))
  }
}

///|
fn fold_binary(
  left : Expr,
  right : Expr,
  operation : (Int, Int) -> Int,
  rebuild : (Expr, Expr) -> Expr,
) -> Expr {
  match (left, right) {
    (Expr(Int(a)), Expr(Int(b))) => Expr::int(operation(a, b))
    _ => rebuild(left, right)
  }
}

///|
fn constant_folder() -> ExprSemantics[Expr] {
  {
    int_: Expr::int,
    symbol_: Expr::symbol,
    add_: (left, right) => fold_binary(left, right, (a, b) => a + b, Expr::add),
    mul_: (left, right) => fold_binary(left, right, (a, b) => a * b, Expr::mul),
  }
}
