///|
test "load language from nano sexp sidecar" {
  let language = Language::from_spec(
    name="Lambda",
    path="meta_parser/fixtures/spec/lambda.cake",
    mod="YumeXi/nanocake",
  )
  let layout = language.layout()
  assert_eq(layout.tree.constructors.length(), 5)
  assert_eq(layout.constructors.length(), 14)
  let lambda_lam = layout.constructors.filter(cl => {
      cl.lang_name == "Lambda" && cl.constr_name == "Lam"
    })[0]
  assert_true(lambda_lam.surface_forms[0].origin is DeclaredForm)
  let lambda_app = layout.constructors.filter(cl => {
      cl.lang_name == "Lambda" && cl.constr_name == "App"
    })[0]
  assert_eq(lambda_app.surface_forms.length(), 1)
  assert_true(lambda_app.surface_forms[0].origin is DeclaredForm)
  let child_app = layout.constructors.filter(cl => {
      cl.lang_name == "SimplyTypedLambda" && cl.constr_name == "App"
    })[0]
  assert_eq(child_app.surface_forms.length(), 1)
  assert_true(child_app.surface_forms[0].origin is DeclaredForm)
}
