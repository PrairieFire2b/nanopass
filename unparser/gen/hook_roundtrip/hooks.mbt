// User-provided `#nano.parse_by` / `#nano.unparse_by` hooks for `HExpr.Sym`.
// Surface syntax: a symbol is written `@name` (e.g. `@foo`), distinct from the
// canonical `(Sym foo)` which `from_sexp_without_hooks` still accepts.

///|
/// parse hook: `@name` atom -> `Sym(name)`. Returns `None` for anything else so
/// the generated parser continues to declarative/canonical handling. Only a
/// genuine failure (an `@` prefix with an empty name) is raised as an error.
pub fn parse_sym(sexp : @sexp.Sexp) -> HExpr? raise @sexp.SexpError {
  match @sexp.atom_text(sexp) {
    Some(text) =>
      if text.has_prefix("@") {
        let name = text[1:].to_owned()
        if name.is_empty() {
          @sexp.decode_error(path="HExpr.Sym", message="empty symbol name")
        }
        Some(HExpr(Sym(name)))
      } else {
        None
      }
    None => None
  }
}

///|
/// unparse hook: `Sym(name)` -> `@name` atom.
pub fn unparse_sym(value : HExpr) -> @sexp.SexpDoc raise @sexp.SexpError {
  match value {
    HExpr(Sym(name)) => @sexp.atom_doc("@" + name)
    _ => @sexp.decode_error(path="HExpr.Sym", message="unparse_sym: not a Sym")
  }
}
