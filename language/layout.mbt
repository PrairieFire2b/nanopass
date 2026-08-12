///|
fn type_decl_params(decl : @syntax.TypeDecl) -> Array[String] {
  decl.params.filter_map(param => param.name).to_array()
}

///|
fn constr_arg_count(constr : @syntax.ConstrDecl) -> Int {
  match constr.args {
    Some(args) => args.length()
    None => 0
  }
}

///|
fn identity_field_order(constr : @syntax.ConstrDecl) -> Array[Int] {
  let order : Array[Int] = []
  for i in 0..<constr_arg_count(constr) {
    order.push(i)
  }
  order
}

///|
fn constr_field_types(constr : @syntax.ConstrDecl) -> Array[String] {
  let names : Array[String] = []
  match constr.args {
    Some(args) => args.each(param => names.push(type_name(param.ty)))
    None => ()
  }
  names
}

///|
fn tree_constructor_layouts(
  tree : @syntax.TypeDecl,
) -> Array[@layout.TreeConstructorLayout] {
  let constructors : Array[@layout.TreeConstructorLayout] = []
  match tree.components {
    @syntax.Variant(cs) =>
      cs.each(constr => {
        constructors.push({
          constr_name: constr.name.name,
          field_types: constr_field_types(constr),
        })
      })
    _ => ()
  }
  constructors
}

///|
fn tree_constructor_names(tree : @syntax.TypeDecl) -> Array[String] {
  tree_constructor_layouts(tree).map(layout => layout.constr_name)
}

///|
fn wrapper_tree_args(wrapper : @syntax.TypeDecl) -> Array[String] {
  match wrapper.components {
    @syntax.TupleStruct(fields) => {
      let args : Array[String] = []
      fields.each(field => {
        match field {
          @syntax.Name(tys~, ..) => tys.each(ty => args.push(type_name(ty)))
          _ => ()
        }
      })
      args
    }
    _ => []
  }
}

///|
fn find_lang_by_tycon(
  langs : Array[@meta_parser.NanoLangDef],
  tycon : String,
) -> @meta_parser.NanoLangDef? {
  for i in 0..<langs.length() {
    if langs[i].type_decl.tycon == tycon {
      return Some(langs[i])
    }
  }
  None
}

///|
fn find_lang_by_ext_tycon(
  langs : Array[@meta_parser.NanoLangDef],
  ext_tycon : String,
) -> @meta_parser.NanoLangDef? {
  for i in 0..<langs.length() {
    if langs[i].type_decl.tycon + "Ext" == ext_tycon {
      return Some(langs[i])
    }
  }
  None
}

///|
fn wrapper_layouts(
  langs : Array[@meta_parser.NanoLangDef],
  wrappers : Array[@syntax.TypeDecl],
) -> Array[@layout.WrapperLayout] {
  wrappers.map(wrapper => {
    let lang_name = match find_lang_by_tycon(langs, wrapper.tycon) {
      Some(lang) => lang.name
      None => wrapper.tycon
    }
    {
      lang_name,
      tycon: wrapper.tycon,
      tree_args: wrapper_tree_args(wrapper),
      decl: wrapper,
    }
  })
}

///|
fn ext_enum_layouts(
  langs : Array[@meta_parser.NanoLangDef],
  ext_enums : Array[@syntax.TypeDecl],
) -> Array[@layout.ExtEnumLayout] {
  ext_enums.map(ext_enum => {
    let lang_name = match find_lang_by_ext_tycon(langs, ext_enum.tycon) {
      Some(lang) => lang.name
      None => ext_enum.tycon
    }
    let constructors : Array[String] = []
    match ext_enum.components {
      @syntax.Variant(cs) =>
        cs.each(constr => constructors.push(constr.name.name))
      _ => ()
    }
    { lang_name, tycon: ext_enum.tycon, constructors, decl: ext_enum }
  })
}

