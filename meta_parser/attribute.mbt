///|
fn is_language_attr(attr : @attribute.Attribute) -> Bool {
  attr.raw is [.. "#nanopass.language", ..] || attr.raw is [.. "#nano.lang", ..]
}

///|
fn string_param_from_attr(
  attr : @attribute.Attribute,
  param_name : String,
) -> String? {
  match attr.parsed {
    Some(Apply(_, props)) =>
      match
        props.find(fn(prop) {
          match prop {
            Labeled(label, String(_)) => label == param_name
            _ => false
          }
        }) {
        Some(Labeled(_, String(value))) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
/// Extract the `name` parameter from a `#nanopass.language(...)` attribute.
///
/// # Raises
/// `NanopassParseError::InvalidAttribute` if the attribute is malformed
/// or missing the `name` parameter.
pub fn get_name_from_attr(attr : @attribute.Attribute) -> String raise {
  match attr.parsed {
    Some(Apply(_, _)) =>
      match string_param_from_attr(attr, "name") {
        Some(name) => name
        _ =>
          raise NanopassParseError::InvalidAttribute(
            "Missing `name` parameter in `#nanopass.language` attribute",
          )
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
  string_param_from_attr(attr, "extends")
}

///|
/// Extract the optional `layer` parameter from `#nanopass.language(...)`.
fn get_layer_from_attr(attr : @attribute.Attribute) -> String? {
  string_param_from_attr(attr, "layer")
}

///|
/// Extract the optional `entry` parameter from `#nanopass.language(...)`.
fn get_entry_from_language_attr(attr : @attribute.Attribute) -> String? {
  string_param_from_attr(attr, "entry")
}

///|
fn meta_vars_from_attrs(
  owner : String,
  attrs : @list.List[@attribute.Attribute],
) -> Array[MetaVarDecl] raise {
  let vars : Array[MetaVarDecl] = []
  attrs.each(attr => {
    if is_nano_attr(attr, "meta") {
      vars.push({ owner, name: meta_string_from_attr(attr) })
    }
  })
  vars
}

///|
fn get_entry_from_attrs(
  lang_name : String,
  lang_attr : @attribute.Attribute,
  attrs : @list.List[@attribute.Attribute],
) -> String? raise {
  let entries : Array[String] = []
  match get_entry_from_language_attr(lang_attr) {
    Some(entry) => entries.push(entry)
    None => ()
  }
  attrs.each(attr => {
    if is_nano_attr(attr, "entry") {
      entries.push(entry_string_from_attr(attr))
    }
  })
  match entries.length() {
    0 => None
    1 => Some(entries[0])
    _ =>
      raise InvalidLanguage(
        "Language '\{lang_name}' declares entry more than once",
      )
  }
}

///|
/// Collect all constructor names listed in top-level `#nano.remove(...)`
/// attributes on a language type declaration.
fn removed_from_attrs(
  attrs : @list.List[@attribute.Attribute],
) -> Array[String] raise {
  let removed : Array[String] = []
  attrs.each(attr => {
    if is_nano_attr(attr, "remove") {
      remove_names_from_attr(attr).each(name => {
        if !removed.contains(name) {
          removed.push(name)
        }
      })
    }
  })
  removed
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
fn find_source_type_names(impls : @list.List[@syntax.Impl]) -> Array[String] {
  let names : Array[String] = []
  impls.each(impl_ => {
    match impl_ {
      TopTypeDef(type_decl) =>
        if !names.contains(type_decl.tycon) {
          names.push(type_decl.tycon)
        }
      _ => ()
    }
  })
  names
}

///|
/// Core logic: parse language definitions from already-parsed file impls
fn parse_languages_from_impls(
  impls : @list.List[@syntax.Impl],
) -> Array[NanoLangDef] raise {
  let nt_types = find_nonterminal_types(impls)
  let nt_names : Array[String] = nt_types.map(fn(td) { td.tycon })
  let source_type_names = find_source_type_names(impls)

  let langs = impls
    .filter_map(impl_ => {
      match impl_ {
        TopTypeDef(type_decl) =>
          match type_decl.components {
            Variant(constructors) =>
              type_decl.attrs
              .find(is_language_attr)
              .map(attr => {
                let name = get_name_from_attr(attr)
                let extends = get_extends_from_attr(attr)
                let layer = get_layer_from_attr(attr)
                let entry = get_entry_from_attrs(name, attr, type_decl.attrs)
                let tycon = type_decl.tycon

                let nonterminals : Array[NonTerminal] = []
                let terminals : Array[Terminal] = []
                let meta_vars = meta_vars_from_attrs(tycon, type_decl.attrs)
                let production_defs : Array[ProductionDef] = []
                let removed = removed_from_attrs(type_decl.attrs)

                // NonTerminal::TypeDecl for each referenced nonterminal type
                nt_types.each(nt_td => {
                  if constructors.any(fn(c) {
                      match c.args {
                        Some(args) =>
                          args.any(fn(p) { type_to_name(p.ty) == nt_td.tycon })
                        None => false
                      }
                    }) {
                    nonterminals.push(TypeDecl(nt_td))
                    meta_vars_from_attrs(nt_td.tycon, nt_td.attrs).each(meta_var => {
                      meta_vars.push(meta_var)
                    })
                  }
                })

                // Classify each constructor
                constructors.each(c => {
                  production_defs.push(production_def_from_constr(tycon, c))
                  let self_ref = match c.args {
                    Some(args) =>
                      args.any(fn(p) { type_to_name(p.ty) == tycon })
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

                {
                  name,
                  extends,
                  layer,
                  entry,
                  resolved_entry: None,
                  meta_vars,
                  nonterminals,
                  terminals,
                  production_defs,
                  removed,
                  type_decl,
                }
              })
            _ => None
          }
        _ => None
      }
    })
    .to_array()
  normalize_language_defs_with_known_types(langs, source_type_names)
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
