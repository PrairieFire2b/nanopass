// Wrapper-based S-expression parser/unparser generator.
//
// This package consumes `@language.Language::layout()` and emits, for every
// type in the language group (language wrappers plus external nonterminals),
// the four codec functions:
//
//   Ty::from_sexp(sexp) -> Ty
//   Ty::parse_sexp(text) -> Ty
//   Ty::to_sexp_doc(self) -> SexpDoc
//   Ty::unparse_sexp(self) -> String
//
// The generator does NOT re-derive tree/wrapper shapes; every constructor's
// target (`RawTarget` / `TreeTarget` / `ExtTarget`), field reorder and tree
// padding come from the shared `ConstructorLayout`.

///|
priv suberror GenError {
  InvalidGeneratedCode(String)
}

///|
/// A per-type bundle of the layout information the generator needs.
priv struct TypeCodegen {
  tycon : String
  constructors : Array[@layout.ConstructorLayout]
}

///|
/// Number of tree slots for a shared/ext tree constructor, used to compute the
/// padding filler (`()`) that language wrappers insert for unused tree params.
fn tree_slot_count(tree : @layout.TreeLayout, constr_name : String) -> Int {
  for c in tree.constructors {
    if c.constr_name == constr_name {
      return c.field_types.length()
    }
  }
  0
}

///|
fn constr_args(c : @syntax.ConstrDecl) -> Array[@syntax.ConstrParam] {
  match c.args {
    Some(args) => args.to_array()
    None => []
  }
}

///|
fn field_type_name(ty : @syntax.Type) -> String {
  match ty {
    @syntax.Name(constr_id~, ..) =>
      match constr_id.id {
        @syntax.Ident(name~) => name
        @syntax.Dot(id~, ..) => id
      }
    _ => ""
  }
}

///|
fn str_lit(text : String) -> String {
  let sb = StringBuilder::new()
  sb.write_char('"')
  for i in 0..<text.length() {
    match text.get_char(i) {
      Some('"') => sb.write_string("\\\"")
      Some('\\') => sb.write_string("\\\\")
      Some('\n') => sb.write_string("\\n")
      Some(ch) => sb.write_char(ch)
      None => ()
    }
  }
  sb.write_char('"')
  sb.to_string()
}

///|
fn constructor_path(tycon : String, constr_name : String) -> String {
  "\{tycon}.\{constr_name}"
}
