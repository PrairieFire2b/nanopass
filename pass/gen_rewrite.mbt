///|
/// M3: generate the effectful rewrite algebra and driver.
///
/// For each concrete language `Tycon` this emits:
///
///   struct TyconRewriteAlg[Env, St, Log, Err] {
///     <constr>_ : (<non-self args>, <self args as delayed PassM>) -> PassM[...Tycon]
///     ...
///   }
///   fn[Env, St, Log, Err] TyconRewriteAlg::identity() -> TyconRewriteAlg[...]
///   fn[Env, St, Log, Err] Tycon::rewrite_m(self, alg) -> PassM[Env, St, Log, Err, Tycon]
///
/// Self-ref subtree positions become *delayed* `PassM[..., Tycon]` values so
/// scope-sensitive handlers (Lam/Let) can extend the environment BEFORE running
/// the child. Generated code lives in the user's package, so `PassM` and its
/// combinators are referenced through `@pass`.
pub fn gen_rewrite(lang : @language.Language) -> @list.List[@syntax.Impl] raise {
  let tree_info = tree_info_from_layout(lang.layout())
  let loc = lang.group[0].type_decl.loc
  let ext_enum_name = match tree_info.ext_enum {
    Some(ee) => Some(ee.name)
    None => None
  }
  let impls : Array[@syntax.Impl] = []
  lang.group.eachi(fn(i, nl) {
    let tycon = nl.type_decl.tycon
    let is_base = i == 0
    let descs = collect_descriptors(
      tree_info, tycon, is_base, ext_enum_name, loc,
    )
    let struct_name = tycon + "RewriteAlg"
    impls.push(gen_rewrite_struct(struct_name, tycon, descs, loc))
    impls.push(gen_rewrite_identity(struct_name, tycon, descs, loc))
    impls.push(gen_rewrite_driver(tycon, struct_name, tree_info, descs, loc))
  })
  List(impls[:])
}

///|
/// Type `@pass.PassM[Env, St, Log, Err, inner]`.
fn passm_type(inner : @syntax.Type, loc : @basic.Location) -> @syntax.Type {
  Name(
    constr_id={ id: Dot(pkg="pass", id="PassM"), loc },
    tys=List([
      type_ref("Env", loc),
      type_ref("St", loc),
      type_ref("Log", loc),
      type_ref("Err", loc),
      inner,
    ]),
    loc~,
  )
}

///|
/// The four effect type parameters `[Env, St, Log, Err]`.
fn rewrite_quantifiers(
  loc : @basic.Location,
) -> @list.List[@syntax.TypeVarBinder] {
  List([
    { name: "Env", name_loc: loc, constraints: @list.empty() },
    { name: "St", name_loc: loc, constraints: @list.empty() },
    { name: "Log", name_loc: loc, constraints: @list.empty() },
    { name: "Err", name_loc: loc, constraints: @list.empty() },
  ])
}

///|
/// struct TyconRewriteAlg[Env, St, Log, Err] { constr_ : (...) -> PassM[...] ... }
fn gen_rewrite_struct(
  struct_name : String,
  tycon : String,
  descs : Array[ConstrDescriptor],
  loc : @basic.Location,
) -> @syntax.Impl {
  let ret = passm_type(type_ref(tycon, loc), loc)
  let fields : Array[@syntax.FieldDecl] = []
  descs.each(fn(d) {
    let arg_tys : Array[@syntax.Type] = []
    d.params.each(fn(p) {
      // Self-ref subtree -> delayed PassM[..., Tycon]; else keep field type.
      if p.is_self_ref {
        arg_tys.push(passm_type(type_ref(tycon, loc), loc))
      } else {
        arg_tys.push(p.field_ty)
      }
    })
    let fn_ty = make_fn_type(arg_tys, ret, loc)
    fields.push(make_field_decl(d.field_name, fn_ty, loc))
  })
  let type_decl : @syntax.TypeDecl = {
    attrs: @list.empty(),
    components: Record(fields=List(fields[:])),
    deriving: @list.empty(),
    doc: @syntax.DocString::empty(),
    is_declare: false,
    loc,
    params: List([
      { name: Some("Env"), loc },
      { name: Some("St"), loc },
      { name: Some("Log"), loc },
      { name: Some("Err"), loc },
    ]),
    tycon: struct_name,
    tycon_loc: loc,
    type_vis: Default,
  }
  TopTypeDef(type_decl)
}

