///|
test "parse nano spec schema and structured forms" {
  let input =
    #|(nanocake
    #|  (version 1)
    #|  (source "lang_def.mbt")
    #|  (nonterminal Type)
    #|  (language Lambda
    #|    (type Expr)
    #|    (entry Expr)
    #|    (meta LambdaVar)
    #|    (production App (form ($0 $1)) (form-only)))
    #|)
  let spec = parse_nano_spec(input) catch {
    InvalidLanguage(message) => fail(message)
    _ => fail("unexpected spec error")
  }
  assert_eq(spec.version, 1)
  assert_eq(spec.source, "lang_def.mbt")
  assert_eq(spec.nonterminals, ["Type"])
  assert_eq(spec.languages.length(), 1)
  let language = spec.languages[0]
  assert_eq(language.name, "Lambda")
  assert_eq(language.tycon, "Expr")
  assert_eq(language.entry, Some("Expr"))
  assert_eq(language.meta_vars, ["LambdaVar"])
  let production = language.productions[0]
  assert_eq(production.name, "App")
  assert_true(production.form_only)
  guard production.forms
    is [ListPattern([FieldPattern(index=0, ..), FieldPattern(index=1, ..)])] else {
    fail("unexpected structured form")
  }
}

///|
test "parse derived nano spec language" {
  let input =
    #|(nanocake
    #|  (version 1)
    #|  (source lang.mbt)
    #|  (language Base (type Expr))
    #|  (language Child
    #|    (type ChildExpr)
    #|    (extends Base)
    #|    (remove App Gone))
    #|)
  let spec = parse_nano_spec(input) catch {
    InvalidLanguage(message) => fail(message)
    _ => fail("unexpected spec error")
  }
  let child = spec.languages[1]
  assert_eq(child.extends, Some("Base"))
  assert_eq(child.removed, ["App", "Gone"])
}

///|
test "reject duplicate cake single-value clauses" {
  let input =
    #|(nanocake
    #|  (version 1)
    #|  (version 2)
    #|  (source lang.mbt)
    #|  (language Base (type Expr)))
  try parse_nano_spec(input) catch {
    InvalidLanguage(message) =>
      assert_true(message.contains("declared more than once"))
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected duplicate version to fail")
  }
}

///|
test "reject unknown cake clauses" {
  let input =
    #|(nanocake
    #|  (version 1)
    #|  (source lang.mbt)
    #|  (langauge Base (type Expr)))
  try parse_nano_spec(input) catch {
    InvalidLanguage(message) =>
      assert_true(message.contains("unknown clause 'langauge'"))
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected unknown clause to fail")
  }
}
