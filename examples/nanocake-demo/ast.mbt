// This wrapper-based AST is the shape emitted by nanocake's language generator.

///|
enum Tree[Self_] {
  Int(Int)
  Var(String)
  Add(Self_, Self_)
  Mul(Self_, Self_)
} derive(Eq, Debug)

///|
struct Expr(Tree[Expr]) derive(Eq, Debug)

///|
fn Expr::int(value : Int) -> Expr {
  Expr(Int(value))
}

///|
fn Expr::symbol(name : String) -> Expr {
  Expr(Var(name))
}

///|
fn Expr::add(left : Expr, right : Expr) -> Expr {
  Expr(Add(left, right))
}

///|
fn Expr::mul(left : Expr, right : Expr) -> Expr {
  Expr(Mul(left, right))
}
