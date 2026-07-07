///|
#nanopass.language(name="BadRepeat")
enum Expr {
  #nano.form("(bad $item ...)")
  Bad(item~ : Expr)
}
