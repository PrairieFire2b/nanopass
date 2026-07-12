///|
#nanopass.language(name="HookBase")
enum HExpr {
  Num(Int)
  #nano.parse_by(parse_sym)
  #nano.unparse_by(unparse_sym)
  Sym(String)
  App(HExpr, HExpr)
}

///|
#nanopass.language(name="HookChild", extends="HookBase")
enum HExpr2 {
  Num(Int)
  Sym(String)
  App(HExpr2, HExpr2)
}
