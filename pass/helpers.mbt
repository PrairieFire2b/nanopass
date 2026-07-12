///|

///|
priv struct TreeInfo {
  /// Type parameter names of the Tree enum, e.g. ["Self_", "LamE", "TreeExt"].
  tree_type_params : Array[String]
  /// All constructors in the merged Tree enum (with Self_/type-var references).
  tree_constrs : Array[@syntax.ConstrDecl]
  /// The index of the Ext(_) constructor in tree_constrs, or -1 if none.
  ext_constr_index : Int
  /// Extension enum info, if any derived language has unique constructors.
  ext_enum : ExtEnumInfo?
}

///|
priv struct ExtEnumInfo {
  /// Enum name, e.g. "TypedExprExt".
  name : String
  /// Constructors with Self_ references.
  constrs : Array[@syntax.ConstrDecl]
}

///|
/// Extract a simple type name from a `@syntax.Type`.
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
/// Create a named type reference at a given location.
fn type_ref(name : String, loc : @basic.Location) -> @syntax.Type {
  @syntax.Name(
    constr_id={ id: @syntax.LongIdent::Ident(name~), loc },
    tys=@list.empty(),
    loc~,
  )
}

///|
/// Create a `Self_` type reference.
fn self_type(loc : @basic.Location) -> @syntax.Type {
  type_ref("Self_", loc)
}

///|
/// Create a function arrow type `(params...) -> result`.
fn make_fn_type(
  param_tys : Array[@syntax.Type],
  result : @syntax.Type,
  loc : @basic.Location,
) -> @syntax.Type {
  @syntax.Arrow(
    args=@list.from_array(param_tys[:]),
    res=result,
    err=@syntax.ErrorType::NoErrorType,
    is_async=None,
    loc~,
  )
}

///|
/// Create a struct field declaration.
fn make_field_decl(
  name : String,
  ty : @syntax.Type,
  loc : @basic.Location,
) -> @syntax.FieldDecl {
  {
    name: @syntax.FieldName::{ label: name, loc },
    ty,
    mut_: false,
    vis: @syntax.Visibility::Default,
    loc,
    attrs: @list.empty(),
    doc: @syntax.DocString::empty(),
  }
}

