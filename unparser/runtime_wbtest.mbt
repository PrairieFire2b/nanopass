///|
test "parse atoms and lists" {
  let sexp = parse("(Lam x Bool x)")
  debug_inspect(
    sexp,
    content=(
      #|List(
      #|  [
      #|    Atom("Lam", loc=Some({ start: 1, end: 4 })),
      #|    Atom("x", loc=Some({ start: 5, end: 6 })),
      #|    Atom("Bool", loc=Some({ start: 7, end: 11 })),
      #|    Atom("x", loc=Some({ start: 12, end: 13 })),
      #|  ],
      #|  loc=Some({ start: 0, end: 14 }),
      #|)
    ),
  )
}

///|
test "runtime helpers decode atoms lists and arity" {
  let atom = Atom("42", loc=None)
  assert_eq(expect_atom(atom, path="value"), "42")
  assert_eq(int_from_atom(atom, path="value"), 42)
  assert_eq(string_from_atom(atom, path="value"), "42")

  let items = [Atom("Lam", loc=None), Atom("x", loc=None)]
  let list = List(items, loc=None)
  assert_true(expect_list(list, path="form") == items)
  expect_arity(items, 2, path="form")
}

///|
test "runtime helpers report structured errors" {
  debug_inspect(
    @test.expect_error(() => parse("(")),
    content=(
      #|Syntax(path="", message="unterminated list")
    ),
  )
  debug_inspect(
    @test.expect_error(() => expect_atom(List([], loc=None), path="value")),
    content=(
      #|Decode(path="value", message="expected atom")
    ),
  )
  debug_inspect(
    @test.expect_error(() => expect_arity([], 1, path="form")),
    content=(
      #|Decode(path="form", message="expected 1 item(s), got 0")
    ),
  )
  debug_inspect(
    @test.expect_error(() => {
      let _ : Unit = unknown_head("Bad", path="Expr")
    }),
    content=(
      #|Decode(path="Expr", message="unknown head `Bad`")
    ),
  )
  debug_inspect(
    @test.expect_error(() => {
      let _ : Unit = literal_failure(["int: failed"], path="Expr")
    }),
    content=(
      #|Decode(path="Expr", message="no literal parser matched: int: failed")
    ),
  )
  debug_inspect(
    @test.expect_error(() => {
      let _ : Unit = hook_error(path="Expr", hook="parse_expr", message="boom")
    }),
    content=(
      #|HookError(path="Expr", hook="parse_expr", message="boom")
    ),
  )
}
