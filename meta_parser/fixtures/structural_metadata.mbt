///|
#nanopass.language(name="StructuralMetadata")
enum Expr {
  #nano.name("lambda")
  #nano.parse_by(parse_lambda)
  #nano.unparse_by(unparse_lambda)
  #nano.inline
  Lambda(Expr, Expr)
}
