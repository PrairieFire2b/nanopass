///|
#nanopass.language(name="LayerBase", layer="surface")
enum Expr {
  Lit(Int)
}

///|
#nanopass.language(name="LayerTyped", extends="LayerBase", layer="typed-core")
enum TypedExpr {
  TypedLit(Int, String)
}
