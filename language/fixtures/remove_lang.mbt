///|
#nanopass.language(name="RemoveBase")
enum Expr {
  Lit(Int)
  Add(Expr, Expr)
  Neg(Expr)
}

///|
#nanopass.language(name="RemoveChild", extends="RemoveBase")
#nano.remove("Neg")
enum Expr2 {
  Add(Expr2, Expr2)
  Mul(Expr2, Expr2)
}
