///|
/// Resolve a source location, parse the file for language definitions,
/// filter by transitive `extends` chain, and resolve the package's `.mbti` interface.
#callsite(autofill(loc, _args_loc))
pub fn Language::def(
  name? : String = "",
  loc~ : SourceLoc,
  _args_loc~ : ArgsLoc,
) -> Language raise {
  let repr = loc |> @meta_parser.resolve
  let mbti = @meta_parser.resolve_mbti(repr)
  let all_langs = @meta_parser.find_languages(repr)
  let langs = all_langs.filter(lang => belongs_to(lang, name, all_langs))
  { name, group: langs, interface: mbti }
}

///|
/// Load language definitions from a specific source file (without relying on `#callsite`).
pub fn Language::from_file(
  name? : String = "",
  path~ : String,
  mod~ : String,
) -> Language raise {
  let all_langs = @meta_parser.find_languages_by_file(path)
  let langs = all_langs.filter(lang => belongs_to(lang, name, all_langs))
  // Resolve mbti for the module
  let pkg = match path.split("/").collect() {
    [p, ..] => p.to_owned()
    _ => path
  }
  let repr = @meta_parser.SourceLocRepr::for_pkg(pkg~, mod~)
  let mbti = @meta_parser.resolve_mbti(repr)
  { name, group: langs, interface: mbti }
}

///|
fn find_lang_by_name(
  langs : Array[@meta_parser.NanoLangDef],
  name : String,
) -> @meta_parser.NanoLangDef? {
  for i in 0..<langs.length() {
    if langs[i].name == name {
      return Some(langs[i])
    }
  }
  None
}

///|
fn extends_chain(
  name : String,
  langs : Array[@meta_parser.NanoLangDef],
) -> Array[String] {
  match find_lang_by_name(langs, name) {
    Some(lang) =>
      match lang.extends {
        Some(parent) => [parent] + extends_chain(parent, langs)
        None => []
      }
    None => []
  }
}

///|
fn belongs_to(
  lang : @meta_parser.NanoLangDef,
  target : String,
  all_langs : Array[@meta_parser.NanoLangDef],
) -> Bool {
  lang.name == target || extends_chain(lang.name, all_langs).contains(target)
}

///|
/// All type/alias names declared in the package interface. Used to feed the
/// normalization step (field-type reference checks) when expanding a group.
fn mbti_type_names(mbti : @meta_parser.Mbti) -> Array[String] {
  let Mbti(mbti_ast) = mbti
  let names : Array[String] = []
  mbti_ast.sigs.each(pair => {
    let (sig, _) = pair
    match sig {
      Type(type_sig) => names.push(type_sig.name.name)
      Alias(alias_sig) =>
        match alias_sig {
          TypeAlias(name~, ..) => names.push(name.name)
          _ => ()
        }
      _ => ()
    }
  })
  names
}

///|
/// Find types referenced by the generated tree (or the original language definitions)
/// that are not part of the tree itself, using the mbti to confirm their existence.
fn find_external_types(
  langs : Array[@meta_parser.NanoLangDef],
  tree : @syntax.TypeDecl,
  mbti : @meta_parser.Mbti,
) -> Array[@mbti_ast.Sig] {
  let param_names : Array[String] = []
  match tree.components {
    Variant(cs) =>
      cs.each(fn(c) {
        match c.args {
          Some(args) =>
            args.each(fn(p) {
              let name = type_name(p.ty)
              if name != "" && !param_names.contains(name) {
                param_names.push(name)
              }
            })
          None => ()
        }
      })
    _ => ()
  }

  let nt_td_names = langs.fold(init=[], fn(names, lang) {
    lang.nonterminals.fold(init=names, fn(ns, nt) {
      match nt {
        TypeDecl(td) => if ns.contains(td.tycon) { ns } else { [td.tycon] + ns }
        _ => ns
      }
    })
  })

  let tree_params : Array[String] = []
  tree.params.each(fn(p) {
    match p.name {
      Some(n) => if !tree_params.contains(n) { tree_params.push(n) }
      None => ()
    }
  })

  let excluded = builtin_types() + tree_params + ["Self_"]
  let external = (param_names + nt_td_names).filter(fn(name) {
    !excluded.contains(name)
  })

  let Mbti(mbti_ast) = mbti
  external.filter_map(fn(target) {
    mbti_ast.sigs
    .find(fn(pair) {
      let (sig, _) = pair
      match sig {
        Type(type_sig) => type_sig.name.name == target
        Alias(alias_sig) =>
          match alias_sig {
            TypeAlias(name~, ..) => name.name == target
            _ => false
          }
        _ => false
      }
    })
    .map(fn(pair) { pair.0 })
  })
}
