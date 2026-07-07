///|
#nanopass.language(name="FormOnlyInline")
enum Expr {
  #nano.form_only
  #nano.inline
  Box(Expr)
}
