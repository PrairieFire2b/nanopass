///|
test "parse nested nano sexp with comments and strings" {
  let input =
    #|(nanocake
    #|  ; source file
    #|  (version 1)
    #|  (source "lang def.mbt")
    #|  (language Lambda (type Expr)))
  let node = parse_spec(input)
  guard node is SpecList(items~, span~) else { fail("expected document list") }
  assert_eq(span.start, 0)
  assert_true(span.end > span.start)
  guard items
    is [
      SpecAtom(value="nanocake", ..),
      SpecList(
        items=[SpecAtom(value="version", ..), SpecAtom(value="1", ..)],
        ..
      ),
      SpecList(
        items=[
          SpecAtom(value="source", ..),
          SpecString(value="lang def.mbt", ..),
        ],
        ..
      ),
      SpecList(
        items=[
          SpecAtom(value="language", ..),
          SpecAtom(value="Lambda", ..),
          SpecList(
            items=[SpecAtom(value="type", ..), SpecAtom(value="Expr", ..)],
            ..
          ),
        ],
        ..
      ),
    ] else {
    fail("unexpected spec tree")
  }
}

///|
test "parse nano sexp string escapes" {
  let input =
    #|(source "a\n\"b\\c")
  guard parse_spec(input)
    is SpecList(
      items=[SpecAtom(value="source", ..), SpecString(value="a\n\"b\\c", ..)],
      ..
    ) else {
    fail("unexpected escaped string")
  }
}

///|
test "reject trailing nano sexp input with offset" {
  try parse_spec("(nanocake) extra") catch {
    InvalidLanguage(message) => assert_true(message.contains("offset 11"))
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected trailing input to fail")
  }
}
