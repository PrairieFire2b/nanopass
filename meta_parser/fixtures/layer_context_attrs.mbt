///|
#nanopass.language(name="TypedSurface", entry="Expr")
#nano.layer("surface")
enum Expr {
  #nano.context("term")
  #nano.form("(lambda $body)")
  Lambda(body~ : Expr)
}
