///|
/// M1 surface API generation: smart constructors and `view()`.
///
/// Pass authors should never touch the underlying tuple-struct wrapper
/// (`struct Expr(Tree[...])`) or its nested `Tree` / `Ext` constructors.
/// This module generates a stable surface:
///
///   - smart constructors: `Expr::int(n)`, `Expr::lam(x, body)`,
///     `Expr::if_(c, t, e)` ... each building `Expr(Int(n))` /
///     `Expr(Ext(If(c, t, e)))` internally.
///   - `Expr::view() -> ExprView`: flattens the wrapped `Tree`/`Ext` into a
///     single flat enum so pass authors can `match` without nesting.
pub fn gen_surface(
  lang : @language.Language,
) -> @list.List[@syntax.Impl] raise {
  let tree_info = tree_info_from_layout(lang.layout())
  let loc = lang.group[0].type_decl.loc
  let impls : Array[@syntax.Impl] = []
  let ext_enum_name = match tree_info.ext_enum {
    Some(ee) => Some(ee.name)
    None => None
  }
  let has_ext_constr = tree_info.ext_constr_index >= 0
  lang.group.eachi(fn(i, nl) {
    let tycon = nl.type_decl.tycon
    let is_base = i == 0
    let descs = collect_descriptors(tree_info, tycon, is_base, ext_enum_name, loc)
    // Smart constructors
    descs.each(fn(d) {
      impls.push(gen_smart_constructor(tycon, d, loc))
    })
    // View enum + accessor
    impls.push(gen_view_enum(tycon, descs, loc))
    impls.push(gen_view_impl(tycon, descs, has_ext_constr, loc))
  })
  @list.List(impls[:])
}

///|
/// Lower the first character of a constructor name; append `_` if the result
/// collides with a MoonBit keyword. e.g. `Int -> int`, `If -> if_`,
/// `True -> true_`, `LambdaVar -> lambdaVar`.
fn smart_ctor_name(constr_name : String) -> String {
  let lowered = if constr_name.length() == 0 {
    constr_name
  } else {
    constr_name.substring(start=0, end=1).to_lower() +
    constr_name.substring(start=1)
  }
  if is_keyword(lowered) {
    lowered + "_"
  } else {
    lowered
  }
}

///|
fn is_keyword(name : String) -> Bool {
  match name {
    "if"
    | "else"
    | "match"
    | "let"
    | "fn"
    | "true"
    | "false"
    | "type"
    | "struct"
    | "enum"
    | "trait"
    | "impl"
    | "for"
    | "while"
    | "loop"
    | "return"
    | "break"
    | "continue"
    | "mut"
    | "pub"
    | "test"
    | "as"
    | "in"
    | "guard"
    | "raise"
    | "try"
    | "catch" => true
    _ => false
  }
}

///|
/// Generate `fn Tycon::name(params) -> Tycon { Tycon(<inner>) }`.
fn gen_smart_constructor(
  tycon : String,
  d : ConstrDescriptor,
  loc : @basic.Location,
) -> @syntax.Impl {
  // Parameters: self-ref positions take the wrapper type `Tycon`, everything
  // else keeps its declared field type.
  let params : Array[@syntax.Parameter] = []
  let arg_exprs : Array[@syntax.Expr] = []
  d.params.each(fn(p) {
    let ty = if p.is_self_ref {
      type_ref(tycon, loc)
    } else {
      p.field_ty
    }
    params.push(
      @syntax.Parameter::Positional(binder={ name: p.name, loc }, ty=Some(ty)),
    )
    arg_exprs.push(var_expr(p.name, loc))
  })

  // Body: Tycon(Constr(args)) or Tycon(Ext(Constr(args))).
  let inner = if d.is_ext {
    bare_constr_call("Ext", [bare_constr_call(d.name, arg_exprs, loc)], loc)
  } else {
    bare_constr_call(d.name, arg_exprs, loc)
  }
  let body = bare_constr_call(tycon, [inner], loc)

  let ret_ty = type_ref(tycon, loc)
  let fun_decl : @syntax.FunDecl = {
    type_name: Some({
      is_object: false,
      loc,
      name: @syntax.LongIdent::Ident(name=tycon),
    }),
    name: { name: smart_ctor_name(d.name), loc },
    is_async: None,
    decl_params: Some(@list.List(params[:])),
    params_loc: loc,
    quantifiers: @list.empty(),
    return_type: Some(ret_ty),
    error_type: @syntax.ErrorType::NoErrorType,
    vis: @syntax.Visibility::Default,
    attrs: @list.empty(),
    doc: @syntax.DocString::empty(),
    loc,
  }
  @syntax.TopFuncDef(
    fun_decl~,
    decl_body=@syntax.DeclBody::DeclBody(expr=body),
    where_clause=None,
    loc~,
  )
}

