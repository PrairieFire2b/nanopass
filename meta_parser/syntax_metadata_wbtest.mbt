///|
test "parse syntax layer and context metadata" {
  let langs = find_languages_by_file(
    "meta_parser/fixtures/layer_context_attrs.mbt",
  )
  assert_eq(langs.length(), 1)
  guard langs[0].layer is Some(SurfaceLayer) else {
    fail("expected surface layer")
  }
  let defs = langs[0].production_defs
  assert_eq(defs.length(), 1)
  assert_eq(defs[0].contexts.length(), 1)
  assert_eq(defs[0].contexts[0].name, "term")
}

///|
test "validate syntax metadata rejects unknown layer" {
  try find_languages_by_file("meta_parser/fixtures/unknown_layer.mbt") catch {
    InvalidAttribute(message) =>
      inspect(message, content="Unknown #nano.layer 'namespace'")
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected unknown layer error")
  }
}

///|
test "validate syntax metadata rejects duplicate context" {
  try
    find_languages_by_file("meta_parser/fixtures/duplicate_context.mbt")
  catch {
    InvalidLanguage(message) =>
      inspect(
        message,
        content="Production 'Expr.Bad' declares #nano.context 'term' more than once",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected duplicate context error")
  }
}
