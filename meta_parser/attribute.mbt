///|
/// Extract the `name` parameter from a `#nanopass.language(...)` attribute.
///
/// # Raises
/// `NanopassParseError::InvalidAttribute` if the attribute is malformed
/// or missing the `name` parameter.
pub fn get_name_from_attr(attr : @attribute.Attribute) -> String raise {
  match attr.parsed {
    Some(Apply(_, props)) => {
      let name_prop = props.find(fn(prop) {
        match prop {
          Labeled("name", String(_)) => true
          _ => false
        }
      })
      match name_prop {
        Some(Labeled(_, String(name))) => name
        _ =>
          raise NanopassParseError::InvalidAttribute(
            "Missing `name` parameter in `#nanopass.language` attribute",
          )
      }
    }
    _ =>
      raise NanopassParseError::InvalidAttribute(
        "Invalid `#nanopass.language` attribute format",
      )
  }
}

///|
/// Extract the `extends` parameter from a `#nanopass.language(...)` attribute
fn get_extends_from_attr(attr : @attribute.Attribute) -> String? {
  match attr.parsed {
    Some(Apply(_, props)) =>
      match
        props.find(fn(prop) {
          match prop {
            Labeled("extends", String(_)) => true
            _ => false
          }
        }) {
        Some(Labeled(_, String(extends))) => Some(extends)
        _ => None
      }
    _ => None
  }
}

///|
/// Get the simple type name from a Type AST node
fn type_to_name(ty : @syntax.Type) -> String {
  match ty {
    Name(constr_id~, ..) =>
      match constr_id.id {
        Ident(name~) => name
        Dot(id~, ..) => id
      }
    _ => ""
  }
}

///|
/// Find all enum type declarations in the file that have `#nanopass.nonterminal` attribute
fn find_nonterminal_types(
  impls : @list.List[@syntax.Impl],
) -> Array[@syntax.TypeDecl] {
  impls
  .filter_map(impl_ => {
    match impl_ {
      TopTypeDef(type_decl) =>
        match type_decl.components {
          Variant(_) =>
            if type_decl.attrs.any(fn(attr) {
                attr.raw is [.. "#nanopass.nonterminal", ..]
              }) {
              Some(type_decl)
            } else {
              None
            }
          _ => None
        }
      _ => None
    }
  })
  .to_array()
}

///|
/// Core logic: parse language definitions from already-parsed file impls
fn parse_languages_from_impls(
  impls : @list.List[@syntax.Impl],
) -> Array[NanoLangDef] raise {
  let nt_types = find_nonterminal_types(impls)
  let nt_names : Array[String] = nt_types.map(fn(td) { td.tycon })

  impls
  .filter_map(impl_ => {
    match impl_ {
      TopTypeDef(type_decl) =>
        match type_decl.components {
          Variant(constructors) =>
            type_decl.attrs
            .find(fn(attr) { attr.raw is [.. "#nanopass.language", ..] })
            .map(attr => {
              let name = get_name_from_attr(attr)
              let extends = get_extends_from_attr(attr)
              let tycon = type_decl.tycon

              let nonterminals : Array[NonTerminal] = []
              let terminals : Array[Terminal] = []

              // NonTerminal::TypeDecl for each referenced nonterminal type
              nt_types.each(fn(nt_td) {
                if constructors.any(fn(c) {
                    match c.args {
                      Some(args) =>
                        args.any(fn(p) { type_to_name(p.ty) == nt_td.tycon })
                      None => false
                    }
                  }) {
                  nonterminals.push(TypeDecl(nt_td))
                }
              })

              // Classify each constructor
              constructors.each(fn(c) {
                let self_ref = match c.args {
                  Some(args) => args.any(fn(p) { type_to_name(p.ty) == tycon })
                  None => false
                }
                let nt_ref = match c.args {
                  Some(args) =>
                    args.any(fn(p) { nt_names.contains(type_to_name(p.ty)) })
                  None => false
                }
                if self_ref {
                  nonterminals.push(Constructor(c))
                } else if nt_ref {
                  ()
                } else {
                  terminals.push(Terminal(c))
                }
              })

              { name, extends, nonterminals, terminals, type_decl }
            })
          _ => None
        }
      _ => None
    }
  })
  .to_array()
}

///|
/// Parse a source file by path and return all language definitions found in it.
///
/// Each enum annotated with `#nanopass.language(name="...")` produces one `NanoLangDef`.
pub fn find_languages_by_file(src : String) -> Array[NanoLangDef] raise {
  let (impls, _reports) = @parser.parse_file(src)
  parse_languages_from_impls(impls)
}

///|
/// Parse the file referenced by a `SourceLocRepr` and return all language definitions found in it.
pub fn find_languages(src : SourceLocRepr) -> Array[NanoLangDef] raise {
  let (impls, _reports) = @parser.parse_file(src.file_path())
  parse_languages_from_impls(impls)
}

///|
test {
  let langs = find_languages_by_file("poc/lang_def.mbt")
  inspect(langs.length(), content="2")
  inspect(langs[0].name, content="Lambda")
  inspect(langs[1].name, content="SimplyTypedLambda")
}
