///|
#nanopass.nonterminal
enum Type {
  Bool
}

///|
#nanopass.language(name="BaseExternal")
#nano.entry("Type")
enum Expr {
  Ann(Type)
}

///|
#nanopass.language(name="ChildExternal", extends="BaseExternal")
enum TypedExpr {
  True
}
