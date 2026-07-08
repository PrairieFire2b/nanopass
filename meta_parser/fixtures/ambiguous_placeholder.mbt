///|
#nanopass.language(name="BadPlaceholder")
#nano.meta("x")
enum Expr {
  #nano.form("(bad $x)")
  Bad(x~ : Expr)
}
