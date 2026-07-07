///|
#nanopass.language(name="BadRepeatLabel")
#nano.meta("e")
enum Expr {
  #nano.form("(bad $e ...)")
  Bad(items~ : Array[Expr])
}
