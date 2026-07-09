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
test "normalize declared and canonical surface form rules" {
  let langs = find_languages_by_file("meta_parser/fixtures/form_attrs.mbt")
  assert_eq(langs.length(), 1)
  let defs = langs[0].production_defs
  let forms = defs[0].surface_forms
  assert_eq(forms.length(), 2)
  assert_true(forms[0].origin is DeclaredForm)
  guard forms[0].pattern
    is ListPattern(
      [AtomPattern("lit"), FieldPattern(index=0, prefix="", suffix="")]
    ) else {
    fail("unexpected declared Lit surface form")
  }
  assert_true(forms[1].origin is CanonicalForm)
  guard forms[1].pattern
    is ListPattern(
      [AtomPattern("Lit"), FieldPattern(index=0, prefix="", suffix="")]
    ) else {
    fail("unexpected canonical Lit surface form")
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

///|
test "parse infix attributes into production defs" {
  let langs = find_languages_by_file("meta_parser/fixtures/infix_attrs.mbt")
  assert_eq(langs.length(), 1)
  let defs = langs[0].production_defs
  assert_eq(defs.length(), 1)
  guard defs[0].infix_operator is Some("+") else {
    fail("expected infix operator")
  }
  let forms = defs[0].surface_forms
  assert_eq(forms.length(), 2)
  assert_true(forms[0].origin is CanonicalForm)
  assert_true(forms[1].origin is InfixForm)
  guard forms[1].pattern
    is ListPattern(
      [
        FieldPattern(index=0, prefix="", suffix=""),
        AtomPattern("+"),
        FieldPattern(index=1, prefix="", suffix=""),
      ]
    ) else {
    fail("unexpected infix surface form")
  }
}

///|
test "parse structural production metadata" {
  let langs = find_languages_by_file(
    "meta_parser/fixtures/structural_metadata.mbt",
  )
  assert_eq(langs.length(), 1)
  let defs = langs[0].production_defs
  assert_eq(defs.length(), 1)
  guard defs[0].name_alias is Some("lambda") else {
    fail("expected name alias")
  }
  guard defs[0].hooks.parse_by is Some("parse_lambda") else {
    fail("expected parse hook")
  }
  guard defs[0].hooks.unparse_by is Some("unparse_lambda") else {
    fail("expected unparse hook")
  }
  assert_true(defs[0].inline)
  let forms = defs[0].surface_forms
  assert_eq(forms.length(), 3)
  assert_true(forms[0].origin is NameAliasForm)
  guard forms[0].pattern
    is ListPattern(
      [
        AtomPattern("lambda"),
        FieldPattern(index=0, prefix="", suffix=""),
        FieldPattern(index=1, prefix="", suffix=""),
      ]
    ) else {
    fail("unexpected name alias surface form")
  }
  assert_true(forms[1].origin is CanonicalForm)
  guard forms[1].pattern
    is ListPattern(
      [
        AtomPattern("Lambda"),
        FieldPattern(index=0, prefix="", suffix=""),
        FieldPattern(index=1, prefix="", suffix=""),
      ]
    ) else {
    fail("unexpected canonical Lambda surface form")
  }
  assert_true(forms[2].origin is InlineForm)
  guard forms[2].pattern
    is ListPattern(
      [
        FieldPattern(index=0, prefix="", suffix=""),
        FieldPattern(index=1, prefix="", suffix=""),
      ]
    ) else {
    fail("unexpected inline surface form")
  }
}

///|
test "parse production context attributes" {
  let langs = find_languages_by_file("meta_parser/fixtures/context_attrs.mbt")
  assert_eq(langs.length(), 1)
  guard langs[0].layer is Some("surface") else {
    fail("unexpected language layer")
  }
  let defs = langs[0].production_defs
  assert_eq(defs.length(), 2)
  debug_inspect(
    defs.map(def => "\{def.constr_name}:\{def.contexts.join(",")}"),
    content=(
      #|["Quote:expression", "Begin:expression,body"]
    ),
  )
}