///|
/// The flat view enum variant name for a constructor: `V` + constructor name.
fn view_variant_name(constr_name : String) -> String {
  "V" + constr_name
}

///|
/// Generate `enum TyconView { VInt(Int); VLam(Var, Tycon); ... }`.
/// Self-ref positions use the wrapper type `Tycon`.
fn gen_view_enum(
  tycon : String,
  descs : Array[ConstrDescriptor],
  loc : @basic.Location,
) -> @syntax.Impl {
  let variants : Array[@syntax.ConstrDecl] = []
  descs.each(fn(d) {
    let args : Array[@syntax.ConstrParam] = []
    d.params.each(fn(p) {
      let ty = if p.is_self_ref {
        type_ref(tycon, loc)
      } else {
        p.field_ty
      }
      args.push({ label: None, mut_: false, ty })
    })
    variants.push({
      args: if args.length() > 0 {
        Some(@list.List(args[:]))
      } else {
        None
      },
      attrs: @list.empty(),
      doc: @syntax.DocString::empty(),
      loc,
      name: @syntax.ConstrName::{ name: view_variant_name(d.name), loc },
      tag: None,
    })
  })
  let type_decl : @syntax.TypeDecl = {
    attrs: @list.empty(),
    components: @syntax.Variant(@list.List(variants[:])),
    deriving: @list.empty(),
    doc: @syntax.DocString::empty(),
    is_declare: false,
    loc,
    params: @list.empty(),
    tycon: tycon + "View",
    tycon_loc: loc,
    type_vis: @syntax.Visibility::Default,
  }
  @syntax.TopTypeDef(type_decl)
}

///|
/// Generate `fn Tycon::view(self) -> TyconView { let Tycon(t) = self; match t { ... } }`.
fn gen_view_impl(
  tycon : String,
  descs : Array[ConstrDescriptor],
  has_ext_constr : Bool,
  loc : @basic.Location,
) -> @syntax.Impl {
  let regular = descs.filter(fn(d) { not(d.is_ext) })
  let ext = descs.filter(fn(d) { d.is_ext })

  let cases : Array[@syntax.Case] = []
  regular.each(fn(d) { cases.push(view_case(d, loc)) })
  if has_ext_constr {
    if ext.length() > 0 {
      cases.push(view_ext_case(ext, loc))
    } else {
      // Tree has `Ext(Unit)` but no real ext variants (base language).
      cases.push(ext_unreachable_case(loc))
    }
  }

  let match_expr = @syntax.Expr::Match(
    expr=var_expr("t", loc),
    cases=@list.List(cases[:]),
    match_loc=loc,
    loc~,
  )

  // let Tycon(t) = self
  let wrapper_constr : @syntax.Constructor = {
    name: { name: tycon, loc },
    extra_info: @syntax.ConstructorExtraInfo::NoExtraInfo,
    loc,
  }
  let t_pat_arg : @syntax.ConstrPatArg = {
    pat: @syntax.Pattern::Var({ name: "t", loc }),
    kind: @syntax.ArgumentKind::Positional,
  }
  let wrapper_pattern : @syntax.Pattern = @syntax.Pattern::Constr(
    constr=wrapper_constr,
    args=Some(@list.List([t_pat_arg])),
    is_open=false,
    loc~,
  )
  let fn_body : @syntax.Expr = @syntax.Expr::Let(
    pattern=wrapper_pattern,
    expr=var_expr("self", loc),
    body=match_expr,
    loc~,
  )

  let view_ty = type_ref(tycon + "View", loc)
  let self_ty = type_ref(tycon, loc)
  let fun_decl : @syntax.FunDecl = {
    type_name: Some({
      is_object: false,
      loc,
      name: @syntax.LongIdent::Ident(name=tycon),
    }),
    name: { name: "view", loc },
    is_async: None,
    decl_params: Some(
      @list.List([
        @syntax.Parameter::Positional(
          binder={ name: "self", loc },
          ty=Some(self_ty),
        ),
      ]),
    ),
    params_loc: loc,
    quantifiers: @list.empty(),
    return_type: Some(view_ty),
    error_type: @syntax.ErrorType::NoErrorType,
    vis: @syntax.Visibility::Default,
    attrs: @list.empty(),
    doc: @syntax.DocString::empty(),
    loc,
  }
  @syntax.TopFuncDef(
    fun_decl~,
    decl_body=@syntax.DeclBody::DeclBody(expr=fn_body),
    where_clause=None,
    loc~,
  )
}

