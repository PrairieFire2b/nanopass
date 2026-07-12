///|
#nanopass.language(name="FormBase")
enum FExpr {
  Num(Int)
  Var(String)
  #nano.form("(lambda $0 $1)")
  Lam(String, FExpr)
  #nano.inline
  App(FExpr, FExpr)
}

///|
#nanopass.language(name="FormChild", extends="FormBase")
enum FExpr2 {
  Num(Int)
  Var(String)
  #nano.form("(lambda $0 $1)")
  Lam(String, FExpr2)
  #nano.inline
  App(FExpr2, FExpr2)
}
