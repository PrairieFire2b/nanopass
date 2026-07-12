///|
#nanopass.language(name="RmMissingBase")
enum Expr {
  Lit(Int)
  Add(Expr, Expr)
}

///|
#nanopass.language(name="RmMissingChild", extends="RmMissingBase")
#nano.remove("Nope")
enum Expr2 {
  Add(Expr2, Expr2)
}
