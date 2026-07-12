///|
#nanopass.language(name="RmConflictBase")
enum Expr {
  Lit(Int)
  Add(Expr, Expr)
}

///|
#nanopass.language(name="RmConflictChild", extends="RmConflictBase")
#nano.remove("Add")
enum Expr2 {
  Add(Expr2, Expr2)
}
