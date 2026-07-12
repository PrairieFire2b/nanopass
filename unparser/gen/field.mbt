// Recursive parse / doc dispatch for a constructor field of a given type.

///|
/// Is `ty` a type this generator emits a codec for (a language wrapper or an
/// external nonterminal)? If so, recurse through its `from_sexp`/`to_sexp_doc`.
fn is_codec_type(types : Array[TypeCodegen], ty : String) -> Bool {
  types.any(t => t.tycon == ty)
}

///|
/// Expression that parses sub-`sexp` `expr` into a value of type `ty`.
fn parse_field(
  types : Array[TypeCodegen],
  ty : String,
  expr : String,
  path : String,
) -> String {
  if is_codec_type(types, ty) {
    "\{ty}::from_sexp(\{expr})"
  } else {
    match ty {
      "Int" => "@sexp.int_from_atom(\{expr}, path=\{str_lit(path)})"
      "String" | "LambdaVar" =>
        "@sexp.string_from_atom(\{expr}, path=\{str_lit(path)})"
      _ => "@sexp.string_from_atom(\{expr}, path=\{str_lit(path)})"
    }
  }
}

///|
/// Expression that renders a value `expr` of type `ty` to a `SexpDoc`.
fn doc_field(types : Array[TypeCodegen], ty : String, expr : String) -> String {
  if is_codec_type(types, ty) {
    "\{expr}.to_sexp_doc()"
  } else {
    match ty {
      "Int" => "@sexp.int_to_doc(\{expr})"
      "String" | "LambdaVar" => "@sexp.string_to_doc(\{expr})"
      _ => "@sexp.atom_doc(\{expr}.to_string())"
    }
  }
}

///|
/// A "list constructor" has a head keyword followed by its fields:
/// `(Name field0 field1 ...)`. Any constructor with 2+ fields is a list form;
/// zero/one-field constructors are atom forms.
fn is_list_constructor(cl : @layout.ConstructorLayout) -> Bool {
  constr_args(cl.source_constr).length() >= 2
}
