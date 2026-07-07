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
