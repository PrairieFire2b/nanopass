///|
#nanopass.language(name="Forms")
enum Expr {
  #nano.form("(lit $0)")
  Lit(Int)
  #nano.form("(if $0 $1 $2)")
  If(Expr, Expr, Expr)
  #nano.form("(lambda ($x : $t) $body)")
  Lam(String, String, Expr)
}
