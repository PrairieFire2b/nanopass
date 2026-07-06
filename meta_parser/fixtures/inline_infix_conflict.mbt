///|
#nanopass.language(name="BadConflict")
enum Expr {
  #nano.inline
  #nano.infix("+")
  Add(Expr, Expr)
}
