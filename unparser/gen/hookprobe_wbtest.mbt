///|
test "probe hooks reach layout" {
  let lang = @language.Language::from_file(
    name="HookBase",
    path="language/fixtures/hook_lang.mbt",
    mod="YumeXi/nanocake",
  )
  let layout = lang.layout()
  let lines : Array[String] = []
  for cl in layout.constructors {
    let pb = match cl.hooks.parse_by {
      Some(h) => h
      None => "-"
    }
    let ub = match cl.hooks.unparse_by {
      Some(h) => h
      None => "-"
    }
    lines.push(
      "\{cl.source_tycon}.\{cl.constr_name}: pb=\{pb} ub=\{ub}",
    )
  }
  inspect(lines.join("\n"), content=(
    #|HExpr.Num: pb=- ub=-
    #|HExpr.Sym: pb=parse_sym ub=unparse_sym
    #|HExpr.App: pb=- ub=-
    #|HExpr2.Num: pb=- ub=-
    #|HExpr2.Sym: pb=- ub=-
    #|HExpr2.App: pb=- ub=-
  ))
}
