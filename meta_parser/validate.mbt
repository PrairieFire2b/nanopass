///|
fn find_language_by_name(
  langs : Array[NanoLangDef],
  name : String,
) -> NanoLangDef? {
  for i in 0..<langs.length() {
    if langs[i].name == name {
      return Some(langs[i])
    }
  }
  None
}

///|
fn validate_unique_language_names(langs : Array[NanoLangDef]) -> Unit raise {
  let seen : Array[String] = []
  langs.each(lang => {
    if seen.contains(lang.name) {
      raise InvalidLanguage("Duplicate language definition '\{lang.name}'")
    }
    seen.push(lang.name)
  })
}

///|
fn validate_extends_chain(
  lang : NanoLangDef,
  langs : Array[NanoLangDef],
  seen : Array[String],
) -> Unit raise {
  match lang.extends {
    None => ()
    Some(parent_name) => {
      if seen.contains(parent_name) {
        raise InvalidLanguage(
          "Cyclic language inheritance involving '\{parent_name}'",
        )
      }
      match find_language_by_name(langs, parent_name) {
        Some(parent) =>
          validate_extends_chain(parent, langs, [parent_name] + seen)
        None =>
          raise InvalidLanguage(
            "Language '\{lang.name}' extends unknown language '\{parent_name}'",
          )
      }
    }
  }
}

///|
fn meta_placeholder_end(chars : Array[Char], end : Int) -> Int {
  if end <= 0 {
    0
  } else {
    let c = chars[end - 1]
    if c.is_ascii_digit() || c == '*' {
      meta_placeholder_end(chars, end - 1)
    } else {
      end
    }
  }
}

///|
fn meta_placeholder_base(name : String) -> String {
  let chars = name.to_array()
  let end = meta_placeholder_end(chars, chars.length())
  if end == 0 {
    name
  } else {
    String::from_array(chars[0:end])
  }
}

///|
fn production_has_field_label(prod : ProductionDef, name : String) -> Bool {
  prod.fields.any(field => {
    match field.label {
      Some(label) => label == name
      None => false
    }
  })
}

///|
fn language_has_meta_var(lang : NanoLangDef, name : String) -> Bool {
  let base = meta_placeholder_base(name)
  lang.meta_vars.any(meta_var => meta_var.name == base)
}

///|
fn validate_form_pattern_fields(
  lang : NanoLangDef,
  prod : ProductionDef,
  pattern : FormPattern,
) -> Unit raise {
  match pattern {
    AtomPattern(_) => ()
    NamedFieldPattern(name~, ..) =>
      if !production_has_field_label(prod, name) &&
        !language_has_meta_var(lang, name) {
        raise InvalidLanguage(
          "Production '\{lang.name}.\{prod.constr_name}' references undeclared meta-var '$\{name}'",
        )
      }
    FieldPattern(index~, ..) =>
      if index < 0 || index >= prod.fields.length() {
        raise InvalidLanguage(
          "Production '\{lang.name}.\{prod.constr_name}' references field $\{index} but only has \{prod.fields.length()} fields",
        )
      }
    ListPattern(items) =>
      items.each(item => validate_form_pattern_fields(lang, prod, item))
  }
}

///|
fn validate_production_defs(lang : NanoLangDef) -> Unit raise {
  lang.production_defs.each(prod => {
    prod.patterns.each(pattern => {
      validate_form_pattern_fields(lang, prod, pattern)
    })
    validate_production_attrs(lang.name, prod)
  })
}

///|
fn validate_meta_vars(lang : NanoLangDef) -> Unit raise {
  let seen : Array[String] = []
  lang.meta_vars.each(meta_var => {
    if meta_var.name.is_empty() {
      raise InvalidLanguage(
        "Meta-var declaration for owner '\{meta_var.owner}' cannot be empty",
      )
    }
    let key = meta_var.owner + "." + meta_var.name
    if seen.contains(key) {
      raise InvalidLanguage(
        "Duplicate meta-var '\{meta_var.name}' for owner '\{meta_var.owner}'",
      )
    }
    seen.push(key)
  })
}

///|
fn production_has_attr(prod : ProductionDef, name : String) -> Bool {
  prod.source_constr.attrs.any(attr => is_nano_attr(attr, name))
}

///|
fn validate_production_attrs(
  lang_name : String,
  prod : ProductionDef,
) -> Unit raise {
  if production_has_attr(prod, "inline") && production_has_attr(prod, "infix") {
    raise InvalidLanguage(
      "Production '\{lang_name}.\{prod.constr_name}' cannot combine #nano.inline and #nano.infix",
    )
  }
  if production_has_attr(prod, "infix") && prod.fields.length() != 2 {
    raise InvalidLanguage(
      "Production '\{lang_name}.\{prod.constr_name}' uses #nano.infix but has \{prod.fields.length()} fields",
    )
  }
  if prod.canonical_policy is FormOnly &&
    prod.patterns.length() == 0 &&
    !production_has_attr(prod, "parse_by") &&
    !production_has_attr(prod, "unparse_by") {
    raise InvalidLanguage(
      "Production '\{lang_name}.\{prod.constr_name}' uses #nano.form_only but has no #nano.form or hook",
    )
  }
}

///|
fn entry_candidates(lang : NanoLangDef) -> Array[String] {
  let candidates : Array[String] = [lang.type_decl.tycon]
  lang.nonterminals.each(nt => {
    match nt {
      TypeDecl(td) =>
        if !candidates.contains(td.tycon) {
          candidates.push(td.tycon)
        }
      Constructor(_) => ()
    }
  })
  candidates
}

///|
fn validate_language_entry(lang : NanoLangDef) -> Unit raise {
  match lang.entry {
    None => ()
    Some(entry) => {
      let candidates = entry_candidates(lang)
      if !candidates.contains(entry) {
        raise InvalidLanguage(
          "Language '\{lang.name}' entry '\{entry}' is not a known nonterminal (candidates: \{candidates.join(", ")})",
        )
      }
    }
  }
}

///|
/// Validate the raw language definitions collected from a source file.
///
/// This is intentionally a small first slice of the plan_4 validator: it checks
/// language identity, inheritance shape, and positional form field references
/// before later phases add meta-var and generated-name diagnostics.
pub fn validate_language_defs(langs : Array[NanoLangDef]) -> Unit raise {
  validate_unique_language_names(langs)
  langs.each(lang => validate_extends_chain(lang, langs, [lang.name]))
  langs.each(validate_language_entry)
  langs.each(validate_meta_vars)
  langs.each(validate_production_defs)
}
