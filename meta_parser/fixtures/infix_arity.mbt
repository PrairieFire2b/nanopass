///|
#nanopass.language(name="BadInfix")
enum Expr {
  #nano.infix("+")
  Neg(Expr)
}
