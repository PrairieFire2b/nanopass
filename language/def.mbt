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
  let (_tree, _ext_enums) = gen_tree_def(langs, _mbti=mbti)
  { name, group: langs }
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
      Some(@list.from_array(merged_args[:]))
    } else {
      None
    },
  }
  (merged_c, extra_var)
}

///|
fn make_base_map(base : @meta_parser.NanoLangDef) -> Map[String, @syntax.ConstrDecl] {
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
      Some(@list.from_array(params[:]))
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
  let binders = @list.from_array(
    type_params.map(fn(name) {
      @syntax.TypeDeclBinder::{ name: Some(name), loc }
    }),
  )
  {
    attrs: @list.empty(),
    components: @syntax.Variant(@list.from_array(constrs[:])),
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
        let (merged, extra_var) = merge_constr(bc, dc, base_tycon, deriv_tycon, loc)
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
    let ext_enum = make_type_decl(ext_name, ext_constrs, [], loc)
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
    deriv_pairs,
    base_map,
    base_tycon,
    loc,
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
      args: Some(@list.from_array([{ label: None, mut_: false, ty: ext_ty }])),
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

  let tree = make_type_decl("Tree", final_constrs, final_type_params, loc)
  (tree, ext_enums)
}

///|
test {
  let a = @meta_parser.find_languages_by_file("poc/lang_def.mbt")
  let (tree, ext_enums) = gen_tree_def(a)
  let impls = @list.from_array(
    [@syntax.TopTypeDef(tree)] + ext_enums.map(fn(e) { @syntax.TopTypeDef(e) }),
  )
  inspect(
    @fmt.impls_to_string(impls),
    content=(
      #|///|
      #|enum Tree[LamE, TreeExt] {
      #|  /// Terminals
      #|  Int(Int)
      #|  Var(Var)
      #|  /// Nonterminals
      #|  Lam(Var, Self_, LamE)
      #|  App(Self_, Self_)
      #|  Ext(TreeExt)
      #|}
      #|
      #|///|
      #|enum TypedExprExt {
      #|  /// Terminals
      #|  True
      #|  False
      #|  /// Nonterminals
      #|  If(cond~ : Self_, Self_, Self_)
      #|}
      #|
      #|
    ),
  )
}
