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

///|
fn layout_summary(layout : @layout.GeneratedLanguageLayout) -> Array[String] {
  layout.constructors.map(cl => {
    let target = match cl.target {
      RawTarget => "raw"
      TreeTarget => "tree"
      ExtTarget(name) => "ext:\{name}"
    }
    let forms = cl.surface_forms
      .map(form => {
        match form.origin {
          DeclaredForm => "declared"
          NameAliasForm => "name"
          CanonicalForm => "canonical"
          InlineForm => "inline"
          InfixForm => "infix"
        }
      })
      .join(",")
    let order = cl.field_order.map(index => index.to_string()).join(",")
    "\{cl.lang_name}:\{cl.source_tycon}:\{cl.constr_name}:\{target}:\{order}:\{forms}"
  })
}

///|
test "cake and attribute frontends produce equivalent layouts" {
  let cake = Language::from_spec(
    name="Lambda",
    path="meta_parser/fixtures/spec/lambda.cake",
    mod="YumeXi/nanocake",
  )
  let attributes = Language::from_file(
    name="Lambda",
    path="meta_parser/fixtures/spec/lang_attr.mbt",
    mod="YumeXi/nanocake",
  )
  assert_eq(layout_summary(cake.layout()), layout_summary(attributes.layout()))
}