///|
fn shared_field_order(
  base_c : @syntax.ConstrDecl,
  deriv_c : @syntax.ConstrDecl,
  base_tycon : String,
  deriv_tycon : String,
) -> Array[Int] {
  let base_args = match base_c.args {
    Some(args) => args.to_array()
    None => []
  }
  let deriv_args = match deriv_c.args {
    Some(args) => args.to_array()
    None => []
  }
  let used : Array[Int] = []
  let order : Array[Int] = []
  base_args.eachi(fn(i, p) {
    let wanted = type_name(p.ty)
    let picked = if wanted == base_tycon {
      first_unused_arg_with_type(deriv_args, used, deriv_tycon)
    } else {
      first_unused_arg_with_type(deriv_args, used, wanted)
    }
    let picked = match picked {
      Some(index) => Some(index)
      None =>
        if i < deriv_args.length() && !used.contains(i) {
          Some(i)
        } else {
          first_unused_arg(deriv_args, used)
        }
    }
    match picked {
      Some(index) => {
        used.push(index)
        order.push(index)
      }
      None => ()
    }
  })
  for i in 0..<deriv_args.length() {
    if !used.contains(i) {
      order.push(i)
      return order
    }
  }
  order
}

///|
/// Classify every constructor into a `ConstructorLayout`.
///
/// Note: the shared/own decision here (base constructor present => `TreeTarget`,
/// derived-only => `ExtTarget`) is the same distinction that `expand` records as
/// `ConstructorOrigin` (`Shared` / `Own`). This duplication is intentional:
/// layout additionally needs the field reorder and tree padding, which are
/// derived by comparing against the base constructor and the tree shape and
/// cannot live in `expand` without coupling it to the tree layout. The invariant
/// "layout target kind agrees with expand origin" is locked by
/// `layout_expand_consistency_wbtest.mbt`.
fn surface_forms_for(
  langs : Array[@meta_parser.NanoLangDef],
  tycon : String,
  constr_name : String,
) -> Array[@meta_parser.ProductionFormRule] {
  for lang in langs {
    if lang.type_decl.tycon == tycon {
      for pd in lang.production_defs {
        if pd.constr_name == constr_name {
          return pd.surface_forms
        }
      }
    }
  }
  []
}

///|
/// Find the constructor-level hooks for a constructor by (tycon, name).
fn hooks_for(
  langs : Array[@meta_parser.NanoLangDef],
  tycon : String,
  constr_name : String,
) -> @meta_parser.NanoHooks {
  for lang in langs {
    if lang.type_decl.tycon == tycon {
      for pd in lang.production_defs {
        if pd.constr_name == constr_name {
          return pd.hooks
        }
      }
    }
  }
  { parse_by: None, unparse_by: None }
}

