///|
test "cake frontend drives complete codec generation" {
  let language = @language.Language::from_spec(
    name="Lambda",
    path="meta_parser/fixtures/spec/lambda.cake",
    mod="YumeXi/nanocake",
  )
  let source = gen_source(language)
  assert_true(source.contains("pub fn Expr::from_sexp"))
  assert_true(source.contains("pub fn TypedExpr::to_sexp_doc"))
  let impls = gen(language)
  assert_true(impls.length() > 0)
}
