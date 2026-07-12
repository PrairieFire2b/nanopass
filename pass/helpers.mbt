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
/// Determine Tree type parameters and constructors from a language group's
/// generated layout.
///
/// This is the single source of truth: instead of independently re-deriving the
/// merged `Tree` shape (as an earlier version did), we read it from
/// `@language.GeneratedLanguageLayout`, which is the same layout that
/// `Language::gen` uses to emit the AST. This guarantees the pass codegen and
/// the AST codegen never drift.
fn tree_info_from_layout(
  layout : @layout.GeneratedLanguageLayout,
) -> TreeInfo raise {
  let tree_constrs = match layout.tree.decl.components {
    @syntax.Variant(cs) => cs.to_array()
    _ => []
  }

  // The `Ext(TreeExt)` constructor, if present, is the one named "Ext".
  let mut ext_constr_index = -1
  tree_constrs.eachi(fn(i, c) {
    if c.name.name == "Ext" {
      ext_constr_index = i
    }
  })

  // Flatten every derived language's ext enum into one descriptor set; the
  // generated Tree only ever references a single `TreeExt` type parameter.
  let ext_enum : ExtEnumInfo? = if layout.ext_enums.length() > 0 {
    let all_ext_constrs : Array[@syntax.ConstrDecl] = []
    layout.ext_enums.each(fn(ee) {
      match ee.decl.components {
        @syntax.Variant(cs) => cs.each(fn(c) { all_ext_constrs.push(c) })
        _ => ()
      }
    })
    Some({ name: layout.ext_enums[0].tycon, constrs: all_ext_constrs })
  } else {
    None
  }

  {
    tree_type_params: layout.tree.params,
    tree_constrs,
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

  // Extension enum constructors.
  //
  // Only languages that actually own the ext enum carry ext descriptors. The
  // base language's wrapper is `Tree[Base, Unit, Unit]` (TreeExt = Unit), so it
  // has NO real ext constructors; emitting `True`/`If`/... matches against its
  // `Ext(Unit)` payload would not type-check. Derived languages whose wrapper
  // fills `TreeExt` with a real ext enum do carry them.
  if not(is_base) {
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

///|
/// Build a *bare* constructor application `Constr(args...)` (no `Tycon::`
/// prefix). Because the constructors of the merged `Tree` enum and the ext
/// enum are in scope wherever the generated code lives, and the language
/// wrapper is a tuple struct (`struct Expr(Tree[...])`), both the wrapper
/// wrapping and the inner tree constructor use this bare form:
///
///   Expr(Int(n))          // wrapper(bare inner tree constructor)
///   Expr(Ext(If(c, t, e)))
fn bare_constr_call(
  constr_name : String,
  args : Array[@syntax.Expr],
  loc : @basic.Location,
) -> @syntax.Expr {
  let constr : @syntax.Constructor = {
    name: { name: constr_name, loc },
    extra_info: @syntax.ConstructorExtraInfo::NoExtraInfo,
    loc,
  }
  if args.length() == 0 {
    @syntax.Expr::Constr(constr~, loc~)
  } else {
    @syntax.Expr::Apply(
      func=@syntax.Expr::Constr(constr~, loc~),
      args=@list.from_array(
        args.map(fn(e) { { value: e, kind: @syntax.ArgumentKind::Positional } }),
      ),
      loc~,
    )
  }
}

