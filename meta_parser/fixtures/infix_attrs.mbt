///|
#nanopass.language(name="InfixForms")
enum Expr {
  #nano.infix("+")
  Add(Expr, Expr)
}
