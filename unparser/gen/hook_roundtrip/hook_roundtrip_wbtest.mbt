// Real compiled + executed roundtrip tests for `#nano.parse_by` / `#nano.unparse_by`.

///|
fn rt(text : String) -> Unit raise {
  let value = HExpr::parse_sexp(text)
  let back = value.unparse_sexp()
  let reparsed = HExpr::parse_sexp(back)
  assert_eq(value, reparsed)
}

///|
test "hook-driven surface syntax roundtrips" {
  rt("42")
  rt("@foo")
  rt("(App @f @x)")
  rt("(App @f (App @g @x))")
  rt("(App 42 @bar)")
}

///|
test "hooks produce the intended surface syntax" {
  // `@name` parses through the hook to `Sym(name)`, unparses back to `@name`.
  let sym = HExpr::parse_sexp("@foo")
  assert_eq(sym, HExpr(Tree::Sym("foo")))
  inspect(sym.unparse_sexp(), content="@foo")

  // Canonical `foo` (bare string atom) is also accepted as Sym via string_from_atom,
  // and unparses via the hook as `@foo`.
  let sym2 = HExpr::parse_sexp("foo")
  assert_eq(sym2, HExpr(Tree::Sym("foo")))
  inspect(sym2.unparse_sexp(), content="@foo")

  // App with hook-driven children.
  let app = HExpr::parse_sexp("(App @f @x)")
  inspect(app.unparse_sexp(), content="(App @f @x)")
}

///|
test "parse hook failure surfaces as a structured error" {
  // `@` with an empty name: the hook raises a decode error.
  let failed = try {
    let _ = HExpr::parse_sexp("@")
    None
  } catch {
    e => Some(e)
  }
  match failed {
    Some(_) => ()
    None => fail("expected a hook error for '@'")
  }
}
