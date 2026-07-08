///|
#nanopass.language(name="BaseEntry")
enum Expr {
  Lit(Int)
}

///|
#nanopass.language(name="ChildEntry", extends="BaseEntry")
enum TypedExpr {
  True
}
