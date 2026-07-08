///|
#nanopass.language(name="BaseEntry")
enum Expr {
  Lit(Int)
}

///|
#nanopass.language(name="ChildEntry", extends="BaseEntry")
#nano.entry("TypedExpr")
enum TypedExpr {
  True
}
