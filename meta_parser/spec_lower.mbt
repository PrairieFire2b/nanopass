///|
fn spec_source_path(spec_path : String, source : String) -> String {
  if source.has_prefix("/") {
    source
  } else {
    match spec_path.rev_find("/") {
      Some(index) => spec_path[:index].to_owned() + "/" + source
      None => source
    }
  }
}

///|
fn source_type_decls(
  impls : @list.List[@syntax.Impl],
) -> Array[@syntax.TypeDecl] {
  impls
  .filter_map(impl_ => {
    match impl_ {
      TopTypeDef(type_decl) => Some(type_decl)
      _ => None
    }
  })
  .to_array()
}

///|
fn find_source_type(
  types : Array[@syntax.TypeDecl],
  name : String,
) -> @syntax.TypeDecl raise NanopassParseError {
  for type_decl in types {
    if type_decl.tycon == name {
      return type_decl
    }
  }
  raise InvalidLanguage(".cake: unknown source type '" + name + "'")
}

///|
fn spec_production(
  language : NanoSpecLanguage,
  name : String,
) -> NanoSpecProduction? {
  for production in language.productions {
    if production.name == name {
      return Some(production)
    }
  }
  None
}

///|
fn metadata_from_spec(production : NanoSpecProduction?) -> ProductionMetadata {
  match production {
    Some(production) =>
      {
        patterns: production.forms,
        canonical_policy: if production.form_only {
          FormOnly
        } else {
          Canonical
        },
        hooks: {
          parse_by: production.parse_by,
          unparse_by: production.unparse_by,
        },
        name_alias: None,
        inline: false,
        infix_operator: None,
        contexts: production.contexts,
      }
    None =>
      {
        patterns: [],
        canonical_policy: Canonical,
        hooks: { parse_by: None, unparse_by: None },
        name_alias: None,
        inline: false,
        infix_operator: None,
        contexts: [],
      }
  }
}

///|
fn validate_spec_productions(
  language : NanoSpecLanguage,
  constructors : Array[@syntax.ConstrDecl],
) -> Unit raise NanopassParseError {
  let seen : Map[String, Unit] = Map([])
  for production in language.productions {
    if seen.contains(production.name) {
      raise InvalidLanguage(
        ".cake: production '" +
        language.name +
        "." +
        production.name +
        "' is declared more than once",
      )
    }
    seen[production.name] = ()
    if !constructors.any(c => c.name.name == production.name) {
      raise InvalidLanguage(
        ".cake: unknown production '" +
        language.name +
        "." +
        production.name +
        "'",
      )
    }
  }
}

///|
fn reject_mixed_metadata(
  language : NanoSpecLanguage,
  type_decl : @syntax.TypeDecl,
  constructors : Array[@syntax.ConstrDecl],
) -> Unit raise NanopassParseError {
  if type_decl.attrs.any(is_language_attr) ||
    constructors.any(c => c.attrs.any(attr => attr.raw is [.. "#nano.", ..])) {
    raise InvalidLanguage(
      ".cake: language '" +
      language.name +
      "' cannot mix sidecar metadata with nanopass attributes",
    )
  }
}

///|
fn lower_spec_language(
  language : NanoSpecLanguage,
  spec : NanoSpec,
  types : Array[@syntax.TypeDecl],
) -> NanoLangDef raise NanopassParseError {
  let type_decl = find_source_type(types, language.tycon)
  let constructors = match type_decl.components {
    Variant(constructors) => constructors.to_array()
    _ =>
      raise InvalidLanguage(
        ".cake: language type '" + language.tycon + "' must be an enum",
      )
  }
  reject_mixed_metadata(language, type_decl, constructors)
  validate_spec_productions(language, constructors)
  let external_types = spec.nonterminals.map(name => {
    find_source_type(types, name)
  })
  let nonterminal_names = external_types.map(type_decl => type_decl.tycon)
  let nonterminals : Array[NonTerminal] = []
  let terminals : Array[Terminal] = []
  let production_defs : Array[ProductionDef] = []
  for external in external_types {
    if constructors.any(c => {
        match c.args {
          Some(args) =>
            args.any(param => type_to_name(param.ty) == external.tycon)
          None => false
        }
      }) {
      nonterminals.push(TypeDecl(external))
    }
  }
  for c in constructors {
    production_defs.push(
      production_def_from_metadata(
        type_decl.tycon,
        c,
        metadata_from_spec(spec_production(language, c.name.name)),
      ),
    )
    let self_ref = match c.args {
      Some(args) => args.any(param => type_to_name(param.ty) == type_decl.tycon)
      None => false
    }
    let external_ref = match c.args {
      Some(args) =>
        args.any(param => nonterminal_names.contains(type_to_name(param.ty)))
      None => false
    }
    if self_ref {
      nonterminals.push(Constructor(c))
    } else if !external_ref {
      terminals.push(Terminal(c))
    }
  }
  {
    name: language.name,
    extends: language.extends,
    layer: language.layer,
    entry: language.entry,
    resolved_entry: None,
    meta_vars: language.meta_vars.map(name => { owner: type_decl.tycon, name }),
    nonterminals,
    terminals,
    production_defs,
    removed: language.removed,
    type_decl,
  }
}

///|
/// Load a `.cake` sidecar and lower it with its referenced MoonBit enums.
pub fn find_languages_by_spec_file(path : String) -> Array[NanoLangDef] raise {
  let spec = parse_nano_spec(@fs.read_file_to_string(path))
  if spec.version != 1 {
    raise InvalidLanguage(".cake: unsupported version \{spec.version}")
  }
  let source_path = spec_source_path(path, spec.source)
  let (impls, reports) = @parser.parse_file(source_path)
  if !reports.is_empty() {
    raise InvalidLanguage(".cake: MoonBit source contains parse errors")
  }
  let types = source_type_decls(impls)
  let known_types = types.map(type_decl => type_decl.tycon)
  let languages = spec.languages.map(language => {
    lower_spec_language(language, spec, types)
  })
  normalize_language_defs_with_known_types(languages, known_types)
}