///|
fn constructor_layouts(
  langs : Array[@meta_parser.NanoLangDef],
  tree : @syntax.TypeDecl,
) -> Array[@layout.ConstructorLayout] raise {
  if langs.length() == 0 {
    raise NoLanguageFound
  }
  let tree_names = tree_constructor_names(tree)
  let base = langs[0]
  let base_tycon = base.type_decl.tycon
  let base_map = make_base_map(base)
  let layouts : Array[@layout.ConstructorLayout] = []

  match base.type_decl.components {
    @syntax.Variant(cs) =>
      cs.each(constr => {
        if tree_names.contains(constr.name.name) {
          layouts.push({
            lang_name: base.name,
            source_tycon: base_tycon,
            constr_name: constr.name.name,
            source_constr: constr,
            target: @layout.TreeTarget,
            field_order: identity_field_order(constr),
            tree_extra_type: None,
            surface_forms: surface_forms_for(
              langs,
              base_tycon,
              constr.name.name,
            ),
            hooks: hooks_for(langs, base_tycon, constr.name.name),
          })
        }
      })
    _ => ()
  }

  for i in 1..<langs.length() {
    let lang = langs[i]
    let tycon = lang.type_decl.tycon
    match lang.type_decl.components {
      @syntax.Variant(cs) =>
        cs.each(constr => {
          match base_map.get(constr.name.name) {
            Some(base_constr) =>
              if tree_names.contains(constr.name.name) {
                layouts.push({
                  lang_name: lang.name,
                  source_tycon: tycon,
                  constr_name: constr.name.name,
                  source_constr: constr,
                  target: @layout.TreeTarget,
                  field_order: shared_field_order(
                    base_constr, constr, base_tycon, tycon,
                  ),
                  tree_extra_type: shared_extra_type(
                    base_constr, constr, base_tycon, tycon,
                  ),
                  surface_forms: surface_forms_for(
                    langs,
                    tycon,
                    constr.name.name,
                  ),
                  hooks: hooks_for(langs, tycon, constr.name.name),
                })
              }
            None =>
              layouts.push({
                lang_name: lang.name,
                source_tycon: tycon,
                constr_name: constr.name.name,
                source_constr: constr,
                target: @layout.ExtTarget(tycon + "Ext"),
                field_order: identity_field_order(constr),
                tree_extra_type: None,
                surface_forms: surface_forms_for(langs, tycon, constr.name.name),
                hooks: hooks_for(langs, tycon, constr.name.name),
              })
          }
        })
      _ => ()
    }
  }

  // External nonterminals (e.g. an enum tagged `#nanopass.nonterminal` such as
  // `Type`) are plain enums, not merged into the shared `Tree`. Each of their
  // constructors is a `RawTarget`. They may be referenced by several languages
  // in the group, so deduplicate by (source_tycon, constr_name).
  let seen_raw : Map[String, Unit] = {}
  langs.each(lang => {
    lang.nonterminals.each(nt => {
      match nt {
        TypeDecl(td) =>
          match td.components {
            @syntax.Variant(cs) =>
              cs.each(constr => {
                let key = td.tycon + "." + constr.name.name
                if !seen_raw.contains(key) {
                  seen_raw[key] = ()
                  layouts.push({
                    lang_name: lang.name,
                    source_tycon: td.tycon,
                    constr_name: constr.name.name,
                    source_constr: constr,
                    target: @layout.RawTarget,
                    field_order: identity_field_order(constr),
                    tree_extra_type: None,
                    surface_forms: [],
                    hooks: { parse_by: None, unparse_by: None },
                  })
                }
              })
            _ => ()
          }
        _ => ()
      }
    })
  })
  layouts
}

///|
/// Rebuild each language's `type_decl` so its enum body reflects the expanded
/// constructor set: inherited-but-not-declared constructors are pulled in from
/// the parent, `#nano.remove(...)` constructors are dropped, and same-name
/// declarations override. Self-references in inherited constructors are rewritten
/// to the deriving language's tycon (e.g. `Add(Expr, Expr)` -> `Add(Expr2, Expr2)`).
///
/// Downstream layout/tree/wrapper generation consumes this expanded group, so it
/// automatically honors inheritance and removal without re-implementing them.
fn Language::expanded_group(
  self : Language,
) -> Array[@meta_parser.NanoLangDef] raise {
  let group = expand_language_group(
    self.group,
    extra_known_types=mbti_type_names(self.interface),
  )
  group.languages.map(el => {
    let constrs = el.constructors.map(ec => ec.constr)
    el.def.with_constructors(constrs)
  })
}

///|
pub fn Language::layout(
  self : Language,
) -> @layout.GeneratedLanguageLayout raise {
  let group = self.expanded_group()
  let (tree_decl, ext_enum_decls) = gen_tree_def(group, _mbti=self.interface)
  let tree_params = type_decl_params(tree_decl)
  let wrapper_decls = struct_wrappers(group, tree_params, tree_decl.loc)
  let external_types = find_external_types(group, tree_decl, self.interface)
  {
    group,
    tree: {
      tycon: tree_decl.tycon,
      params: tree_params,
      constructors: tree_constructor_layouts(tree_decl),
      decl: tree_decl,
    },
    wrappers: wrapper_layouts(group, wrapper_decls),
    ext_enums: ext_enum_layouts(group, ext_enum_decls),
    constructors: constructor_layouts(group, tree_decl),
    external_types,
  }
}
