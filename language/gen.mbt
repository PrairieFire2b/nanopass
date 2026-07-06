///|
/// Generate the complete set of `Impl`s for this language group;
/// The result can be formatted with `@fmt.impls_to_string`.
pub fn Language::gen(self : Language) -> @list.List[@syntax.Impl] raise {
  let (tree, ext_enums) = gen_tree_def(self.group, _mbti=self.interface)
  let tree_params = tree.params.filter_map(p => p.name)
  let wrappers = struct_wrappers(self.group, tree_params.to_array(), tree.loc)
  let wrapper_impls = wrappers.map(fn(w) { @syntax.TopTypeDef(w) })
  let ext_impls = ext_enums.map(fn(e) { @syntax.TopTypeDef(e) })
  let external_impls = find_external_types(self.group, tree, self.interface).filter_map(
    sig_to_impl,
  )
  @list.List(
    [@syntax.TopTypeDef(tree)] + wrapper_impls + ext_impls + external_impls,
  )
}

///|
fn type_name(ty : @syntax.Type) -> String {
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
fn self_type(loc : @basic.Location) -> @syntax.Type {
  @syntax.Name(
    constr_id={ id: @syntax.LongIdent::Ident(name="Self_"), loc },
    tys=@list.empty(),
    loc~,
  )
}

///|
fn merge_constr(
  base_c : @syntax.ConstrDecl,
  deriv_c : @syntax.ConstrDecl,
  base_tycon : String,
  _deriv_tycon : String,
  loc : @basic.Location,
) -> (@syntax.ConstrDecl, String?) {
  let base_count = match base_c.args {
    Some(args) => args.length()
    None => 0
  }
  let deriv_count = match deriv_c.args {
    Some(args) => args.length()
    None => 0
  }
  let extra_var : String? = if deriv_count > base_count {
    Some(base_c.name.name + "E")
  } else {
    None
  }

  let merged_args : Array[@syntax.ConstrParam] = []
  match base_c.args {
    Some(args) =>
      args.each(fn(p) {
        let new_ty = if type_name(p.ty) == base_tycon {
          self_type(loc)
        } else {
          p.ty
        }
        merged_args.push({ ..p, ty: new_ty })
      })
    None => ()
  }
  match extra_var {
    Some(name) => {
      let var_ty = @syntax.Name(
        constr_id={ id: @syntax.LongIdent::Ident(name~), loc },
        tys=@list.empty(),
        loc~,
      )
      merged_args.push({ label: None, mut_: false, ty: var_ty })
    }
    None => ()
  }
  let merged_c = {
    ..base_c,
    args: if merged_args.length() > 0 {
      Some(@list.List(merged_args[:]))
    } else {
      None
    },
  }
  (merged_c, extra_var)
}

///|
fn make_base_map(
  base : @meta_parser.NanoLangDef,
) -> Map[String, @syntax.ConstrDecl] {
  let m : Map[String, @syntax.ConstrDecl] = {}
  match base.type_decl.components {
    @syntax.Variant(cs) => cs.each(fn(c) { m[c.name.name] = c })
    _ => ()
  }
  m
}

///|
fn replace_self_refs(
  constr : @syntax.ConstrDecl,
  tycon : String,
  loc : @basic.Location,
) -> @syntax.ConstrDecl {
  let new_args = match constr.args {
    Some(args) => {
      let params : Array[@syntax.ConstrParam] = []
      args.each(fn(p) {
        let new_ty = if type_name(p.ty) == tycon {
          self_type(loc)
        } else {
          p.ty
        }
        params.push({ ..p, ty: new_ty })
      })
      Some(@list.List(params[:]))
    }
    None => None
  }
  { ..constr, args: new_args }
}

///|
fn make_type_decl(
  tycon : String,
  constrs : Array[@syntax.ConstrDecl],
  type_params : Array[String],
  loc : @basic.Location,
) -> @syntax.TypeDecl {
  let binders = @list.List(
    type_params.map(fn(name) {
      @syntax.TypeDeclBinder::{ name: Some(name), loc }
    }),
  )
  {
    attrs: @list.empty(),
    components: @syntax.Variant(@list.List(constrs[:])),
    deriving: @list.empty(),
    doc: @syntax.DocString::empty(),
    is_declare: false,
    loc,
    params: binders,
    tycon,
    tycon_loc: loc,
    type_vis: @syntax.Visibility::Default,
  }
}

///|
fn merge_shared_constrs(
  deriv_pairs : Array[(@syntax.ConstrDecl, String)],
  base_map : Map[String, @syntax.ConstrDecl],
  base_tycon : String,
  loc : @basic.Location,
) -> (Array[@syntax.ConstrDecl], Array[String]) {
  let shared = deriv_pairs.filter(fn(pair) {
    let (dc, _) = pair
    base_map.get(dc.name.name) is Some(_)
  })
  let (merged_rev, extra_vars_rev) = shared.fold(init=([], []), fn(acc, pair) {
    let (ms, vs) = acc
    let (dc, deriv_tycon) = pair
    match base_map.get(dc.name.name) {
      Some(bc) => {
        let (merged, extra_var) = merge_constr(
          bc, dc, base_tycon, deriv_tycon, loc,
        )
        let next_vs = match extra_var {
          Some(v) => if vs.contains(v) { vs } else { [v] + vs }
          None => vs
        }
        ([merged] + ms, next_vs)
      }
      None => (ms, vs)
    }
  })
  (merged_rev.rev(), extra_vars_rev.rev())
}

///|
fn build_ext_enum(
  deriv : @meta_parser.NanoLangDef,
  base_map : Map[String, @syntax.ConstrDecl],
  loc : @basic.Location,
) -> (@syntax.TypeDecl, String)? {
  let deriv_tycon = deriv.type_decl.tycon
  let ext_constrs : Array[@syntax.ConstrDecl] = []
  match deriv.type_decl.components {
    @syntax.Variant(cs) =>
      cs.each(fn(c) {
        match base_map.get(c.name.name) {
          None => ext_constrs.push(replace_self_refs(c, deriv_tycon, loc))
          _ => ()
        }
      })
    _ => ()
  }
  if ext_constrs.length() > 0 {
    let ext_name = deriv_tycon + "Ext"
    let ext_enum = make_type_decl(ext_name, ext_constrs, ["Self_"], loc)
    Some((ext_enum, ext_name))
  } else {
    None
  }
}

///|
fn gen_tree_def(
  langs : Array[@meta_parser.NanoLangDef],
  _mbti? : @meta_parser.Mbti,
) -> (@syntax.TypeDecl, Array[@syntax.TypeDecl]) raise {
  if langs.length() == 0 {
    raise NoLanguageFound
  }

  let base = langs[0]
  let loc = base.type_decl.loc
  let base_tycon = base.type_decl.tycon
  let base_map = make_base_map(base)

  // Collect all deriv constructors as (constr, deriv_tycon) pairs
  let deriv_pairs : Array[(@syntax.ConstrDecl, String)] = []
  for i in 1..<langs.length() {
    let deriv = langs[i]
    match deriv.type_decl.components {
      @syntax.Variant(cs) =>
        cs.each(fn(c) { deriv_pairs.push((c, deriv.type_decl.tycon)) })
      _ => ()
    }
  }

  // Merge constructors shared with base
  let (merged_constrs, extra_vars) = merge_shared_constrs(
    deriv_pairs, base_map, base_tycon, loc,
  )

  // Build ext enums for deriv-only constructors
  let ext_results = langs[1:].filter_map(fn(deriv) {
    build_ext_enum(deriv, base_map, loc)
  })
  let ext_enums = ext_results.map(fn(pair) { pair.0 })
  let ext_vars = ext_results.map(fn(pair) { pair.1 })

  // Add Ext(TreeExt) if there are ext enums
  let (final_constrs, final_type_params) = if ext_vars.length() > 0 {
    let ext_var = "TreeExt"
    let ext_ty = @syntax.Name(
      constr_id={ id: @syntax.LongIdent::Ident(name=ext_var), loc },
      tys=@list.empty(),
      loc~,
    )
    let ext_constr : @syntax.ConstrDecl = {
      args: Some(@list.List([{ label: None, mut_: false, ty: ext_ty }])),
      attrs: @list.empty(),
      doc: @syntax.DocString::empty(),
      loc,
      name: { name: "Ext", loc },
      tag: None,
    }
    (merged_constrs + [ext_constr], extra_vars + [ext_var])
  } else {
    (merged_constrs, extra_vars)
  }

  let final_type_params = ["Self_"] + final_type_params
  let tree = make_type_decl("Tree", final_constrs, final_type_params, loc)
  (tree, ext_enums)
}

///|
fn builtin_types() -> Array[String] {
  [
    "Int", "String", "Bool", "Char", "Double", "Float", "Byte", "Bytes", "Unit",
    "BigInt", "UInt", "UInt16", "UInt64", "Int16", "Int64",
  ]
}

///|
fn unit_type(loc : @basic.Location) -> @syntax.Type {
  @syntax.Name(
    constr_id={ id: @syntax.LongIdent::Ident(name="Unit"), loc },
    tys=@list.empty(),
    loc~,
  )
}

///|
fn type_ref(name : String, loc : @basic.Location) -> @syntax.Type {
  @syntax.Name(
    constr_id={ id: @syntax.LongIdent::Ident(name~), loc },
    tys=@list.empty(),
    loc~,
  )
}

///|
fn type_ref_with_args(
  name : String,
  args : Array[@syntax.Type],
  loc : @basic.Location,
) -> @syntax.Type {
  @syntax.Name(
    constr_id={ id: @syntax.LongIdent::Ident(name~), loc },
    tys=@list.List(args[:]),
    loc~,
  )
}

///|
fn first_unused_arg(
  args : Array[@syntax.ConstrParam],
  used : Array[Int],
) -> Int? {
  for i in 0..<args.length() {
    if !used.contains(i) {
      return Some(i)
    }
  }
  None
}

///|
fn first_unused_arg_with_type(
  args : Array[@syntax.ConstrParam],
  used : Array[Int],
  tycon : String,
) -> Int? {
  for i in 0..<args.length() {
    if !used.contains(i) && type_name(args[i].ty) == tycon {
      return Some(i)
    }
  }
  None
}

///|
fn shared_extra_type(
  base_c : @syntax.ConstrDecl,
  deriv_c : @syntax.ConstrDecl,
  base_tycon : String,
  deriv_tycon : String,
) -> @syntax.Type? {
  let base_args = match base_c.args {
    Some(args) => args.to_array()
    None => []
  }
  let deriv_args = match deriv_c.args {
    Some(args) => args.to_array()
    None => []
  }
  if deriv_args.length() <= base_args.length() {
    return None
  }
  let used : Array[Int] = []
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
      Some(index) => used.push(index)
      None => ()
    }
  })
  for i in 0..<deriv_args.length() {
    if !used.contains(i) {
      return Some(deriv_args[i].ty)
    }
  }
  None
}

