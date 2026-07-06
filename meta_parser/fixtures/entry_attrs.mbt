///|
#nanopass.nonterminal
enum Type {
  Bool
}

///|
#nanopass.language(name="WithEntry")
#nano.entry("Type")
enum Expr {
  Ann(Type)
}
