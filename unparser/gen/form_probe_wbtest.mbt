///|
// Generated codec source for a language using `#nano.form` and `#nano.inline`.
// Verifies the generator emits `@sexp.match_form` / `@sexp.form_doc` calls for
// custom surface forms, with canonical forms still available as fallback.
test "generate codec source with #nano.form and #nano.inline" {
  let lang = @language.Language::from_file(
    name="FormBase",
    path="language/fixtures/form_lang.mbt",
    mod="YumeXi/nanocake",
  )
  let source = gen_source(lang)
  inspect(source, content=(
    #|///|
    #|pub fn FExpr::from_sexp(sexp : @sexp.Sexp) -> FExpr raise @sexp.SexpError {
    #|  FExpr::from_sexp_without_hooks(sexp)
    #|}
    #|
    #|///|
    #|pub fn FExpr::from_sexp_without_hooks(sexp : @sexp.Sexp) -> FExpr raise @sexp.SexpError {
    #|  match @sexp.match_form(sexp, "(lambda $0 $1)", 2, path="FExpr.Lam") {
    #|    Some(fields) => {
    #|      return FExpr(Tree::Lam(@sexp.string_from_atom(fields[0], path="FExpr.Lam[0]"), FExpr::from_sexp(fields[1])))
    #|    }
    #|    None => ()
    #|  }
    #|  match @sexp.match_form(sexp, "($0 $1)", 2, path="FExpr.App") {
    #|    Some(fields) => {
    #|      return FExpr(Tree::App(FExpr::from_sexp(fields[0]), FExpr::from_sexp(fields[1])))
    #|    }
    #|    None => ()
    #|  }
    #|  match @sexp.atom_text(sexp) {
    #|    Some(atom) => {
    #|      try {
    #|        let v = @sexp.int_from_atom(sexp, path="FExpr.Num")
    #|        return FExpr(Tree::Num(v))
    #|      } catch {
    #|        _ => ()
    #|      }
    #|      try {
    #|        let v = @sexp.string_from_atom(sexp, path="FExpr.Var")
    #|        return FExpr(Tree::Var(v))
    #|      } catch {
    #|        _ => ()
    #|      }
    #|      @sexp.decode_error(path="FExpr", message="no atom constructor matched: " + atom)
    #|    }
    #|    None => {
    #|      let items = @sexp.expect_list(sexp, path="FExpr")
    #|      guard items.length() > 0 else {
    #|        @sexp.decode_error(path="FExpr", message="empty list")
    #|      }
    #|      let head = @sexp.expect_atom(items[0], path="FExpr.head")
    #|      match head {
    #|        "Lam" => {
    #|          @sexp.expect_arity(items, 3, path="FExpr.Lam")
    #|          FExpr(Tree::Lam(@sexp.string_from_atom(items[1], path="FExpr.Lam[0]"), FExpr::from_sexp(items[2])))
    #|        }
    #|        "App" => {
    #|          @sexp.expect_arity(items, 3, path="FExpr.App")
    #|          FExpr(Tree::App(FExpr::from_sexp(items[1]), FExpr::from_sexp(items[2])))
    #|        }
    #|        _ => @sexp.unknown_head(head, path="FExpr")
    #|      }
    #|    }
    #|  }
    #|}
    #|
    #|///|
    #|pub fn FExpr::to_sexp_doc(self : FExpr) -> @sexp.SexpDoc raise @sexp.SexpError {
    #|  match self {
    #|    FExpr(Tree::Num(x0)) => @sexp.int_to_doc(x0)
    #|    FExpr(Tree::Var(x0)) => @sexp.string_to_doc(x0)
    #|    FExpr(Tree::Lam(x0, x1)) => @sexp.form_doc("(lambda $0 $1)", [@sexp.string_to_doc(x0), x1.to_sexp_doc()], path="FExpr.Lam")
    #|    FExpr(Tree::App(x0, x1)) => @sexp.form_doc("($0 $1)", [x0.to_sexp_doc(), x1.to_sexp_doc()], path="FExpr.App")
    #|    _ => @sexp.decode_error(path="FExpr", message="unreachable tree ext")
    #|  }
    #|}
    #|
    #|///|
    #|pub fn FExpr::parse_sexp(input : StringView) -> FExpr raise @sexp.SexpError {
    #|  FExpr::from_sexp(@sexp.parse(input))
    #|}
    #|
    #|///|
    #|pub fn FExpr::unparse_sexp(self : FExpr, width? : Int) -> String raise @sexp.SexpError {
    #|  @sexp.render(FExpr::to_sexp_doc(self), width?)
    #|}
    #|
    #|///|
    #|pub fn FExpr2::from_sexp(sexp : @sexp.Sexp) -> FExpr2 raise @sexp.SexpError {
    #|  FExpr2::from_sexp_without_hooks(sexp)
    #|}
    #|
    #|///|
    #|pub fn FExpr2::from_sexp_without_hooks(sexp : @sexp.Sexp) -> FExpr2 raise @sexp.SexpError {
    #|  match @sexp.match_form(sexp, "(lambda $0 $1)", 2, path="FExpr2.Lam") {
    #|    Some(fields) => {
    #|      return FExpr2(Tree::Lam(@sexp.string_from_atom(fields[0], path="FExpr2.Lam[0]"), FExpr2::from_sexp(fields[1])))
    #|    }
    #|    None => ()
    #|  }
    #|  match @sexp.match_form(sexp, "($0 $1)", 2, path="FExpr2.App") {
    #|    Some(fields) => {
    #|      return FExpr2(Tree::App(FExpr2::from_sexp(fields[0]), FExpr2::from_sexp(fields[1])))
    #|    }
    #|    None => ()
    #|  }
    #|  match @sexp.atom_text(sexp) {
    #|    Some(atom) => {
    #|      try {
    #|        let v = @sexp.int_from_atom(sexp, path="FExpr2.Num")
    #|        return FExpr2(Tree::Num(v))
    #|      } catch {
    #|        _ => ()
    #|      }
    #|      try {
    #|        let v = @sexp.string_from_atom(sexp, path="FExpr2.Var")
    #|        return FExpr2(Tree::Var(v))
    #|      } catch {
    #|        _ => ()
    #|      }
    #|      @sexp.decode_error(path="FExpr2", message="no atom constructor matched: " + atom)
    #|    }
    #|    None => {
    #|      let items = @sexp.expect_list(sexp, path="FExpr2")
    #|      guard items.length() > 0 else {
    #|        @sexp.decode_error(path="FExpr2", message="empty list")
    #|      }
    #|      let head = @sexp.expect_atom(items[0], path="FExpr2.head")
    #|      match head {
    #|        "Lam" => {
    #|          @sexp.expect_arity(items, 3, path="FExpr2.Lam")
    #|          FExpr2(Tree::Lam(@sexp.string_from_atom(items[1], path="FExpr2.Lam[0]"), FExpr2::from_sexp(items[2])))
    #|        }
    #|        "App" => {
    #|          @sexp.expect_arity(items, 3, path="FExpr2.App")
    #|          FExpr2(Tree::App(FExpr2::from_sexp(items[1]), FExpr2::from_sexp(items[2])))
    #|        }
    #|        _ => @sexp.unknown_head(head, path="FExpr2")
    #|      }
    #|    }
    #|  }
    #|}
    #|
    #|///|
    #|pub fn FExpr2::to_sexp_doc(self : FExpr2) -> @sexp.SexpDoc raise @sexp.SexpError {
    #|  match self {
    #|    FExpr2(Tree::Num(x0)) => @sexp.int_to_doc(x0)
    #|    FExpr2(Tree::Var(x0)) => @sexp.string_to_doc(x0)
    #|    FExpr2(Tree::Lam(x0, x1)) => @sexp.form_doc("(lambda $0 $1)", [@sexp.string_to_doc(x0), x1.to_sexp_doc()], path="FExpr2.Lam")
    #|    FExpr2(Tree::App(x0, x1)) => @sexp.form_doc("($0 $1)", [x0.to_sexp_doc(), x1.to_sexp_doc()], path="FExpr2.App")
    #|    _ => @sexp.decode_error(path="FExpr2", message="unreachable tree ext")
    #|  }
    #|}
    #|
    #|///|
    #|pub fn FExpr2::parse_sexp(input : StringView) -> FExpr2 raise @sexp.SexpError {
    #|  FExpr2::from_sexp(@sexp.parse(input))
    #|}
    #|
    #|///|
    #|pub fn FExpr2::unparse_sexp(self : FExpr2, width? : Int) -> String raise @sexp.SexpError {
    #|  @sexp.render(FExpr2::to_sexp_doc(self), width?)
    #|}
    #|
    #|

  ))
}
