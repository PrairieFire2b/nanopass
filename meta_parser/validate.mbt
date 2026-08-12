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
fn validate_language_layer(lang : NanoLangDef) -> Unit raise {
  match lang.layer {
    None => ()
    Some(layer) =>
      if layer.is_empty() {
        raise InvalidLanguage("Language '\{lang.name}' layer cannot be empty")
      }
  }
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
/// The constructor names declared directly in a language's enum body.
fn declared_constructor_names(lang : NanoLangDef) -> Array[String] {
  let names : Array[String] = []
  match lang.type_decl.components {
    @syntax.Variant(cs) => cs.each(c => names.push(c.name.name))
    _ => ()
  }
  names
}

///|
/// Validate `#nano.remove(...)`:
///   - removals require a parent language,
///   - each removed name must exist in the parent's constructors,
///   - a removed name must not also be re-declared in this language's body.
fn validate_removed_constructors(
  lang : NanoLangDef,
  langs : Array[NanoLangDef],
) -> Unit raise {
  if lang.removed.length() == 0 {
    return
  }
  let parent = match lang.extends {
    Some(parent_name) =>
      match find_language_by_name(langs, parent_name) {
        Some(p) => p
        None =>
          raise InvalidLanguage(
            "Language '\{lang.name}' extends unknown language '\{parent_name}'",
          )
      }
    None =>
      raise InvalidLanguage(
        "Language '\{lang.name}' uses #nano.remove but does not extend a parent language",
      )
  }
  let parent_names = declared_constructor_names(parent)
  let own_names = declared_constructor_names(lang)
  lang.removed.each(name => {
    if !parent_names.contains(name) {
      raise InvalidLanguage(
        "Language '\{lang.name}' removes constructor '\{name}' that does not exist in parent '\{parent.name}'",
      )
    }
    if own_names.contains(name) {
      raise InvalidLanguage(
        "Language '\{lang.name}' both removes and re-declares constructor '\{name}'",
      )
    }
  })
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
fn meta_var_base_for_placeholder(lang : NanoLangDef, name : String) -> String? {
  let base = meta_placeholder_base(name)
  if lang.meta_vars.any(meta_var => meta_var.name == base) {
    Some(base)
  } else {
    None
  }
}

///|
fn production_field_by_index(
  prod : ProductionDef,
  index : Int,
) -> ProductionField? {
  for field in prod.fields {
    if field.index == index {
      return Some(field)
    }
  }
  None
}

///|
fn production_field_by_label(
  prod : ProductionDef,
  name : String,
) -> ProductionField? {
  for field in prod.fields {
    match field.label {
      Some(label) => if label == name { return Some(field) }
      None => ()
    }
  }
  None
}

///|
fn named_placeholder_target_key(
  lang : NanoLangDef,
  prod : ProductionDef,
  name : String,
) -> String raise {
  let field = production_field_by_label(prod, name)
  let meta_base = meta_var_base_for_placeholder(lang, name)
  match (field, meta_base) {
    (Some(_), Some(base)) =>
      raise InvalidLanguage(
        "Production '\{lang.name}.\{prod.constr_name}' references '$\{name}' ambiguously as both constructor field and meta-var '$\{base}'",
      )
    (Some(_), None) => "field:\{name}"
    (None, Some(base)) => "meta:\{base}"
    (None, None) =>
      raise InvalidLanguage(
        "Production '\{lang.name}.\{prod.constr_name}' references undeclared meta-var '$\{name}'",
      )
  }
}

///|
fn field_placeholder_name(pattern : FormPattern) -> String {
  match pattern {
    FieldPattern(index~, ..) => "$\{index}"
    NamedFieldPattern(name~, ..) => "$\{name}"
    _ => "<pattern>"
  }
}

///|
fn repeat_field(
  lang_name : String,
  prod : ProductionDef,
  pattern : FormPattern,
) -> ProductionField raise {
  match pattern {
    FieldPattern(index~, prefix~, suffix~) =>
      if !prefix.is_empty() || !suffix.is_empty() {
        raise InvalidLanguage(
          "Production '\{lang_name}.\{prod.constr_name}' repeats '$\{index}' with affix; repeated fields must be bare placeholders",
        )
      } else {
        match production_field_by_index(prod, index) {
          Some(field) => field
          None =>
            raise InvalidLanguage(
              "Production '\{lang_name}.\{prod.constr_name}' references field $\{index} but only has \{prod.fields.length()} fields",
            )
        }
      }
    NamedFieldPattern(name~, prefix~, suffix~) =>
      if !prefix.is_empty() || !suffix.is_empty() {
        raise InvalidLanguage(
          "Production '\{lang_name}.\{prod.constr_name}' repeats '$\{name}' with affix; repeated fields must be bare placeholders",
        )
      } else {
        match production_field_by_label(prod, name) {
          Some(field) => field
          None =>
            raise InvalidLanguage(
              "Production '\{lang_name}.\{prod.constr_name}' repeats '$\{name}' but it is not a constructor field label",
            )
        }
      }
    _ =>
      raise InvalidLanguage(
        "Production '\{lang_name}.\{prod.constr_name}' repeats \{field_placeholder_name(pattern)} but only constructor fields can use ellipsis",
      )
  }
}

///|
fn validate_repeat_pattern_field(
  lang : NanoLangDef,
  prod : ProductionDef,
  pattern : FormPattern,
) -> Unit raise {
  let field = repeat_field(lang.name, prod, pattern)
  if field.type_name != "Array" {
    raise InvalidLanguage(
      "Production '\{lang.name}.\{prod.constr_name}' repeats \{field_placeholder_name(pattern)} but field type is '\{field.type_name}', expected Array",
    )
  }
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
      ignore(named_placeholder_target_key(lang, prod, name))
    FieldPattern(index~, ..) =>
      if index < 0 || index >= prod.fields.length() {
        raise InvalidLanguage(
          "Production '\{lang.name}.\{prod.constr_name}' references field $\{index} but only has \{prod.fields.length()} fields",
        )
      }
    RepeatPattern(item) => {
      validate_form_pattern_fields(lang, prod, item)
      validate_repeat_pattern_field(lang, prod, item)
    }
    ListPattern(items) =>
      items.each(item => validate_form_pattern_fields(lang, prod, item))
  }
}

///|
fn record_named_placeholder(
  seen : Array[(String, String)],
  name : String,
  target_key : String,
) -> Bool {
  for pair in seen {
    let (seen_name, seen_target) = pair
    if seen_name == name {
      return seen_target == target_key
    }
  }
  seen.push((name, target_key))
  true
}

///|
fn validate_named_placeholder_consistency(
  lang : NanoLangDef,
  prod : ProductionDef,
  pattern : FormPattern,
  seen : Array[(String, String)],
) -> Unit raise {
  match pattern {
    AtomPattern(_) | FieldPattern(_) => ()
    NamedFieldPattern(name~, ..) => {
      let target_key = named_placeholder_target_key(lang, prod, name)
      if !record_named_placeholder(seen, name, target_key) {
        raise InvalidLanguage(
          "Production '\{lang.name}.\{prod.constr_name}' references '$\{name}' inconsistently within one form",
        )
      }
    }
    RepeatPattern(item) =>
      validate_named_placeholder_consistency(lang, prod, item, seen)
    ListPattern(items) =>
      items.each(item => {
        validate_named_placeholder_consistency(lang, prod, item, seen)
      })
  }
}

///|
fn validate_form_pattern(
  lang : NanoLangDef,
  prod : ProductionDef,
  pattern : FormPattern,
) -> Unit raise {
  validate_form_pattern_fields(lang, prod, pattern)
  validate_named_placeholder_consistency(lang, prod, pattern, [])
}

///|
fn validate_production_defs(lang : NanoLangDef) -> Unit raise {
  lang.production_defs.each(prod => {
    validate_production_attrs(lang.name, prod)
    prod.surface_forms.each(rule => {
      validate_form_pattern(lang, prod, rule.pattern)
    })
  })
}

///|
fn builtin_field_types() -> Array[String] {
  [
    "Int", "String", "Bool", "Char", "Double", "Float", "Byte", "Bytes", "Unit",
    "BigInt", "UInt", "UInt16", "UInt64", "Int16", "Int64", "Array", "FixedArray",
    "Map", "Option", "Result",
  ]
}

///|
fn add_known_type_name(names : Array[String], name : String) -> Unit {
  if !name.is_empty() && !names.contains(name) {
    names.push(name)
  }
}

///|
fn known_field_type_names(
  langs : Array[NanoLangDef],
  extra_known_types : Array[String],
) -> Array[String] {
  let names = builtin_field_types()
  extra_known_types.each(name => add_known_type_name(names, name))
  langs.each(lang => {
    add_known_type_name(names, lang.type_decl.tycon)
    lang.nonterminals.each(nt => {
      match nt {
        TypeDecl(td) => add_known_type_name(names, td.tycon)
        Constructor(_) => ()
      }
    })
  })
  names
}

///|
fn validate_type_ref(
  lang : NanoLangDef,
  prod : ProductionDef,
  field_index : Int,
  ty : @syntax.Type,
  known : Array[String],
) -> Unit raise {
  match ty {
    @syntax.Name(tys~, ..) => {
      let name = type_to_name(ty)
      if !known.contains(name) {
        raise InvalidLanguage(
          "Production '\{lang.name}.\{prod.constr_name}' field $\{field_index} has unknown type '\{name}'",
        )
      }
      tys.each(arg => validate_type_ref(lang, prod, field_index, arg, known))
    }
    @syntax.Option(ty~, ..) =>
      validate_type_ref(lang, prod, field_index, ty, known)
    @syntax.Tuple(tys~, ..) =>
      tys.each(ty => validate_type_ref(lang, prod, field_index, ty, known))
    @syntax.Any(_) => ()
    _ =>
      raise InvalidLanguage(
        "Production '\{lang.name}.\{prod.constr_name}' field $\{field_index} has unsupported field type",
      )
  }
}

///|
fn validate_field_type_refs(
  langs : Array[NanoLangDef],
  lang : NanoLangDef,
  extra_known_types : Array[String],
) -> Unit raise {
  let known = known_field_type_names(langs, extra_known_types)
  lang.production_defs.each(prod => {
    match prod.source_constr.args {
      Some(args) =>
        args.eachi((index, param) => {
          validate_type_ref(lang, prod, index, param.ty, known)
        })
      None => ()
    }
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
fn hooks_empty(hooks : NanoHooks) -> Bool {
  match (hooks.parse_by, hooks.unparse_by) {
    (None, None) => true
    _ => false
  }
}

///|
fn validate_production_attrs(
  lang_name : String,
  prod : ProductionDef,
) -> Unit raise {
  if prod.inline && prod.infix_operator is Some(_) {
    raise InvalidLanguage(
      "Production '\{lang_name}.\{prod.constr_name}' cannot combine #nano.inline and #nano.infix",
    )
  }
  if prod.infix_operator is Some(_) && prod.fields.length() != 2 {
    raise InvalidLanguage(
      "Production '\{lang_name}.\{prod.constr_name}' uses #nano.infix but has \{prod.fields.length()} fields",
    )
  }
  if prod.canonical_policy is FormOnly &&
    prod.surface_forms.length() == 0 &&
    hooks_empty(prod.hooks) {
    raise InvalidLanguage(
      "Production '\{lang_name}.\{prod.constr_name}' uses #nano.form_only but has no #nano.form or hook",
    )
  }
}

///|
fn generated_language_names(lang : NanoLangDef) -> Array[String] {
  ["parse_\{lang.name}", "unparse_\{lang.name}"]
}

///|
fn generated_name_owner(
  generated : Array[(String, String)],
  name : String,
) -> String? {
  for pair in generated {
    let (generated_name, owner) = pair
    if generated_name == name {
      return Some(owner)
    }
  }
  None
}

///|
fn validate_unique_generated_names(langs : Array[NanoLangDef]) -> Unit raise {
  let seen : Array[(String, String)] = []
  langs.each(lang => {
    generated_language_names(lang).each(name => {
      match generated_name_owner(seen, name) {
        Some(owner) =>
          raise InvalidLanguage(
            "Generated name '\{name}' for language '\{lang.name}' collides with language '\{owner}'",
          )
        None => seen.push((name, lang.name))
      }
    })
  })
}

///|
fn validate_hook_generated_name_collisions(
  langs : Array[NanoLangDef],
) -> Unit raise {
  let generated : Array[(String, String)] = []
  langs.each(lang => {
    generated_language_names(lang).each(name => {
      generated.push((name, lang.name))
    })
  })
  langs.each(lang => {
    lang.production_defs.each(prod => {
      match prod.hooks.parse_by {
        Some(hook) =>
          match generated_name_owner(generated, hook) {
            Some(owner) =>
              raise InvalidLanguage(
                "Production '\{lang.name}.\{prod.constr_name}' parse hook '\{hook}' collides with generated name for language '\{owner}'",
              )
            None => ()
          }
        None => ()
      }
      match prod.hooks.unparse_by {
        Some(hook) =>
          match generated_name_owner(generated, hook) {
            Some(owner) =>
              raise InvalidLanguage(
                "Production '\{lang.name}.\{prod.constr_name}' unparse hook '\{hook}' collides with generated name for language '\{owner}'",
              )
            None => ()
          }
        None => ()
      }
    })
  })
}

///|
fn validate_generated_name_collisions(langs : Array[NanoLangDef]) -> Unit raise {
  validate_unique_generated_names(langs)
  validate_hook_generated_name_collisions(langs)
}

///|
fn raw_nonterminal_positions(lang : NanoLangDef) -> Array[NonTerminalPosition] {
  let positions : Array[NonTerminalPosition] = [
    {
      name: lang.type_decl.tycon,
      introduced_by: lang.name,
      kind: RootNonTerminal,
    },
  ]
  lang.nonterminals.each(nt => {
    match nt {
      TypeDecl(td) =>
        positions.push({
          name: td.tycon,
          introduced_by: lang.name,
          kind: ExternalNonTerminal,
        })
      Constructor(_) => ()
    }
  })
  positions
}

///|
fn inherited_nonterminal_position(
  pos : NonTerminalPosition,
) -> NonTerminalPosition {
  {
    name: pos.name,
    introduced_by: pos.introduced_by,
    kind: InheritedNonTerminal,
  }
}

///|
fn effective_nonterminal_positions(
  lang : NanoLangDef,
  langs : Array[NanoLangDef],
) -> Array[NonTerminalPosition] raise {
  let positions : Array[NonTerminalPosition] = []
  match lang.extends {
    Some(parent_name) =>
      match find_language_by_name(langs, parent_name) {
        Some(parent) =>
          effective_nonterminal_positions(parent, langs).each(pos => {
            positions.push(inherited_nonterminal_position(pos))
          })
        None =>
          raise InvalidLanguage(
            "Language '\{lang.name}' extends unknown language '\{parent_name}'",
          )
      }
    None => ()
  }
  raw_nonterminal_positions(lang).each(pos => positions.push(pos))
  positions
}

///|
fn entry_position_candidates(
  positions : Array[NonTerminalPosition],
) -> Array[String] {
  let candidates : Array[String] = []
  positions.each(pos => {
    if !candidates.contains(pos.name) {
      candidates.push(pos.name)
    }
  })
  candidates
}

///|
fn entry_position_sources(positions : Array[NonTerminalPosition]) -> String {
  positions
  .map(pos => "\{pos.name} from language '\{pos.introduced_by}'")
  .join(", ")
}

///|
fn resolve_entry_position(
  lang : NanoLangDef,
  entry : String,
  positions : Array[NonTerminalPosition],
) -> NonTerminalPosition raise {
  let matches : Array[NonTerminalPosition] = []
  positions.each(pos => if pos.name == entry { matches.push(pos) })
  match matches.length() {
    1 => matches[0]
    0 => {
      let candidates = entry_position_candidates(positions)
      raise InvalidLanguage(
        "Language '\{lang.name}' entry '\{entry}' is not a known nonterminal (candidates: \{candidates.join(", ")})",
      )
    }
    _ =>
      raise InvalidLanguage(
        "Language '\{lang.name}' entry '\{entry}' is ambiguous across nonterminal positions: \{entry_position_sources(matches)}",
      )
  }
}

///|
fn resolve_language_entry(
  lang : NanoLangDef,
  langs : Array[NanoLangDef],
) -> ResolvedEntry raise {
  let positions = effective_nonterminal_positions(lang, langs)
  match lang.entry {
    Some(entry) =>
      {
        origin: ExplicitEntry,
        target: resolve_entry_position(lang, entry, positions),
      }
    None =>
      match lang.extends {
        Some(parent_name) =>
          match find_language_by_name(langs, parent_name) {
            Some(parent) => {
              let parent_entry = resolve_language_entry(parent, langs)
              {
                origin: InheritedEntry(parent_name),
                target: resolve_entry_position(
                  lang,
                  parent_entry.target.name,
                  positions,
                ),
              }
            }
            None =>
              raise InvalidLanguage(
                "Language '\{lang.name}' extends unknown language '\{parent_name}'",
              )
          }
        None =>
          {
            origin: DefaultEntry,
            target: resolve_entry_position(
              lang,
              lang.type_decl.tycon,
              positions,
            ),
          }
      }
  }
}

///|
fn with_resolved_entry(
  lang : NanoLangDef,
  resolved_entry : ResolvedEntry,
) -> NanoLangDef {
  {
    name: lang.name,
    extends: lang.extends,
    layer: lang.layer,
    entry: lang.entry,
    resolved_entry: Some(resolved_entry),
    meta_vars: lang.meta_vars,
    nonterminals: lang.nonterminals,
    terminals: lang.terminals,
    production_defs: lang.production_defs,
    removed: lang.removed,
    type_decl: lang.type_decl,
  }
}

///|
fn resolve_language_entries(
  langs : Array[NanoLangDef],
) -> Array[NanoLangDef] raise {
  langs.map(lang => {
    with_resolved_entry(lang, resolve_language_entry(lang, langs))
  })
}

///|
fn validate_resolved_language_entry(lang : NanoLangDef) -> Unit raise {
  match lang.resolved_entry {
    Some(_) => ()
    None =>
      raise InvalidLanguage("Language '\{lang.name}' entry was not resolved")
  }
}

///|
fn normalize_language_defs_with_known_types(
  langs : Array[NanoLangDef],
  extra_known_types : Array[String],
) -> Array[NanoLangDef] raise {
  validate_unique_language_names(langs)
  langs.each(validate_language_layer)
  langs.each(lang => validate_extends_chain(lang, langs, [lang.name]))
  langs.each(lang => validate_removed_constructors(lang, langs))
  let resolved_langs = resolve_language_entries(langs)
  validate_generated_name_collisions(resolved_langs)
  resolved_langs.each(validate_resolved_language_entry)
  resolved_langs.each(validate_meta_vars)
  resolved_langs.each(validate_production_defs)
  resolved_langs.each(lang => {
    validate_field_type_refs(resolved_langs, lang, extra_known_types)
  })
  resolved_langs
}

///|
fn validate_language_defs_with_known_types(
  langs : Array[NanoLangDef],
  extra_known_types : Array[String],
) -> Unit raise {
  ignore(normalize_language_defs_with_known_types(langs, extra_known_types))
}

///|
/// Return a copy of this language whose enum body (`type_decl.components`) is
/// replaced with the given constructors. The `production_defs` are rebuilt from
/// those constructors so downstream surface-form/hook metadata stays in sync.
/// Used by downstream packages to feed an expanded constructor set back through
/// the raw-language pipeline without re-implementing `NanoLangDef` construction.
pub fn NanoLangDef::with_constructors(
  self : NanoLangDef,
  constrs : Array[@syntax.ConstrDecl],
) -> NanoLangDef raise {
  let td : @syntax.TypeDecl = {
    ..self.type_decl,
    components: @syntax.Variant(@list.List(constrs[:])),
  }
  let production_defs = constrs.map(c => {
    production_def_from_constr(self.type_decl.tycon, c)
  })
  { ..self, type_decl: td, production_defs }
}

///|
/// Validate the raw language definitions collected from a source file.
///
/// This checks language identity, inheritance shape, effective entry resolution,
/// generated names, field references, and form placeholder consistency.
pub fn validate_language_defs(langs : Array[NanoLangDef]) -> Unit raise {
  validate_language_defs_with_known_types(langs, [])
}

///|
/// Validate and normalize the raw language definitions, returning the same
/// languages with `resolved_entry` populated (explicit / inherited / default).
///
/// Downstream packages (e.g. `language`) use this to expand a group without
/// re-implementing entry inheritance.
pub fn normalize_language_defs(
  langs : Array[NanoLangDef],
  extra_known_types? : Array[String] = [],
) -> Array[NanoLangDef] raise {
  normalize_language_defs_with_known_types(langs, extra_known_types)
}
