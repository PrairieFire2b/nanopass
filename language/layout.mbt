///|
pub(all) enum ConstructorTarget {
  TreeTarget
  ExtTarget(String)
} derive(Debug, Eq)

///|
pub(all) struct ConstructorLayout {
  lang_name : String
  source_tycon : String
  constr_name : String
  source_constr : @syntax.ConstrDecl
  target : ConstructorTarget
  field_order : Array[Int]
  tree_extra_type : @syntax.Type?
}

///|
pub(all) struct TreeConstructorLayout {
  constr_name : String
  field_types : Array[String]
}

///|
pub(all) struct TreeLayout {
  tycon : String
  params : Array[String]
  constructors : Array[TreeConstructorLayout]
  decl : @syntax.TypeDecl
}

///|
pub(all) struct WrapperLayout {
  lang_name : String
  tycon : String
  tree_args : Array[String]
  decl : @syntax.TypeDecl
}

///|
pub(all) struct ExtEnumLayout {
  lang_name : String
  tycon : String
  constructors : Array[String]
  decl : @syntax.TypeDecl
}

///|
pub(all) struct GeneratedLanguageLayout {
  group : Array[@meta_parser.NanoLangDef]
  tree : TreeLayout
  wrappers : Array[WrapperLayout]
  ext_enums : Array[ExtEnumLayout]
  constructors : Array[ConstructorLayout]
  external_types : Array[@mbti_ast.Sig]
}

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
) -> Array[TreeConstructorLayout] {
  let constructors : Array[TreeConstructorLayout] = []
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
) -> Array[WrapperLayout] {
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
) -> Array[ExtEnumLayout] {
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
fn constructor_layouts(
  langs : Array[@meta_parser.NanoLangDef],
  tree : @syntax.TypeDecl,
) -> Array[ConstructorLayout] raise {
  if langs.length() == 0 {
    raise NoLanguageFound
  }
  let tree_names = tree_constructor_names(tree)
  let base = langs[0]
  let base_tycon = base.type_decl.tycon
  let base_map = make_base_map(base)
  let layouts : Array[ConstructorLayout] = []

  match base.type_decl.components {
    @syntax.Variant(cs) =>
      cs.each(constr => {
        if tree_names.contains(constr.name.name) {
          layouts.push({
            lang_name: base.name,
            source_tycon: base_tycon,
            constr_name: constr.name.name,
            source_constr: constr,
            target: TreeTarget,
            field_order: identity_field_order(constr),
            tree_extra_type: None,
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
                  target: TreeTarget,
                  field_order: shared_field_order(
                    base_constr, constr, base_tycon, tycon,
                  ),
                  tree_extra_type: shared_extra_type(
                    base_constr, constr, base_tycon, tycon,
                  ),
                })
              }
            None =>
              layouts.push({
                lang_name: lang.name,
                source_tycon: tycon,
                constr_name: constr.name.name,
                source_constr: constr,
                target: ExtTarget(tycon + "Ext"),
                field_order: identity_field_order(constr),
                tree_extra_type: None,
              })
          }
        })
      _ => ()
    }
  }
  layouts
}

///|
pub fn Language::layout(self : Language) -> GeneratedLanguageLayout raise {
  let (tree_decl, ext_enum_decls) = gen_tree_def(
    self.group,
    _mbti=self.interface,
  )
  let tree_params = type_decl_params(tree_decl)
  let wrapper_decls = struct_wrappers(self.group, tree_params, tree_decl.loc)
  let external_types = find_external_types(
    self.group,
    tree_decl,
    self.interface,
  )
  {
    group: self.group,
    tree: {
      tycon: tree_decl.tycon,
      params: tree_params,
      constructors: tree_constructor_layouts(tree_decl),
      decl: tree_decl,
    },
    wrappers: wrapper_layouts(self.group, wrapper_decls),
    ext_enums: ext_enum_layouts(self.group, ext_enum_decls),
    constructors: constructor_layouts(self.group, tree_decl),
    external_types,
  }
}
