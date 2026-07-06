///|
fn has_meta_var(
  vars : Array[MetaVarDecl],
  owner : String,
  name : String,
) -> Bool {
  vars.any(meta_var => meta_var.owner == owner && meta_var.name == name)
}

///|
test "parse #nano.meta declarations" {
  let langs = find_languages_by_file("meta_parser/fixtures/meta_attrs.mbt")
  assert_eq(langs.length(), 1)
  let vars = langs[0].meta_vars
  assert_eq(vars.length(), 2)
  assert_true(has_meta_var(vars, "Expr", "e"))
  assert_true(has_meta_var(vars, "Type", "t"))
}