///|
fn gen_rewrite_identity(
  struct_name : String,
  tycon : String,
  descs : Array[ConstrDescriptor],
  loc : @basic.Location,
) -> @syntax.Impl {
  let fields : Array[@syntax.FieldDef] = []
  descs.each(fn(d) { fields.push(rewrite_identity_field(d, tycon, loc)) })
  let record_expr : @syntax.Expr = Record(
    type_name=None,
    fields=List(fields[:]),
    trailing=None,
    loc~,
  )
  let ret_ty : @syntax.Type = Name(
    constr_id={ id: Ident(name=struct_name), loc },
    tys=List([
      type_ref("Env", loc),
      type_ref("St", loc),
      type_ref("Log", loc),
      type_ref("Err", loc),
    ]),
    loc~,
  )
  let fun_decl : @syntax.FunDecl = {
    type_name: Some({ is_object: false, loc, name: Ident(name=struct_name) }),
    name: { name: "identity", loc },
    is_async: None,
    decl_params: Some(@list.empty()),
    params_loc: loc,
    quantifiers: rewrite_quantifiers(loc),
    return_type: Some(ret_ty),
    error_type: NoErrorType,
    vis: Default,
    attrs: @list.empty(),
    doc: @syntax.DocString::empty(),
    loc,
  }
  TopFuncDef(
    fun_decl~,
    decl_body=DeclBody(expr=record_expr),
    where_clause=None,
    loc~,
  )
}

///|
/// One identity handler:
///   no self-ref  -> fn(a0, ..) { @pass.PassM::pure(Tycon::smart(a0, ..)) }
///   with self-ref-> chain flat_map/map over the delayed sub-computations,
///                   then rebuild via the smart constructor.
fn rewrite_identity_field(
  d : ConstrDescriptor,
  tycon : String,
  loc : @basic.Location,
) -> @syntax.FieldDef {
  // Lambda parameters (all constructor params, in order).
  let params : Array[@syntax.Parameter] = []
  d.params.each(fn(p) {
    params.push(Positional(binder={ name: p.name, loc }, ty=None))
  })

  // Arguments to the smart constructor, in order. Self-ref positions use the
  // executed result name `<name>_v`; others use the parameter name directly.
  let ctor_args : Array[@syntax.Expr] = []
  d.params.each(fn(p) {
    if p.is_self_ref {
      ctor_args.push(var_expr(p.name + "_v", loc))
    } else {
      ctor_args.push(var_expr(p.name, loc))
    }
  })
  let rebuilt = smart_ctor_call(tycon, d, ctor_args, loc)

  // Self-ref sub-computations to sequence.
  let self_params = d.params.filter(fn(p) { p.is_self_ref })
  let body = if self_params.length() == 0 {
    passm_pure(rebuilt, loc)
  } else {
    // Build innermost-out: last self uses .map, earlier ones .flat_map.
    let n = self_params.length()
    let mut expr = rebuilt |> passm_map_last(self_params[n - 1], loc)
    for i = n - 2; i >= 0; i = i - 1 {
      expr = passm_flat_map(self_params[i], expr, loc)
    }
    expr
  }

  let lambda_func : @syntax.Func = {
    parameters: List(params[:]),
    params_loc: loc,
    body,
    return_type: None,
    error_type: NoErrorType,
    kind: Lambda,
    is_async: None,
    loc,
  }
  {
    label: { name: d.field_name, loc },
    expr: Function(func=lambda_func, loc~),
    is_pun: false,
    loc,
  }
}

///|
/// `@pass.PassM::pure(inner)`
fn passm_pure(inner : @syntax.Expr, loc : @basic.Location) -> @syntax.Expr {
  Apply(
    func=Method(
      type_name={ is_object: false, loc, name: Dot(pkg="pass", id="PassM") },
      method_name={ name: "pure", loc },
      loc~,
    ),
    args=List([{ value: inner, kind: Positional }]),
    loc~,
  )
}

///|
/// Innermost: `<param>.map(fn(<param>_v) { <rebuilt> })`
fn passm_map_last(
  rebuilt : @syntax.Expr,
  p : ParamDescriptor,
  loc : @basic.Location,
) -> @syntax.Expr {
  let lambda : @syntax.Func = {
    parameters: List([Positional(binder={ name: p.name + "_v", loc }, ty=None)]),
    params_loc: loc,
    body: rebuilt,
    return_type: None,
    error_type: NoErrorType,
    kind: Lambda,
    is_async: None,
    loc,
  }
  DotApply(
    self=var_expr(p.name, loc),
    method_name={ name: "map", loc },
    args=List([{ value: Function(func=lambda, loc~), kind: Positional }]),
    return_self=false,
    loc~,
  )
}

