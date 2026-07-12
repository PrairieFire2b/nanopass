// Real compiled + executed roundtrip tests for the generated codecs.
// These prove the generator output type-checks and roundtrips, not just that
// it matches a string snapshot.

///|
fn assert_roundtrip_expr(text : String) -> Unit raise {
  let value = Expr::parse_sexp(text)
  let back = value.unparse_sexp()
  let reparsed = Expr::parse_sexp(back)
  assert_eq(value, reparsed)
}

///|
fn assert_roundtrip_typed(text : String) -> Unit raise {
  let value = TypedExpr::parse_sexp(text)
  let back = value.unparse_sexp()
  let reparsed = TypedExpr::parse_sexp(back)
  assert_eq(value, reparsed)
}

///|
fn assert_roundtrip_type(text : String) -> Unit raise {
  let value = Type::parse_sexp(text)
  let back = value.unparse_sexp()
  let reparsed = Type::parse_sexp(back)
  assert_eq(value, reparsed)
}

///|
test "Expr roundtrips through generated codec" {
  assert_roundtrip_expr("42")
  assert_roundtrip_expr("x")
  assert_roundtrip_expr("(App f x)")
  assert_roundtrip_expr("(Lam x (App x x))")
  assert_roundtrip_expr("(Lam f (Lam x (App f (App x x))))")
}

///|
test "Type roundtrips through generated codec" {
  assert_roundtrip_type("Bool")
  assert_roundtrip_type("Int")
  assert_roundtrip_type("(Arrow Bool Int)")
  assert_roundtrip_type("(Arrow (Arrow Bool Int) Bool)")
}

///|
test "TypedExpr roundtrips through generated codec (shared + ext + external)" {
  assert_roundtrip_typed("True")
  assert_roundtrip_typed("False")
  assert_roundtrip_typed("42")
  // shared constructor with reordered fields + external nonterminal `Type`
  assert_roundtrip_typed("(Lam x Bool x)")
  // derived-only constructor routed through ext enum
  assert_roundtrip_typed("(If True x y)")
  assert_roundtrip_typed("(App (Lam x (Arrow Bool Int) x) True)")
}

///|
test "unparse produces expected surface syntax" {
  let e = Expr::parse_sexp("(Lam x (App x x))")
  inspect(e.unparse_sexp(), content="(Lam x (App x x))")
  let t = Type::parse_sexp("(Arrow Bool Int)")
  inspect(t.unparse_sexp(), content="(Arrow Bool Int)")
}
