///|
test "cake frontend drives pass generators" {
  let language = @language.Language::from_spec(
    name="Lambda",
    path="meta_parser/fixtures/spec/lambda.cake",
    mod="YumeXi/nanocake",
  )
  let ast = language.gen()
  let surface = gen_surface(language)
  let semantics = gen_semantics(language)
  let rewrite = gen_rewrite(language)
  assert_true(ast.length() > 0)
  assert_true(surface.length() > 0)
  assert_true(semantics.length() > 0)
  assert_true(rewrite.length() > 0)
  let generated = @fmt.impls_to_string(ast) +
    @fmt.impls_to_string(surface) +
    @fmt.impls_to_string(semantics) +
    @fmt.impls_to_string(rewrite)
  assert_true(generated.contains("enum Tree"))
  assert_true(generated.contains("struct ExprSemantics"))
  assert_true(generated.contains("struct ExprRewriteAlg"))
}
