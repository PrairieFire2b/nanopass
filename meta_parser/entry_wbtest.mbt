///|
test "parse #nano.entry attribute" {
  let langs = find_languages_by_file("meta_parser/fixtures/entry_attrs.mbt")
  assert_eq(langs.length(), 1)
  guard langs[0].entry is Some("Type") else { fail("unexpected entry") }
  guard langs[0].nonterminals is [TypeDecl(_)] else {
    fail("expected external nonterminal entry candidate")
  }
}

///|
test "parse entry parameter from language attribute" {
  let langs = find_languages_by_file("meta_parser/fixtures/entry_param.mbt")
  assert_eq(langs.length(), 1)
  guard langs[0].entry is Some("Expr") else {
    fail("unexpected entry parameter")
  }
}
