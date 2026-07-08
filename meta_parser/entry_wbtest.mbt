///|
fn expect_resolved_entry(lang : NanoLangDef) -> ResolvedEntry raise {
  match lang.resolved_entry {
    Some(entry) => entry
    None => fail("expected resolved entry")
  }
}

///|
test "parse #nano.entry attribute" {
  let langs = find_languages_by_file("meta_parser/fixtures/entry_attrs.mbt")
  assert_eq(langs.length(), 1)
  guard langs[0].entry is Some("Type") else { fail("unexpected entry") }
  guard langs[0].nonterminals is [TypeDecl(_)] else {
    fail("expected external nonterminal entry candidate")
  }
  let resolved = expect_resolved_entry(langs[0])
  assert_true(resolved.origin is ExplicitEntry)
  assert_eq(resolved.target.name, "Type")
  assert_eq(resolved.target.introduced_by, "WithEntry")
  assert_true(resolved.target.kind is ExternalNonTerminal)
}

///|
test "parse entry parameter from language attribute" {
  let langs = find_languages_by_file("meta_parser/fixtures/entry_param.mbt")
  assert_eq(langs.length(), 1)
  guard langs[0].entry is Some("Expr") else {
    fail("unexpected entry parameter")
  }
  let resolved = expect_resolved_entry(langs[0])
  assert_true(resolved.origin is ExplicitEntry)
  assert_eq(resolved.target.name, "Expr")
  assert_true(resolved.target.kind is RootNonTerminal)
}

///|
test "resolve default entry to root nonterminal" {
  let langs = find_languages_by_file("meta_parser/fixtures/entry_default.mbt")
  assert_eq(langs.length(), 1)
  guard langs[0].entry is None else { fail("unexpected explicit entry") }
  let resolved = expect_resolved_entry(langs[0])
  assert_true(resolved.origin is DefaultEntry)
  assert_eq(resolved.target.name, "Expr")
  assert_eq(resolved.target.introduced_by, "DefaultEntry")
  assert_true(resolved.target.kind is RootNonTerminal)
}

///|
test "resolve derived entry by inheriting parent entry" {
  let langs = find_languages_by_file("meta_parser/fixtures/entry_inherit.mbt")
  assert_eq(langs.length(), 2)
  let resolved = expect_resolved_entry(langs[1])
  guard resolved.origin is InheritedEntry("BaseEntry") else {
    fail("expected inherited entry")
  }
  assert_eq(resolved.target.name, "Expr")
  assert_eq(resolved.target.introduced_by, "BaseEntry")
  assert_true(resolved.target.kind is InheritedNonTerminal)
}

///|
test "resolve child entry override to child root" {
  let langs = find_languages_by_file("meta_parser/fixtures/entry_override.mbt")
  assert_eq(langs.length(), 2)
  guard langs[1].entry is Some("TypedExpr") else {
    fail("unexpected child entry")
  }
  let resolved = expect_resolved_entry(langs[1])
  assert_true(resolved.origin is ExplicitEntry)
  assert_eq(resolved.target.name, "TypedExpr")
  assert_eq(resolved.target.introduced_by, "ChildEntry")
  assert_true(resolved.target.kind is RootNonTerminal)
}

///|
test "resolve inherited external entry" {
  let langs = find_languages_by_file(
    "meta_parser/fixtures/entry_inherit_external.mbt",
  )
  assert_eq(langs.length(), 2)
  let resolved = expect_resolved_entry(langs[1])
  guard resolved.origin is InheritedEntry("BaseExternal") else {
    fail("expected inherited external entry")
  }
  assert_eq(resolved.target.name, "Type")
  assert_eq(resolved.target.introduced_by, "BaseExternal")
  assert_true(resolved.target.kind is InheritedNonTerminal)
}
