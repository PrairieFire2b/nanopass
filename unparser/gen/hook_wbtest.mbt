///|
// Generated codec source for a language using `#nano.parse_by` / `#nano.unparse_by`.
// `from_sexp` tries the hook first then delegates to `from_sexp_without_hooks`;
// `to_sexp_doc` calls the unparse hook.
test "generate codec source with parse_by and unparse_by hooks" {
  let lang = @language.Language::from_file(
    name="HookBase",
    path="language/fixtures/hook_lang.mbt",
    mod="YumeXi/nanocake",
  )
  let source = gen_source(lang)
  inspect(source, content=(
    #|///|
    #|pub fn HExpr::from_sexp(sexp : @sexp.Sexp) -> HExpr raise @sexp.SexpError {
    #|  match (parse_sym(sexp) catch {
    #|    _ => @sexp.hook_error(path="HExpr.Sym", hook="parse_sym", message="parse hook failed")
    #|  }) {
    #|    Some(value) => return value
    #|    None => ()
    #|  }
    #|  HExpr::from_sexp_without_hooks(sexp)
    #|}
    #|
    #|///|
    #|pub fn HExpr::from_sexp_without_hooks(sexp : @sexp.Sexp) -> HExpr raise @sexp.SexpError {
    #|  match @sexp.atom_text(sexp) {
    #|    Some(atom) => {
    #|      try {
    #|        let v = @sexp.int_from_atom(sexp, path="HExpr.Num")
    #|        return HExpr(Tree::Num(v))
    #|      } catch {
    #|        _ => ()
    #|      }
    #|      try {
    #|        let v = @sexp.string_from_atom(sexp, path="HExpr.Sym")
    #|        return HExpr(Tree::Sym(v))
    #|      } catch {
    #|        _ => ()
    #|      }
    #|      @sexp.decode_error(path="HExpr", message="no atom constructor matched: " + atom)
    #|    }
    #|    None => {
    #|      let items = @sexp.expect_list(sexp, path="HExpr")
    #|      guard items.length() > 0 else {
    #|        @sexp.decode_error(path="HExpr", message="empty list")
    #|      }
    #|      let head = @sexp.expect_atom(items[0], path="HExpr.head")
    #|      match head {
    #|        "App" => {
    #|          @sexp.expect_arity(items, 3, path="HExpr.App")
    #|          HExpr(Tree::App(HExpr::from_sexp(items[1]), HExpr::from_sexp(items[2])))
    #|        }
    #|        _ => @sexp.unknown_head(head, path="HExpr")
    #|      }
    #|    }
    #|  }
    #|}
    #|
    #|///|
    #|pub fn HExpr::to_sexp_doc(self : HExpr) -> @sexp.SexpDoc raise @sexp.SexpError {
    #|  match self {
    #|    HExpr(Tree::Num(x0)) => @sexp.int_to_doc(x0)
    #|    HExpr(Tree::Sym(x0)) as bound => unparse_sym(bound) catch {
    #|      _ => @sexp.hook_error(path="HExpr.Sym", hook="unparse_sym", message="unparse hook failed")
    #|    }
    #|    HExpr(Tree::App(x0, x1)) => @sexp.list_doc([@sexp.atom_doc("App"), x0.to_sexp_doc(), x1.to_sexp_doc()])
    #|    _ => @sexp.decode_error(path="HExpr", message="unreachable tree ext")
    #|  }
    #|}
    #|
    #|///|
    #|pub fn HExpr::parse_sexp(input : StringView) -> HExpr raise @sexp.SexpError {
    #|  HExpr::from_sexp(@sexp.parse(input))
    #|}
    #|
    #|///|
    #|pub fn HExpr::unparse_sexp(self : HExpr, width? : Int) -> String raise @sexp.SexpError {
    #|  @sexp.render(HExpr::to_sexp_doc(self), width?)
    #|}
    #|
    #|///|
    #|pub fn HExpr2::from_sexp(sexp : @sexp.Sexp) -> HExpr2 raise @sexp.SexpError {
    #|  HExpr2::from_sexp_without_hooks(sexp)
    #|}
    #|
    #|///|
    #|pub fn HExpr2::from_sexp_without_hooks(sexp : @sexp.Sexp) -> HExpr2 raise @sexp.SexpError {
    #|  match @sexp.atom_text(sexp) {
    #|    Some(atom) => {
    #|      try {
    #|        let v = @sexp.int_from_atom(sexp, path="HExpr2.Num")
    #|        return HExpr2(Tree::Num(v))
    #|      } catch {
    #|        _ => ()
    #|      }
    #|      try {
    #|        let v = @sexp.string_from_atom(sexp, path="HExpr2.Sym")
    #|        return HExpr2(Tree::Sym(v))
    #|      } catch {
    #|        _ => ()
    #|      }
    #|      @sexp.decode_error(path="HExpr2", message="no atom constructor matched: " + atom)
    #|    }
    #|    None => {
    #|      let items = @sexp.expect_list(sexp, path="HExpr2")
    #|      guard items.length() > 0 else {
    #|        @sexp.decode_error(path="HExpr2", message="empty list")
    #|      }
    #|      let head = @sexp.expect_atom(items[0], path="HExpr2.head")
    #|      match head {
    #|        "App" => {
    #|          @sexp.expect_arity(items, 3, path="HExpr2.App")
    #|          HExpr2(Tree::App(HExpr2::from_sexp(items[1]), HExpr2::from_sexp(items[2])))
    #|        }
    #|        _ => @sexp.unknown_head(head, path="HExpr2")
    #|      }
    #|    }
    #|  }
    #|}
    #|
    #|///|
    #|pub fn HExpr2::to_sexp_doc(self : HExpr2) -> @sexp.SexpDoc raise @sexp.SexpError {
    #|  match self {
    #|    HExpr2(Tree::Num(x0)) => @sexp.int_to_doc(x0)
    #|    HExpr2(Tree::Sym(x0)) => @sexp.string_to_doc(x0)
    #|    HExpr2(Tree::App(x0, x1)) => @sexp.list_doc([@sexp.atom_doc("App"), x0.to_sexp_doc(), x1.to_sexp_doc()])
    #|    _ => @sexp.decode_error(path="HExpr2", message="unreachable tree ext")
    #|  }
    #|}
    #|
    #|///|
    #|pub fn HExpr2::parse_sexp(input : StringView) -> HExpr2 raise @sexp.SexpError {
    #|  HExpr2::from_sexp(@sexp.parse(input))
    #|}
    #|
    #|///|
    #|pub fn HExpr2::unparse_sexp(self : HExpr2, width? : Int) -> String raise @sexp.SexpError {
    #|  @sexp.render(HExpr2::to_sexp_doc(self), width?)
    #|}
    #|
    #|

  ))
}
