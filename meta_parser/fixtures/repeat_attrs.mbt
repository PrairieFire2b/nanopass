///|
#nanopass.language(name="RepeatForms")
enum Expr {
  #nano.form("(begin $items ...)")
  Begin(items~ : Array[Expr])
  #nano.form("(tuple $0 ...)")
  Tuple(Array[Int])
}
