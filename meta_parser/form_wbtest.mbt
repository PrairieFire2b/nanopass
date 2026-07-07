///|
test "compile #nano.form atoms fields and lists" {
  let pattern = compile_form_pattern("(if $0 x=$name $0:)")
  guard pattern
    is ListPattern(
      [
        AtomPattern("if"),
        FieldPattern(index=0, prefix="", suffix=""),
        NamedFieldPattern(name="name", prefix="x=", suffix=""),
        FieldPattern(index=0, prefix="", suffix=":"),
      ]
    ) else {
    fail("unexpected compiled form pattern")
  }
}

///|
test "compile #nano.form nested list" {
  let pattern = compile_form_pattern("(lambda ($x : $t) $body)")
  guard pattern
    is ListPattern(
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
    ) else {
    fail("unexpected nested form pattern")
  }
}

///|
test "compile #nano.form ellipsis repeat" {
  let pattern = compile_form_pattern("(begin $items ...)")
  guard pattern
    is ListPattern(
      [
        AtomPattern("begin"),
        RepeatPattern(NamedFieldPattern(name="items", prefix="", suffix="")),
      ]
    ) else {
    fail("unexpected repeated form pattern")
  }
}

///|
test "compile #nano.form rejects trailing tokens" {
  try compile_form_pattern("$0 $1") catch {
    InvalidAttribute(_) => ()
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected invalid form pattern")
  }
}

///|
test "compile #nano.form rejects bare ellipsis" {
  try compile_form_pattern("(...)") catch {
    InvalidAttribute(message) =>
      inspect(
        message,
        content="Ellipsis must follow a pattern in #nano.form pattern",
      )
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("expected invalid ellipsis")
  }
}
