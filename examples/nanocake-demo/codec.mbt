// These codecs use the same runtime calls as `@unparser/gen` output.

///|
fn Expr::from_sexp(sexp : @sexp.Sexp) -> Expr raise @sexp.SexpError {
  match @sexp.atom_text(sexp) {
    Some(_) =>
      try @sexp.int_from_atom(sexp, path="Expr.Int") catch {
        _ => Expr::symbol(@sexp.string_from_atom(sexp, path="Expr.Var"))
      } noraise {
        value => Expr::int(value)
      }
    None => {
      let items = @sexp.expect_list(sexp, path="Expr")
      @sexp.expect_arity(items, 3, path="Expr.binary")
      let operator = @sexp.expect_atom(items[0], path="Expr.operator")
      let left = Expr::from_sexp(items[1])
      let right = Expr::from_sexp(items[2])
      match operator {
        "+" => Expr::add(left, right)
        "*" => Expr::mul(left, right)
        _ => @sexp.unknown_head(operator, path="Expr")
      }
    }
  }
}

///|
fn Expr::parse(input : StringView) -> Expr raise @sexp.SexpError {
  Expr::from_sexp(@sexp.parse(input))
}

///|
fn Expr::to_doc(self : Expr) -> @sexp.SexpDoc {
  let Expr(tree) = self
  match tree {
    Int(value) => @sexp.int_to_doc(value)
    Var(name) => @sexp.string_to_doc(name)
    Add(left, right) =>
      @sexp.list_doc([@sexp.atom_doc("+"), left.to_doc(), right.to_doc()])
    Mul(left, right) =>
      @sexp.list_doc([@sexp.atom_doc("*"), left.to_doc(), right.to_doc()])
  }
}

///|
fn Expr::render(self : Expr) -> String {
  self.to_doc().render()
}
