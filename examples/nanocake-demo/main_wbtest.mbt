///|
test "constant folding evaluates closed arithmetic" {
  inspect(simplify("(+ 1 (* 2 3))"), content="7")
}

///|
test "constant folding preserves open expressions" {
  inspect(simplify("(+ x (* 2 3))"), content="(+ x 6)")
}

///|
test "constant folding reports malformed input" {
  try simplify("(+ 1)") catch {
    _ => ()
  } noraise {
    _ => fail("expected malformed input to raise")
  }
}

///|
test "cake schema drives the full generation pipeline" {
  let language = @language.Language::from_spec(
    name="Arithmetic",
    path="schema/arithmetic.cake",
    mod="YumeXi/nanocake-demo",
    pkg="schema",
  )
  assert_true(language.layout().constructors.length() > 0)
  assert_true(@gen.gen_source(language).contains("ExprSchema::from_sexp"))
  assert_true(@pass.gen_semantics(language).length() > 0)
  assert_true(@pass.gen_rewrite(language).length() > 0)
}
