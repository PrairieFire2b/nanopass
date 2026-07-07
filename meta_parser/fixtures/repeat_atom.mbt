///|
#nanopass.language(name="BadRepeatAtom")
enum Expr {
  #nano.form("(bad kw ...)")
  Bad(Array[Expr])
}