///|
/// Wrap: `<param>.flat_map(fn(<param>_v) { <cont> })`
fn passm_flat_map(
  p : ParamDescriptor,
  cont : @syntax.Expr,
  loc : @basic.Location,
) -> @syntax.Expr {
  let lambda : @syntax.Func = {
    parameters: List([Positional(binder={ name: p.name + "_v", loc }, ty=None)]),
    params_loc: loc,
    body: cont,
    return_type: None,
    error_type: NoErrorType,
    kind: Lambda,
    is_async: None,
    loc,
  }
  DotApply(
    self=var_expr(p.name, loc),
    method_name={ name: "flat_map", loc },
    args=List([{ value: Function(func=lambda, loc~), kind: Positional }]),
    return_self=false,
    loc~,
  )
}

///|
/// Call the M1 smart constructor `Tycon::name(args)`. M1 smart constructors
/// take positional parameters (labels are not preserved on the surface API),
/// so all arguments are passed positionally.
fn smart_ctor_call(
  tycon : String,
  d : ConstrDescriptor,
  args : Array[@syntax.Expr],
  loc : @basic.Location,
) -> @syntax.Expr {
  let arguments : Array[@syntax.Argument] = args.map(fn(a) {
    { value: a, kind: Positional }
  })
  Apply(
    func=Method(
      type_name={ is_object: false, loc, name: Ident(name=tycon) },
      method_name={ name: smart_ctor_name(d.name), loc },
      loc~,
    ),
    args=List(arguments[:]),
    loc~,
  )
}

///|
fn gen_rewrite_driver(
  tycon : String,
  struct_name : String,
  tree_info : TreeInfo,
  descs : Array[ConstrDescriptor],
  loc : @basic.Location,
) -> @syntax.Impl {
  let match_expr = build_rewrite_match(tycon, tree_info, descs, loc)

  // let Tycon(t) = self
  let wrapper_constr : @syntax.Constructor = {
    name: { name: tycon, loc },
    extra_info: NoExtraInfo,
    loc,
  }
  let t_pat_arg : @syntax.ConstrPatArg = {
    pat: Var({ name: "t", loc }),
    kind: Positional,
  }
  let wrapper_pattern : @syntax.Pattern = Constr(
    constr=wrapper_constr,
    args=Some(List([t_pat_arg])),
    is_open=false,
    loc~,
  )
  let fn_body : @syntax.Expr = Let(
    pattern=wrapper_pattern,
    expr=var_expr("self", loc),
    body=match_expr,
    loc~,
  )

  let alg_ty : @syntax.Type = Name(
    constr_id={ id: Ident(name=struct_name), loc },
    tys=List([
      type_ref("Env", loc),
      type_ref("St", loc),
      type_ref("Log", loc),
      type_ref("Err", loc),
    ]),
    loc~,
  )
  let ret_ty = passm_type(type_ref(tycon, loc), loc)
  let fun_decl : @syntax.FunDecl = {
    type_name: Some({ is_object: false, loc, name: Ident(name=tycon) }),
    name: { name: "rewrite_m", loc },
    is_async: None,
    decl_params: Some(
      List([
        Positional(binder={ name: "self", loc }, ty=Some(type_ref(tycon, loc))),
        Positional(binder={ name: "alg", loc }, ty=Some(alg_ty)),
      ]),
    ),
    params_loc: loc,
    quantifiers: rewrite_quantifiers(loc),
    return_type: Some(ret_ty),
    error_type: NoErrorType,
    vis: Default,
    attrs: @list.empty(),
    doc: @syntax.DocString::empty(),
    loc,
  }
  TopFuncDef(
    fun_decl~,
    decl_body=DeclBody(expr=fn_body),
    where_clause=None,
    loc~,
  )
}

///|
fn build_rewrite_match(
  _tycon : String,
  tree_info : TreeInfo,
  descs : Array[ConstrDescriptor],
  loc : @basic.Location,
) -> @syntax.Expr {
  let regular = descs.filter(fn(d) { !d.is_ext })
  let ext = descs.filter(fn(d) { d.is_ext })

  let cases : Array[@syntax.Case] = []
  regular.each(fn(d) { cases.push(rewrite_case(d, loc)) })
  if tree_info.ext_constr_index >= 0 {
    if ext.length() > 0 {
      cases.push(rewrite_ext_case(ext, loc))
    } else {
      // Tree has an `Ext` constructor but this language owns no ext variants
      // (base language: TreeExt = Unit). Emit `Ext(_) => abort(...)`.
      cases.push(ext_unreachable_case(loc))
    }
  }
  Match(expr=var_expr("t", loc), cases=List(cases[:]), match_loc=loc, loc~)
}