///|
/// Build a name-to-constructor map from a NanoLangDef's type declaration.
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
/// Replace self-references to `tycon` with `Self_` in constructor args.
fn replace_self_refs(
  constr : @syntax.ConstrDecl,
  tycon : String,
  _loc : @basic.Location,
) -> @syntax.ConstrDecl {
  let new_args = match constr.args {
    Some(args) => {
      let params : Array[@syntax.ConstrParam] = []
      args.each(fn(p) {
        let new_ty = if type_name(p.ty) == tycon {
          self_type(_loc)
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
/// Merge base and derived versions of a shared constructor.
/// Returns (merged_constructor, extra_var_name?).
fn merge_constr(
  base_c : @syntax.ConstrDecl,
  deriv_c : @syntax.ConstrDecl,
  base_tycon : String,
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
    Some(name) =>
      merged_args.push({ label: None, mut_: false, ty: type_ref(name, loc) })
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
/// Merge all shared constructors between base and derived languages.
/// Returns (merged_constructors, extra_type_variable_names).
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
    let (dc, _deriv_tycon) = pair
    match base_map.get(dc.name.name) {
      Some(bc) => {
        let (merged, extra_var) = merge_constr(bc, dc, base_tycon, loc)
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
/// For a derived language, extract constructors not present in the base,
/// building an ext enum if any exist.
fn build_ext_enum_constrs(
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
    let binders = @list.from_array([
      @syntax.TypeDeclBinder::{ name: Some("Self_"), loc },
    ])
    let ext_enum : @syntax.TypeDecl = {
      attrs: @list.empty(),
      components: @syntax.Variant(@list.from_array(ext_constrs[:])),
      deriving: @list.empty(),
      doc: @syntax.DocString::empty(),
      is_declare: false,
      loc,
      params: binders,
      tycon: ext_name,
      tycon_loc: loc,
      type_vis: @syntax.Visibility::Default,
    }
    Some((ext_enum, ext_name))
  } else {
    None
  }
}

///|
/// Determine Tree type parameters and constructors from a language group.
/// Mirrors `gen_tree_def` in language/gen.mbt.
fn compute_tree_params(
  langs : Array[@meta_parser.NanoLangDef],
) -> TreeInfo raise {
  if langs.length() == 0 {
    fail("compute_tree_params: empty language group")
  }

  let base = langs[0]
  let loc = base.type_decl.loc
  let base_tycon = base.type_decl.tycon
  let base_map = make_base_map(base)

  // Collect all derived constructors as (constr, deriv_tycon) pairs
  let deriv_pairs : Array[(@syntax.ConstrDecl, String)] = []
  for i in 1..<langs.length() {
    let deriv = langs[i]
    match deriv.type_decl.components {
      @syntax.Variant(cs) =>
        cs.each(fn(c) { deriv_pairs.push((c, deriv.type_decl.tycon)) })
      _ => ()
    }
  }

  // Merge shared constructors
  let (merged_constrs, extra_vars) = merge_shared_constrs(
    deriv_pairs, base_map, base_tycon, loc,
  )

  // Build ext enums for derived-only constructors
  let ext_results : Array[(@syntax.TypeDecl, String)] = []
  for i in 1..<langs.length() {
    match build_ext_enum_constrs(langs[i], base_map, loc) {
      Some(result) => ext_results.push(result)
      None => ()
    }
  }

  let ext_enums = ext_results.map(fn(pair) { pair.0 })
  let ext_names = ext_results.map(fn(pair) { pair.1 })

  // Add Ext(TreeExt) constructor if there are ext enums
  let (final_constrs, final_type_params, ext_constr_index) = if ext_names.length() >
    0 {
    let ext_constr : @syntax.ConstrDecl = {
      args: Some(
        @list.from_array([
          { label: None, mut_: false, ty: type_ref("TreeExt", loc) },
        ]),
      ),
      attrs: @list.empty(),
      doc: @syntax.DocString::empty(),
      loc,
      name: @syntax.ConstrName::{ name: "Ext", loc },
      tag: None,
    }
    (
      merged_constrs + [ext_constr],
      extra_vars + ["TreeExt"],
      merged_constrs.length(),
    )
  } else {
    (merged_constrs, extra_vars, -1)
  }

  let ext_enum : ExtEnumInfo? = if ext_names.length() > 0 {
    let all_ext_constrs : Array[@syntax.ConstrDecl] = []
    for i in 0..<ext_enums.length() {
      match ext_enums[i].components {
        @syntax.Variant(cs) => cs.each(fn(c) { all_ext_constrs.push(c) })
        _ => ()
      }
    }
    Some({ name: ext_names[0], constrs: all_ext_constrs })
  } else {
    None
  }

  {
    tree_type_params: ["Self_"] + final_type_params,
    tree_constrs: final_constrs,
    ext_constr_index,
    ext_enum,
  }
}

///|
/// Compute the concrete type name that fills a Tree type parameter for a given language.
fn fill_type(
  param_name : String,
  tycon : String,
  is_base : Bool,
  ext_enum_name : String?,
) -> String {
  if param_name == "Self_" {
    tycon
  } else if is_base {
    "Unit"
  } else if param_name == "TreeExt" {
    match ext_enum_name {
      Some(name) => name
      None => "Unit"
    }
  } else {
    "Unit"
  }
}

///|
/// Sanitize a constructor name for use as a struct field name.
fn field_name(name : String) -> String {
  name + "_"
}

///|
/// Create a variable reference expression.
fn var_expr(name : String, loc : @basic.Location) -> @syntax.Expr {
  @syntax.Expr::Ident(
    id=@syntax.Var::{ name: @syntax.LongIdent::Ident(name~), loc },
    loc~,
  )
}

///|
/// Describes one parameter of a constructor for pass code generation.
priv struct ParamDescriptor {
  /// Variable name in generated pattern/call, e.g. "arg0".
  name : String
  /// Type used in Semantics field signature (Self_ positions become "Repr").
  field_ty : @syntax.Type
  /// Whether this parameter is a recursive (Self_) position.
  is_self_ref : Bool
  /// Label if this is a labelled parameter.
  label : @syntax.Label?
}

///|
/// Describes one constructor for pass code generation.
/// Drives Semantics struct fields, identity lambda bodies, and cata match cases.
priv struct ConstrDescriptor {
  /// Constructor name, e.g. "Int", "Lam".
  name : String
  /// Sanitized field name, e.g. "Int_", "Lam_".
  field_name : String
  /// Descriptors for each parameter.
  params : Array[ParamDescriptor]
  /// Whether this constructor belongs to an extension enum.
  is_ext : Bool
  /// Extension enum type name if is_ext, e.g. "TypedExprExt".
  ext_enum_name : String?
}

///|
/// Build parameter descriptors from a constructor declaration.
fn build_params(
  constr : @syntax.ConstrDecl,
  tycon : String,
  is_base : Bool,
  ext_enum_name : String?,
  tree_params : Array[String],
  loc : @basic.Location,
) -> Array[ParamDescriptor] {
  match constr.args {
    Some(args) => {
      let params : Array[ParamDescriptor] = []
      args.eachi(fn(i, p) {
        let ty_name = type_name(p.ty)
        let is_self = ty_name == "Self_" || ty_name == tycon
        let field_ty = if is_self {
          type_ref("Repr", loc)
        } else if tree_params.contains(ty_name) {
          let filled = fill_type(ty_name, tycon, is_base, ext_enum_name)
          type_ref(filled, loc)
        } else {
          p.ty
        }
        params.push({
          name: "arg\{i}",
          field_ty,
          is_self_ref: is_self,
          label: p.label,
        })
      })
      params
    }
    None => []
  }
}

///|
/// Collect flat descriptor list for all constructors in a language group.
/// Regular Tree constructors come first; extension-enum constructors follow.
fn collect_descriptors(
  tree_info : TreeInfo,
  tycon : String,
  is_base : Bool,
  ext_enum_name : String?,
  loc : @basic.Location,
) -> Array[ConstrDescriptor] {
  let descs : Array[ConstrDescriptor] = []

  // Regular tree constructors (skip Ext)
  tree_info.tree_constrs.eachi(fn(i, c) {
    if i != tree_info.ext_constr_index {
      let params = build_params(
        c,
        tycon,
        is_base,
        ext_enum_name,
        tree_info.tree_type_params,
        loc,
      )
      descs.push({
        name: c.name.name,
        field_name: field_name(c.name.name),
        params,
        is_ext: false,
        ext_enum_name: None,
      })
    }
  })

  // Extension enum constructors
  match tree_info.ext_enum {
    Some(ee) =>
      ee.constrs.each(fn(c) {
        let params = build_params(
          c,
          tycon,
          is_base,
          ext_enum_name,
          tree_info.tree_type_params,
          loc,
        )
        descs.push({
          name: c.name.name,
          field_name: field_name(c.name.name),
          params,
          is_ext: true,
          ext_enum_name: Some(ee.name),
        })
      })
    None => ()
  }
  descs
}

///|
/// Build a constructor call expression for a language type.
fn make_constr_call(
  tycon : String,
  constr_name : String,
  args : Array[@syntax.Expr],
  loc : @basic.Location,
) -> @syntax.Expr {
  if args.length() == 0 {
    let constr : @syntax.Constructor = {
      name: { name: constr_name, loc },
      extra_info: @syntax.ConstructorExtraInfo::NoExtraInfo,
      loc,
    }
    @syntax.Expr::Constr(constr~, loc~)
  } else {
    @syntax.Expr::Apply(
      func=@syntax.Expr::Method(
        type_name={
          is_object: false,
          loc,
          name: @syntax.LongIdent::Ident(name=tycon),
        },
        method_name={ name: constr_name, loc },
        loc~,
      ),
      args=@list.from_array(
        args.map(fn(e) { { value: e, kind: @syntax.ArgumentKind::Positional } }),
      ),
      loc~,
    )
  }
}