///|
fn extra_type_map(
  base_map : Map[String, @syntax.ConstrDecl],
  deriv : @meta_parser.NanoLangDef,
  base_tycon : String,
) -> Map[String, @syntax.Type] {
  let result : Map[String, @syntax.Type] = {}
  match deriv.type_decl.components {
    @syntax.Variant(cs) =>
      cs.each(fn(c) {
        match base_map.get(c.name.name) {
          Some(base_c) =>
            match
              shared_extra_type(base_c, c, base_tycon, deriv.type_decl.tycon) {
              Some(ty) => result[c.name.name + "E"] = ty
              None => ()
            }
          None => ()
        }
      })
    _ => ()
  }
  result
}

///|
fn struct_wrappers(
  langs : Array[@meta_parser.NanoLangDef],
  tree_type_params : Array[String],
  loc : @basic.Location,
) -> Array[@syntax.TypeDecl] {
  let base = langs[0]
  let base_map = make_base_map(base)
  let ext_names = langs.fold(init={}, fn(m, lang) {
    lang.nonterminals.fold(init=m, fn(m2, nt) {
      match nt {
        TypeDecl(td) => {
          m2[td.tycon + "E"] = td.tycon
          m2
        }
        _ => m2
      }
    })
  })

  langs.map(fn(lang) {
    let tycon = lang.type_decl.tycon
    let is_base = lang.name == base.name
    let extras = extra_type_map(base_map, lang, base.type_decl.tycon)
    let tys = tree_type_params.map(fn(p) {
      if p == "Self_" {
        type_ref(tycon, loc)
      } else if is_base {
        unit_type(loc)
      } else if p == "TreeExt" {
        type_ref_with_args(tycon + "Ext", [type_ref(tycon, loc)], loc)
      } else {
        match extras.get(p) {
          Some(ty) => ty
          None =>
            match ext_names.get(p) {
              Some(name) => type_ref(name, loc)
              None => unit_type(loc)
            }
        }
      }
    })
    let tree_ty = @syntax.Name(
      constr_id={ id: @syntax.LongIdent::Ident(name="Tree"), loc },
      tys=@list.List(tys[:]),
      loc~,
    )
    {
      attrs: @list.empty(),
      components: @syntax.TupleStruct(@list.List([tree_ty])),
      deriving: @list.empty(),
      doc: @syntax.DocString::empty(),
      is_declare: false,
      loc,
      params: @list.empty(),
      tycon,
      tycon_loc: loc,
      type_vis: @syntax.Visibility::Default,
    }
  })
}
