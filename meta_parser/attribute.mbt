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
/// Extract the optional `entry` parameter from `#nanopass.language(...)`.
fn get_entry_from_language_attr(attr : @attribute.Attribute) -> String? {
  match attr.parsed {
    Some(Apply(_, props)) =>
      match
        props.find(fn(prop) {
          match prop {
            Labeled("entry", String(_)) => true
            _ => false
          }
        }) {
        Some(Labeled(_, String(entry))) => Some(entry)
        _ => None
      }
    _ => None
  }
}

///|
/// Get the simple type name from a Type AST node
fn type_to_name(ty : @syntax.Type) -> String {
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
fn is_nano_attr(attr : @attribute.Attribute, name : String) -> Bool {
  attr.name() == Some(name) && attr.raw is [.. "#nano.", ..]
}

///|
fn form_string_from_attr(attr : @attribute.Attribute) -> String raise {
  match attr.parsed {
    Some(Apply(_, props)) =>
      match
        props.find(fn(prop) {
          match prop {
            Expr(String(_)) => true
            _ => false
          }
        }) {
        Some(Expr(String(form))) => form
        _ =>
          raise InvalidAttribute("#nano.form expects a string literal payload")
      }
    _ => raise InvalidAttribute("#nano.form expects a string literal payload")
  }
}

///|
fn entry_string_from_attr(attr : @attribute.Attribute) -> String raise {
  match attr.parsed {
    Some(Apply(_, props)) =>
      match
        props.find(fn(prop) {
          match prop {
            Expr(String(_)) => true
            _ => false
          }
        }) {
        Some(Expr(String(entry))) => entry
        _ =>
          raise InvalidAttribute("#nano.entry expects a string literal payload")
      }
    _ => raise InvalidAttribute("#nano.entry expects a string literal payload")
  }
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
fn form_patterns_from_attrs(
  attrs : @list.List[@attribute.Attribute],
) -> Array[FormPattern] raise {
  let patterns : Array[FormPattern] = []
  attrs.each(attr => {
    if is_nano_attr(attr, "form") {
      patterns.push(compile_form_pattern(form_string_from_attr(attr)))
    }
  })
  patterns
}

///|
fn canonical_policy_from_attrs(
  attrs : @list.List[@attribute.Attribute],
) -> CanonicalPolicy {
  if attrs.any(attr => is_nano_attr(attr, "form_only")) {
    FormOnly
  } else {
    Canonical
  }
}

///|
fn production_fields_from_constr(
  c : @syntax.ConstrDecl,
) -> Array[ProductionField] {
  let fields : Array[ProductionField] = []
  match c.args {
    Some(args) =>
      args.eachi(fn(index, param) {
        let label = match param.label {
          Some(label) => Some(label.name)
          None => None
        }
        fields.push({ index, label, type_name: type_to_name(param.ty) })
      })
    None => ()
  }
  fields
}

///|
fn production_def_from_constr(
  owner : String,
  c : @syntax.ConstrDecl,
) -> ProductionDef raise {
  {
    owner,
    constr_name: c.name.name,
    fields: production_fields_from_constr(c),
    patterns: form_patterns_from_attrs(c.attrs),
    canonical_policy: canonical_policy_from_attrs(c.attrs),
    source_constr: c,
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
      @syntax.TopTypeDef(type_decl) =>
        match type_decl.components {
          @syntax.Variant(_) =>
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

  let langs = impls
    .filter_map(impl_ => {
      match impl_ {
        @syntax.TopTypeDef(type_decl) =>
          match type_decl.components {
            @syntax.Variant(constructors) =>
              type_decl.attrs
              .find(fn(attr) { attr.raw is [.. "#nanopass.language", ..] })
              .map(attr => {
                let name = get_name_from_attr(attr)
                let extends = get_extends_from_attr(attr)
                let entry = get_entry_from_attrs(name, attr, type_decl.attrs)
                let tycon = type_decl.tycon

                let nonterminals : Array[NonTerminal] = []
                let terminals : Array[Terminal] = []
                let production_defs : Array[ProductionDef] = []

                // NonTerminal::TypeDecl for each referenced nonterminal type
                nt_types.each(fn(nt_td) {
                  if constructors.any(fn(c) {
                      match c.args {
                        Some(args) =>
                          args.any(fn(p) { type_to_name(p.ty) == nt_td.tycon })
                        None => false
                      }
                    }) {
                    nonterminals.push(NonTerminal::TypeDecl(nt_td))
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
                    nonterminals.push(NonTerminal::Constructor(c))
                  } else if nt_ref {
                    ()
                  } else {
                    terminals.push(Terminal(c))
                  }
                })

                {
                  name,
                  extends,
                  entry,
                  nonterminals,
                  terminals,
                  production_defs,
                  type_decl,
                }
              })
            _ => None
          }
        _ => None
      }
    })
    .to_array()
  validate_language_defs(langs)
  langs
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
