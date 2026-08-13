// Real compiled + executed roundtrip tests for custom surface forms.

///|
fn rt(text : String) -> Unit raise {
  let value = FExpr::parse_sexp(text)
  let back = value.unparse_sexp()
  let reparsed = FExpr::parse_sexp(back)
  assert_eq(value, reparsed)
}

///|
test "custom #nano.form and #nano.inline roundtrip" {
  rt("42")
  rt("x")
  rt("(lambda x x)")
  rt("(lambda f (lambda x (f x)))")
  rt("(x y)")
  rt("(lambda f (f (f x)))")
}

///|
test "custom forms produce the intended surface syntax" {
  // `Lam` unparses via `#nano.form("(lambda $0 $1)")`
  let lam = FExpr::parse_sexp("(lambda x x)")
  inspect(lam.unparse_sexp(), content="(lambda x x)")
  // `App` unparses via `#nano.inline` -> `($0 $1)`
  let app = FExpr::parse_sexp("(f x)")
  inspect(app.unparse_sexp(), content="(f x)")
  // canonical `(Lam ...)` is still accepted on parse (form_only not set)
  let lam2 = FExpr::parse_sexp("(Lam x x)")
  inspect(lam2.unparse_sexp(), content="(lambda x x)")
}

///|
test "child wrapper constructor remains usable from wbtest" {
  debug_inspect(FExpr2(Num(0)), content="FExpr2(Num(0))")
}
