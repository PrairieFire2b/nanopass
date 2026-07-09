///|
test "validate language definitions rejects duplicate names" {
  try
    find_languages_by_file("meta_parser/fixtures/duplicate_language.mbt")
  catch {
    InvalidLanguage(message) =>
      inspect(message, content="Duplicate language definition 'Repeated'")
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected duplicate language error")
  }
}

///|
test "validate language definitions rejects unknown parent" {
  try find_languages_by_file("meta_parser/fixtures/unknown_parent.mbt") catch {
    InvalidLanguage(message) =>
      inspect(
        message,
        content="Language 'Child' extends unknown language 'Missing'",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected unknown parent error")
  }
}

///|
test "parse language layer parameters" {
  let langs = find_languages_by_file("meta_parser/fixtures/layer_attrs.mbt")
  assert_eq(langs.length(), 2)
  guard langs[0].layer is Some("surface") else { fail("unexpected base layer") }
  guard langs[1].extends is Some("LayerBase") else {
    fail("unexpected derived parent")
  }
  guard langs[1].layer is Some("typed-core") else {
    fail("unexpected derived layer")
  }
}

///|
test "parse #nano.lang layer parameter" {
  let langs = find_languages_by_file("meta_parser/fixtures/nano_lang_attr.mbt")
  assert_eq(langs.length(), 2)
  assert_eq(langs[0].name, "NanoLayer")
  guard langs[0].layer is Some("datum") else {
    fail("unexpected nano lang layer")
  }
  guard langs[1].extends is Some("NanoLayer") else {
    fail("unexpected nano lang parent")
  }
  guard langs[1].layer is Some("surface") else {
    fail("unexpected nano lang child layer")
  }
}

///|
test "validate language definitions rejects empty layer" {
  try find_languages_by_file("meta_parser/fixtures/empty_layer.mbt") catch {
    InvalidLanguage(message) =>
      inspect(message, content="Language 'BadLayer' layer cannot be empty")
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected empty layer error")
  }
}

///|
test "validate form patterns rejects out of range field references" {
  try
    find_languages_by_file("meta_parser/fixtures/form_field_out_of_range.mbt")
  catch {
    InvalidLanguage(message) =>
      inspect(
        message,
        content="Production 'BadForm.Bad' references field $1 but only has 1 fields",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected invalid form field reference")
  }
}

///|
test "validate language definitions rejects unknown entry" {
  try find_languages_by_file("meta_parser/fixtures/unknown_entry.mbt") catch {
    InvalidLanguage(message) =>
      inspect(
        message,
        content="Language 'BadEntry' entry 'Missing' is not a known nonterminal (candidates: Expr)",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected unknown entry error")
  }
}

///|
test "validate production attrs rejects form_only without form or hook" {
  try
    find_languages_by_file("meta_parser/fixtures/form_only_without_form.mbt")
  catch {
    InvalidLanguage(message) =>
      inspect(
        message,
        content="Production 'BadFormOnly.Bad' uses #nano.form_only but has no #nano.form or hook",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected form_only error")
  }
}

///|
test "validate production attrs accepts form_only inline surface form" {
  let langs = find_languages_by_file(
    "meta_parser/fixtures/form_only_inline.mbt",
  )
  assert_eq(langs.length(), 1)
  let forms = langs[0].production_defs[0].surface_forms
  assert_eq(forms.length(), 1)
  assert_true(forms[0].origin is InlineForm)
}

///|
test "validate production attrs rejects inline infix conflict" {
  try
    find_languages_by_file("meta_parser/fixtures/inline_infix_conflict.mbt")
  catch {
    InvalidLanguage(message) =>
      inspect(
        message,
        content="Production 'BadConflict.Add' cannot combine #nano.inline and #nano.infix",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected inline/infix conflict error")
  }
}

///|
test "validate production attrs rejects invalid infix arity" {
  try find_languages_by_file("meta_parser/fixtures/infix_arity.mbt") catch {
    InvalidLanguage(message) =>
      inspect(
        message,
        content="Production 'BadInfix.Neg' uses #nano.infix but has 1 fields",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected infix arity error")
  }
}

///|
test "validate production attrs rejects empty infix payload" {
  try find_languages_by_file("meta_parser/fixtures/infix_empty.mbt") catch {
    InvalidAttribute(message) =>
      inspect(
        message,
        content="#nano.infix expects a non-empty string literal payload",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected empty infix payload error")
  }
}

///|
test "validate production attrs rejects empty context payload" {
  try find_languages_by_file("meta_parser/fixtures/context_empty.mbt") catch {
    InvalidAttribute(message) =>
      inspect(
        message,
        content="#nano.context expects a non-empty string literal payload",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected empty context payload error")
  }
}

///|
test "validate meta vars rejects duplicate owner declarations" {
  try find_languages_by_file("meta_parser/fixtures/duplicate_meta.mbt") catch {
    InvalidLanguage(message) =>
      inspect(message, content="Duplicate meta-var 'e' for owner 'Expr'")
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected duplicate meta-var error")
  }
}

///|
test "validate form patterns rejects undeclared meta vars" {
  try find_languages_by_file("meta_parser/fixtures/unknown_meta.mbt") catch {
    InvalidLanguage(message) =>
      inspect(
        message,
        content="Production 'BadMeta.Bad' references undeclared meta-var '$e0'",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected unknown meta-var error")
  }
}

///|
test "validate form patterns rejects ambiguous named placeholders" {
  try
    find_languages_by_file("meta_parser/fixtures/ambiguous_placeholder.mbt")
  catch {
    InvalidLanguage(message) =>
      inspect(
        message,
        content="Production 'BadPlaceholder.Bad' references '$x' ambiguously as both constructor field and meta-var '$x'",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected ambiguous placeholder error")
  }
}

///|
test "validate generated names reject hook collisions" {
  try
    find_languages_by_file("meta_parser/fixtures/generated_name_collision.mbt")
  catch {
    InvalidLanguage(message) =>
      inspect(
        message,
        content="Production 'Collision.Bad' parse hook 'parse_Collision' collides with generated name for language 'Collision'",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected generated name collision error")
  }
}

///|
test "validate field types rejects unknown nested type references" {
  try
    find_languages_by_file("meta_parser/fixtures/unknown_field_type.mbt")
  catch {
    InvalidLanguage(message) =>
      inspect(
        message,
        content="Production 'BadFieldType.Bad' field $0 has unknown type 'Missing'",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected unknown field type error")
  }
}

///|
test "validate form patterns rejects repeated non array fields" {
  try
    find_languages_by_file("meta_parser/fixtures/repeat_non_array.mbt")
  catch {
    InvalidLanguage(message) =>
      inspect(
        message,
        content="Production 'BadRepeat.Bad' repeats $item but field type is 'Expr', expected Array",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected repeated non-array field error")
  }
}

///|
test "validate form patterns rejects repeated unbound named placeholders" {
  try
    find_languages_by_file("meta_parser/fixtures/repeat_unknown_label.mbt")
  catch {
    InvalidLanguage(message) =>
      inspect(
        message,
        content="Production 'BadRepeatLabel.Bad' repeats '$e' but it is not a constructor field label",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected repeated unknown label error")
  }
}

///|
test "validate form patterns rejects repeated non field patterns" {
  try find_languages_by_file("meta_parser/fixtures/repeat_atom.mbt") catch {
    InvalidLanguage(message) =>
      inspect(
        message,
        content="Production 'BadRepeatAtom.Bad' repeats <pattern> but only constructor fields can use ellipsis",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected repeated non-field pattern error")
  }
}
