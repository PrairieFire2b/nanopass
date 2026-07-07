///|
test "parse constructor form attributes into production defs" {
  let langs = find_languages_by_file("meta_parser/fixtures/form_attrs.mbt")
  assert_eq(langs.length(), 1)
  let defs = langs[0].production_defs
  assert_eq(defs.length(), 3)
  assert_eq(defs[0].owner, "Expr")
  assert_eq(defs[0].constr_name, "Lit")
  assert_eq(defs[0].fields.length(), 1)
  guard defs[0].canonical_policy is Canonical else {
    fail("unexpected canonical policy")
  }
  guard defs[0].patterns
    is [
      ListPattern(
        [AtomPattern("lit"), FieldPattern(index=0, prefix="", suffix="")]
      ),
    ] else {
    fail("unexpected Lit production pattern")
  }
  guard defs[1].patterns
    is [
      ListPattern(
        [
          AtomPattern("if"),
          FieldPattern(index=0, prefix="", suffix=""),
          FieldPattern(index=1, prefix="", suffix=""),
          FieldPattern(index=2, prefix="", suffix=""),
        ]
      ),
    ] else {
    fail("unexpected If production pattern")
  }
  guard defs[2].fields[0].label is Some("x") else {
    fail("expected labeled x field")
  }
  guard defs[2].fields[1].label is Some("t") else {
    fail("expected labeled t field")
  }
  guard defs[2].fields[2].label is Some("body") else {
    fail("expected labeled body field")
  }
  guard defs[2].patterns
    is [
      ListPattern(
        [
          AtomPattern("lambda"),
          ListPattern(
            [
              NamedFieldPattern(name="x", prefix="", suffix=""),
              AtomPattern(":"),
              NamedFieldPattern(name="t", prefix="", suffix=""),
            ]
          ),
          NamedFieldPattern(name="body", prefix="", suffix=""),
        ]
      ),
    ] else {
    fail("unexpected Lam production pattern")
  }
}

///|
test "parse ellipsis form attributes into repeat patterns" {
  let langs = find_languages_by_file("meta_parser/fixtures/repeat_attrs.mbt")
  assert_eq(langs.length(), 1)
  let defs = langs[0].production_defs
  assert_eq(defs.length(), 2)
  guard defs[0].fields[0].label is Some("items") else {
    fail("expected items field label")
  }
  assert_eq(defs[0].fields[0].type_name, "Array")
  guard defs[0].patterns
    is [
      ListPattern(
        [
          AtomPattern("begin"),
          RepeatPattern(NamedFieldPattern(name="items", prefix="", suffix="")),
        ]
      ),
    ] else {
    fail("unexpected Begin repeat pattern")
  }
  guard defs[1].patterns
    is [
      ListPattern(
        [
          AtomPattern("tuple"),
          RepeatPattern(FieldPattern(index=0, prefix="", suffix="")),
        ]
      ),
    ] else {
    fail("unexpected Tuple repeat pattern")
  }
}
