///|
fn simplify(input : String) -> String raise @sexp.SexpError {
  Expr::parse(input).cata(constant_folder()).render()
}

///|
fn main raise {
  let input = "(+ 1 (* 2 3))"
  let output = simplify(input)
  println("input:  \{input}")
  println("output: \{output}")
}
