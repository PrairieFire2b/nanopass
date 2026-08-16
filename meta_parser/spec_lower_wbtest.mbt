///|
test "lower nano sidecar with plain MoonBit enums" {
  let languages = find_languages_by_spec_file(
    "meta_parser/fixtures/spec/lambda.cake",
  )
  assert_eq(languages.length(), 2)
  let language = languages[0]
  assert_eq(language.name, "Lambda")
  assert_eq(language.type_decl.tycon, "Expr")
  assert_true(language.resolved_entry is Some(_))
  assert_eq(language.meta_vars, [{ owner: "Expr", name: "LambdaVar" }])
  assert_eq(language.production_defs.length(), 4)
  guard language.production_defs[2].patterns
    is [
      ListPattern(
        [
          AtomPattern("lambda"),
          FieldPattern(index=0, ..),
          FieldPattern(index=1, ..),
        ]
      ),
    ] else {
    fail("unexpected Lam form")
  }
  assert_true(language.production_defs[3].canonical_policy is FormOnly)
  guard language.production_defs[3].surface_forms
    is [
      {
        origin: DeclaredForm,
        pattern: ListPattern(
          [FieldPattern(index=0, ..), FieldPattern(index=1, ..)]
        ),
      },
    ] else {
    fail("unexpected App forms")
  }
}

///|
test "reject unknown nano sidecar production" {
  try
    find_languages_by_spec_file(
      "meta_parser/fixtures/spec/unknown_production.cake",
    )
  catch {
    InvalidLanguage(message) =>
      assert_true(message.contains("unknown production"))
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected unknown production to fail")
  }
}
