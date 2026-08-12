///|
test "form pattern helpers" {
  let lam_form = SexpForm::compile("(lambda ($0 : $1) $2)", path="Lam")
  let fields = match lam_form.match_sexp(parse("(lambda (x : Bool) x)"), 3) {
    Some(fields) => fields
    None => panic()
  }
  assert_true(atom_text(fields[0]) == Some("x"))
  assert_true(atom_text(fields[1]) == Some("Bool"))
  assert_true(atom_text(fields[2]) == Some("x"))
  assert_true(
    match_form(
      parse("(lambda (x : Bool) x)"),
      "(lambda ($0 : $1) $2)",
      3,
      path="Lam",
    )
    is Some(_),
  )

  let lam_doc = lam_form.to_doc([
    SexpDoc::atom("x"),
    SexpDoc::atom("Bool"),
    SexpDoc::atom("x"),
  ])
  let lam_src = lam_doc.render()
  inspect(lam_src, content="(lambda (x : Bool) x)")
  assert_true(lam_form.match_sexp(parse(lam_src), 3) is Some(_))

  let compact_lam_form = SexpForm::compile("(lambda ($0: $1) $2)", path="Lam")
  let compact_lam_src = compact_lam_form
    .to_doc([SexpDoc::atom("x"), SexpDoc::atom("Bool"), SexpDoc::atom("x")])
    .render()
  inspect(compact_lam_src, content="(lambda (x: Bool) x)")
  assert_true(compact_lam_form.match_sexp(parse(compact_lam_src), 3) is Some(_))

  let arrow_form = SexpForm::compile("($0 -> $1)", path="Arrow")
  let arrow_doc = arrow_form.to_doc([
    SexpDoc::atom("Bool"),
    SexpDoc::atom("Int"),
  ])
  let arrow_src = arrow_doc.render()
  inspect(arrow_src, content="(Bool -> Int)")
  assert_true(arrow_form.match_sexp(parse(arrow_src), 2) is Some(_))
  assert_true(
    match_form(parse(arrow_src), "($0 -> $1)", 2, path="Arrow") is Some(_),
  )
}

///|
test "form pattern helpers report generated-code errors" {
  debug_inspect(
    @test.expect_error(() => SexpForm::compile("(", path="Bad")),
    content=(
      #|GeneratedCode(message="invalid #nano.form pattern at Bad: parse failed")
    ),
  )
  debug_inspect(
    @test.expect_error(() => {
      let form = SexpForm::compile("($1)", path="Bad")
      let _ = form.match_sexp(parse("(x)"), 1)
    }),
    content=(
      #|GeneratedCode(message="invalid #nano.form pattern at Bad: field $1 out of range")
    ),
  )
  debug_inspect(
    @test.expect_error(() => {
      let form = SexpForm::compile("($0)", path="Bad")
      let _ = form.to_doc([])
    }),
    content=(
      #|GeneratedCode(message="invalid #nano.form pattern at Bad: field $0 out of range")
    ),
  )
}