///|
/// A match case: `Constr(bind...) => (alg.constr_)(<args>)` where self-ref args
/// become the delayed `<bind>.rewrite_m(alg)`.
fn rewrite_case(d : ConstrDescriptor, loc : @basic.Location) -> @syntax.Case {
  let pat_args : Array[@syntax.ConstrPatArg] = []
  let call_args : Array[@syntax.Argument] = []
  d.params.each(fn(p) {
    let (kind, bind_name) : (@syntax.ArgumentKind, String) = match p.label {
      Some(l) => (Labelled(l), l.name)
      None => (Positional, p.name)
    }
    pat_args.push({ pat: Var({ name: bind_name, loc }), kind })
    let arg_expr = if p.is_self_ref {
      // <bind>.rewrite_m(alg)  -- delayed sub-computation
      @syntax.Expr::DotApply(
        self=var_expr(bind_name, loc),
        method_name={ name: "rewrite_m", loc },
        args=List([{ value: var_expr("alg", loc), kind: Positional }]),
        return_self=false,
        loc~,
      )
    } else {
      var_expr(bind_name, loc)
    }
    call_args.push({ value: arg_expr, kind: Positional })
  })
  let constr : @syntax.Constructor = {
    name: { name: d.name, loc },
    extra_info: NoExtraInfo,
    loc,
  }
  let pattern : @syntax.Pattern = Constr(
    constr~,
    args=if pat_args.length() > 0 { Some(List(pat_args[:])) } else { None },
    is_open=false,
    loc~,
  )
  // (alg.constr_)(args...)
  let handler = @syntax.Expr::Field(
    record=var_expr("alg", loc),
    accessor=Label({ name: d.field_name, loc }),
    loc~,
  )
  let body = @syntax.Expr::Apply(func=handler, args=List(call_args[:]), loc~)
  { pattern, guard_: None, body }
}

///|
/// The ext case: `Ext(te) => match te { <ext cases> }`.
fn rewrite_ext_case(
  ext_descs : Array[ConstrDescriptor],
  loc : @basic.Location,
) -> @syntax.Case {
  let ext_cases : Array[@syntax.Case] = []
  ext_descs.each(fn(d) { ext_cases.push(rewrite_case(d, loc)) })
  let nested_match : @syntax.Expr = Match(
    expr=var_expr("te", loc),
    cases=List(ext_cases[:]),
    match_loc=loc,
    loc~,
  )
  let ext_constr : @syntax.Constructor = {
    name: { name: "Ext", loc },
    extra_info: NoExtraInfo,
    loc,
  }
  let te_pat_arg : @syntax.ConstrPatArg = {
    pat: Var({ name: "te", loc }),
    kind: Positional,
  }
  let ext_pattern : @syntax.Pattern = Constr(
    constr=ext_constr,
    args=Some(List([te_pat_arg])),
    is_open=false,
    loc~,
  )
  { pattern: ext_pattern, guard_: None, body: nested_match }
}

///|
/// `Ext(_) => abort("...")` for languages whose `TreeExt` is `Unit` (no real
/// ext variants). The branch is unreachable for well-formed values but keeps
/// the match exhaustive over the Tree's `Ext` constructor.
fn ext_unreachable_case(loc : @basic.Location) -> @syntax.Case {
  let ext_constr : @syntax.Constructor = {
    name: { name: "Ext", loc },
    extra_info: NoExtraInfo,
    loc,
  }
  let any_arg : @syntax.ConstrPatArg = { pat: Any(loc~), kind: Positional }
  let ext_pattern : @syntax.Pattern = Constr(
    constr=ext_constr,
    args=Some(List([any_arg])),
    is_open=false,
    loc~,
  )
  let abort_call = @syntax.Expr::Apply(
    func=var_expr("abort", loc),
    args=List([
      {
        value: Constant(c=String("this language has no ext constructors"), loc~),
        kind: Positional,
      },
    ]),
    loc~,
  )
  { pattern: ext_pattern, guard_: None, body: abort_call }
}
