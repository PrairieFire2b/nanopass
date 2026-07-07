///|
#nanopass.language(name="BadInfixPayload")
enum Expr {
  #nano.infix("")
  Add(Expr, Expr)
}
