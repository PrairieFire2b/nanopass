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