///|
/// A view match case for a regular constructor:
///   Constr(a0, a1, ...) => VConstr(a0, a1, ...)
fn view_case(d : ConstrDescriptor, loc : @basic.Location) -> @syntax.Case {
  let pat_args : Array[@syntax.ConstrPatArg] = []
  let val_exprs : Array[@syntax.Expr] = []
  d.params.each(fn(p) {
    // For a labelled field `cond~ : T`, the pattern `Constr(cond~, ...)` binds
    // the variable `cond`; the rebuild must reference `cond`, not `argN`.
    // For positional fields we use `argN`.
    let (kind, bind_name) : (@syntax.ArgumentKind, String) = match p.label {
      Some(l) => (@syntax.ArgumentKind::Labelled(l), l.name)
      None => (@syntax.ArgumentKind::Positional, p.name)
    }
    pat_args.push({ pat: @syntax.Pattern::Var({ name: bind_name, loc }), kind })
    val_exprs.push(var_expr(bind_name, loc))
  })
  let constr : @syntax.Constructor = {
    name: { name: d.name, loc },
    extra_info: @syntax.ConstructorExtraInfo::NoExtraInfo,
    loc,
  }
  let pattern : @syntax.Pattern = @syntax.Pattern::Constr(
    constr~,
    args=if pat_args.length() > 0 {
      Some(@list.List(pat_args[:]))
    } else {
      None
    },
    is_open=false,
    loc~,
  )
  let body = bare_constr_call(view_variant_name(d.name), val_exprs, loc)
  { pattern, guard_: None, body }
}

///|
/// The ext case: `Ext(te) => match te { True => VTrue; If(a,b,c) => VIf(a,b,c) }`.
fn view_ext_case(
  ext_descs : Array[ConstrDescriptor],
  loc : @basic.Location,
) -> @syntax.Case {
  let ext_cases : Array[@syntax.Case] = []
  ext_descs.each(fn(d) { ext_cases.push(view_case(d, loc)) })
  let nested_match : @syntax.Expr = @syntax.Expr::Match(
    expr=var_expr("te", loc),
    cases=@list.List(ext_cases[:]),
    match_loc=loc,
    loc~,
  )
  let ext_constr : @syntax.Constructor = {
    name: { name: "Ext", loc },
    extra_info: @syntax.ConstructorExtraInfo::NoExtraInfo,
    loc,
  }
  let te_pat_arg : @syntax.ConstrPatArg = {
    pat: @syntax.Pattern::Var({ name: "te", loc }),
    kind: @syntax.ArgumentKind::Positional,
  }
  let ext_pattern : @syntax.Pattern = @syntax.Pattern::Constr(
    constr=ext_constr,
    args=Some(@list.List([te_pat_arg])),
    is_open=false,
    loc~,
  )
  { pattern: ext_pattern, guard_: None, body: nested_match }
}
