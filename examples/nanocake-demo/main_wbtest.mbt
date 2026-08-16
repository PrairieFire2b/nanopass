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
