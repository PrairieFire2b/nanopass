///|
test "generator honors inheritance and #nano.remove" {
  let lang = @language.Language::from_file(
    name="RemoveBase",
    path="language/fixtures/remove_lang.mbt",
    mod="YumeXi/nanocake",
  )
  let source = gen_source(lang)
  inspect(
    source,
    content=(
      #|///|
      #|pub fn Expr::from_sexp(sexp : @sexp.Sexp) -> Expr raise @sexp.SexpError {
      #|  Expr::from_sexp_without_hooks(sexp)
      #|}
      #|
      #|///|
      #|pub fn Expr::from_sexp_without_hooks(sexp : @sexp.Sexp) -> Expr raise @sexp.SexpError {
      #|  match @sexp.atom_text(sexp) {
      #|    Some(atom) => {
      #|      try {
      #|        let v = @sexp.int_from_atom(sexp, path="Expr.Lit")
      #|        return Expr(Tree::Lit(v))
      #|      } catch {
      #|        _ => ()
      #|      }
      #|      @sexp.decode_error(path="Expr", message="no atom constructor matched: " + atom)
      #|    }
      #|    None => {
      #|      let items = @sexp.expect_list(sexp, path="Expr")
      #|      guard items.length() > 0 else {
      #|        @sexp.decode_error(path="Expr", message="empty list")
      #|      }
      #|      let head = @sexp.expect_atom(items[0], path="Expr.head")
      #|      match head {
      #|        "Add" => {
      #|          @sexp.expect_arity(items, 3, path="Expr.Add")
      #|          Expr(Tree::Add(Expr::from_sexp(items[1]), Expr::from_sexp(items[2])))
      #|        }
      #|        _ => @sexp.unknown_head(head, path="Expr")
      #|      }
      #|    }
      #|  }
      #|}
      #|
      #|///|
      #|pub fn Expr::to_sexp_doc(self : Expr) -> @sexp.SexpDoc raise @sexp.SexpError {
      #|  match self {
      #|    Expr(Tree::Lit(x0)) => @sexp.int_to_doc(x0)
      #|    Expr(Tree::Add(x0, x1)) => @sexp.list_doc([@sexp.atom_doc("Add"), x0.to_sexp_doc(), x1.to_sexp_doc()])
      #|    _ => @sexp.decode_error(path="Expr", message="unreachable tree ext")
      #|  }
      #|}
      #|
      #|///|
      #|pub fn Expr::parse_sexp(input : StringView) -> Expr raise @sexp.SexpError {
      #|  Expr::from_sexp(@sexp.parse(input))
      #|}
      #|
      #|///|
      #|pub fn Expr::unparse_sexp(self : Expr, width? : Int) -> String raise @sexp.SexpError {
      #|  @sexp.render(Expr::to_sexp_doc(self), width?)
      #|}
      #|
      #|///|
      #|pub fn Expr2::from_sexp(sexp : @sexp.Sexp) -> Expr2 raise @sexp.SexpError {
      #|  Expr2::from_sexp_without_hooks(sexp)
      #|}
      #|
      #|///|
      #|pub fn Expr2::from_sexp_without_hooks(sexp : @sexp.Sexp) -> Expr2 raise @sexp.SexpError {
      #|  match @sexp.atom_text(sexp) {
      #|    Some(atom) => {
      #|      try {
      #|        let v = @sexp.int_from_atom(sexp, path="Expr2.Lit")
      #|        return Expr2(Tree::Lit(v))
      #|      } catch {
      #|        _ => ()
      #|      }
      #|      @sexp.decode_error(path="Expr2", message="no atom constructor matched: " + atom)
      #|    }
      #|    None => {
      #|      let items = @sexp.expect_list(sexp, path="Expr2")
      #|      guard items.length() > 0 else {
      #|        @sexp.decode_error(path="Expr2", message="empty list")
      #|      }
      #|      let head = @sexp.expect_atom(items[0], path="Expr2.head")
      #|      match head {
      #|        "Add" => {
      #|          @sexp.expect_arity(items, 3, path="Expr2.Add")
      #|          Expr2(Tree::Add(Expr2::from_sexp(items[1]), Expr2::from_sexp(items[2])))
      #|        }
      #|        "Mul" => {
      #|          @sexp.expect_arity(items, 3, path="Expr2.Mul")
      #|          Expr2(Tree::Ext(Expr2Ext::Mul(Expr2::from_sexp(items[1]), Expr2::from_sexp(items[2]))))
      #|        }
      #|        _ => @sexp.unknown_head(head, path="Expr2")
      #|      }
      #|    }
      #|  }
      #|}
      #|
      #|///|
      #|pub fn Expr2::to_sexp_doc(self : Expr2) -> @sexp.SexpDoc raise @sexp.SexpError {
      #|  match self {
      #|    Expr2(Tree::Lit(x0)) => @sexp.int_to_doc(x0)
      #|    Expr2(Tree::Add(x0, x1)) => @sexp.list_doc([@sexp.atom_doc("Add"), x0.to_sexp_doc(), x1.to_sexp_doc()])
      #|    Expr2(Tree::Ext(Expr2Ext::Mul(x0, x1))) => @sexp.list_doc([@sexp.atom_doc("Mul"), x0.to_sexp_doc(), x1.to_sexp_doc()])
      #|    _ => @sexp.decode_error(path="Expr2", message="unreachable tree ext")
      #|  }
      #|}
      #|
      #|///|
      #|pub fn Expr2::parse_sexp(input : StringView) -> Expr2 raise @sexp.SexpError {
      #|  Expr2::from_sexp(@sexp.parse(input))
      #|}
      #|
      #|///|
      #|pub fn Expr2::unparse_sexp(self : Expr2, width? : Int) -> String raise @sexp.SexpError {
      #|  @sexp.render(Expr2::to_sexp_doc(self), width?)
      #|}
      #|
      #|
    ),
  )
}
