///|
test "parse generate command options" {
  let options = parse_generate_options([
    "--spec", "schema/language.cake", "--language", "Lambda", "--module", "user/compiler",
    "--pkg", "schema", "--out-dir", "src/generated", "--check",
  ])
  assert_eq(options.spec, "schema/language.cake")
  assert_eq(options.language, "Lambda")
  assert_eq(options.module_name, "user/compiler")
  assert_eq(options.pkg, "schema")
  assert_eq(options.out_dir, "src/generated")
  assert_true(options.check)
}

///|
test "build the complete generated file set" {
  let files = build_generated_files({
    spec: "meta_parser/fixtures/spec/lambda.cake",
    language: "Lambda",
    module_name: "YumeXi/nanocake",
    pkg: "meta_parser",
    out_dir: "unused",
    check: true,
  })
  assert_eq(files.map(file => file.name), [
    "ast.mbt", "codec.mbt", "pass.mbt", "moon.pkg",
  ])
  assert_true(files[0].content.contains("enum Tree"))
  assert_true(files[1].content.contains("Expr::from_sexp"))
  assert_true(files[2].content.contains("ExprSemantics"))
  assert_true(files[2].content.contains("ExprRewriteAlg"))
}

///|
test "detect stale generated files without writing" {
  let changed = write_generated_files({
    spec: "meta_parser/fixtures/spec/lambda.cake",
    language: "Lambda",
    module_name: "YumeXi/nanocake",
    pkg: "meta_parser",
    out_dir: "_build/nonexistent-nanocake-generated",
    check: true,
  })
  assert_eq(changed.length(), 4)
  assert_false(@fs.path_exists("_build/nonexistent-nanocake-generated"))
}

///|
test "generated file checks tolerate Windows line endings" {
  assert_eq(normalize_newlines("a\r\nb\r\n"), "a\nb\n")
}
