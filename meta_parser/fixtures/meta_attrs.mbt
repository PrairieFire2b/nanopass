///|
#nanopass.nonterminal
#nano.meta("t")
enum Type {
  Bool
}

///|
#nanopass.language(name="MetaForms")
#nano.meta("e")
enum Expr {
  #nano.form("(ann $e0 : $t)")
  Ann(Expr, Type)
}
