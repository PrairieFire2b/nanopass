///|
#nanopass.language(name="ContextForms", layer="surface")
enum Expr {
  #nano.context("expression")
  #nano.form("(quote $0)")
  Quote(Int)

  #nano.context("expression")
  #nano.context("body")
  #nano.form("(begin $items ...)")
  Begin(items~ : Array[Expr])
}
