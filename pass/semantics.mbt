///|
/// Generate unified `Semantics[Repr]` struct, identity denotation, and generic
/// catamorphism for each concrete language in the group.
///
/// Replaces the separate `gen_transform` + `gen_fold` + `gen_minimal_pass` with
/// a single parameterized design:
///
/// - `Repr = Tycon`: transform (identity denotation)
/// - `Repr = SomeOtherType`: fold / analysis
///
/// Users override only the constructors they care about via spread-default:
/// `{ ..identity(), field: override }`.
pub fn gen_semantics(
  lang : @language.Language,
) -> @list.List[@syntax.Impl] raise {
  let tree_info = tree_info_from_layout(lang.layout())
  let loc = lang.group[0].type_decl.loc
  let impls : Array[@syntax.Impl] = []
  lang.group.eachi(fn(i, nl) { gen_for_lang(nl, i, tree_info, loc, impls) })
  @list.from_array(impls[:])
}

///|
fn gen_for_lang(
  nl : @meta_parser.NanoLangDef,
  index : Int,
  tree_info : TreeInfo,
  loc : @basic.Location,
  impls : Array[@syntax.Impl],
) -> Unit {
  let tycon = nl.type_decl.tycon
  let is_base = index == 0
  let ext_enum_name = match tree_info.ext_enum {
    Some(ee) => Some(ee.name)
    None => None
  }

  // Collect flat descriptor list once — drives struct fields, identity, and cata
  let descs = collect_descriptors(tree_info, tycon, is_base, ext_enum_name, loc)
  let struct_name = tycon + "Semantics"

  // struct {Name}Semantics[Repr] { ... }
  impls.push(gen_semantics_struct(struct_name, descs, loc))

  // fn {Name}Semantics::identity() -> {Name}Semantics[{Name}]
  impls.push(gen_identity_impl(struct_name, tycon, descs, loc))

  // fn[R] {Name}::cata(self, s: {Name}Semantics[R]) -> R
  impls.push(gen_cata_impl(tycon, struct_name, tree_info, descs, loc))
}

///|
/// ---- Semantics struct type declaration ----

///|
fn gen_semantics_struct(
  struct_name : String,
  descs : Array[ConstrDescriptor],
  loc : @basic.Location,
) -> @syntax.Impl {
  let repr_ty = type_ref("Repr", loc)
  let fields : Array[@syntax.FieldDecl] = []
  descs.each(fn(d) {
    let arg_tys = d.params.map(fn(p) { p.field_ty })
    let fn_ty = make_fn_type(arg_tys, repr_ty, loc)
    fields.push(make_field_decl(d.field_name, fn_ty, loc))
  })
  let struct_type_decl : @syntax.TypeDecl = {
    attrs: @list.empty(),
    components: @syntax.Record(
      fields=@list.from_array(fields[:]),
      constr_decl=None,
    ),
    deriving: @list.empty(),
    doc: @syntax.DocString::empty(),
    is_declare: false,
    loc,
    params: @list.from_array([{ name: Some("Repr"), loc }]),
    tycon: struct_name,
    tycon_loc: loc,
    type_vis: @syntax.Visibility::Default,
  }
  @syntax.TopTypeDef(struct_type_decl)
}

///|
/// ---- Identity denotation ----

///|
fn gen_identity_impl(
  struct_name : String,
  tycon : String,
  descs : Array[ConstrDescriptor],
  loc : @basic.Location,
) -> @syntax.Impl {
  let fields : Array[@syntax.FieldDef] = []
  descs.each(fn(d) { fields.push(identity_field_from_desc(d, tycon, loc)) })

  let record_expr : @syntax.Expr = @syntax.Record(
    type_name=None,
    fields=@list.from_array(fields[:]),
    trailing=@syntax.TrailingMark::None,
    loc~,
  )

  let ret_ty : @syntax.Type = @syntax.Name(
    constr_id={ id: @syntax.LongIdent::Ident(name=struct_name), loc },
    tys=@list.from_array([
      @syntax.Name(
        constr_id={ id: @syntax.LongIdent::Ident(name=tycon), loc },
        tys=@list.empty(),
        loc~,
      ),
    ]),
    loc~,
  )

  let fun_decl : @syntax.FunDecl = {
    type_name: Some({
      is_object: false,
      loc,
      name: @syntax.LongIdent::Ident(name=struct_name),
    }),
    name: { name: "identity", loc },
    is_async: None,
    decl_params: Some(@list.empty()),
    params_loc: loc,
    quantifiers: @list.empty(),
    return_type: Some(ret_ty),
    error_type: @syntax.ErrorType::DefaultErrorType(loc~),
    vis: @syntax.Visibility::Default,
    attrs: @list.empty(),
    doc: @syntax.DocString::empty(),
    loc,
  }

  @syntax.TopFuncDef(
    fun_decl~,
    decl_body=@syntax.DeclBody::DeclBody(expr=record_expr),
    where_clause=None,
    loc~,
  )
}

///|
fn identity_field_from_desc(
  d : ConstrDescriptor,
  tycon : String,
  loc : @basic.Location,
) -> @syntax.FieldDef {
  // Lambda parameters
  let params_rev : Array[@syntax.Parameter] = []
  let arg_exprs : Array[@syntax.Expr] = []
  d.params.each(fn(p) {
    params_rev.push(
      @syntax.Parameter::Positional(binder={ name: p.name, loc }, ty=None),
    )
    arg_exprs.push(var_expr(p.name, loc))
  })

  // Body: for regular constructors, call Tycon::Constr(...);
  // for ext constructors, wrap with Tycon::Ext(ExtEnum::Constr(...))
  let body = if d.is_ext {
    let ext_enum_name = match d.ext_enum_name {
      Some(n) => n
      None => abort("ext constructor without ext_enum_name")
    }
    let ext_inner = make_constr_call(ext_enum_name, d.name, arg_exprs, loc)
    @syntax.Expr::Apply(
      func=@syntax.Expr::Method(
        type_name={
          is_object: false,
          loc,
          name: @syntax.LongIdent::Ident(name=tycon),
        },
        method_name={ name: "Ext", loc },
        loc~,
      ),
      args=@list.from_array([
        { value: ext_inner, kind: @syntax.ArgumentKind::Positional },
      ]),
      loc~,
    )
  } else {
    make_constr_call(tycon, d.name, arg_exprs, loc)
  }

  let lambda_func : @syntax.Func = {
    parameters: @list.from_array(params_rev[:]),
    params_loc: loc,
    body,
    return_type: None,
    error_type: @syntax.ErrorType::DefaultErrorType(loc~),
    kind: @syntax.FnKind::Lambda,
    is_async: None,
    loc,
  }

  {
    label: { name: d.field_name, loc },
    expr: @syntax.Expr::Function(func=lambda_func, loc~),
    is_pun: false,
    loc,
  }
}

///|
/// ---- Catamorphism ----

///|
fn gen_cata_impl(
  tycon : String,
  struct_name : String,
  tree_info : TreeInfo,
  descs : Array[ConstrDescriptor],
  loc : @basic.Location,
) -> @syntax.Impl {
  let match_expr = build_cata_match(tycon, tree_info, descs, loc)

  let tree_constr : @syntax.Constructor = {
    name: { name: "Tree", loc },
    extra_info: @syntax.ConstructorExtraInfo::NoExtraInfo,
    loc,
  }
  let t_pat_arg : @syntax.ConstrPatArg = {
    pat: @syntax.Pattern::Var({ name: "t", loc }),
    kind: @syntax.ArgumentKind::Positional,
  }
  let tree_pattern : @syntax.Pattern = @syntax.Pattern::Constr(
    constr=tree_constr,
    args=Some(@list.from_array([t_pat_arg])),
    is_open=false,
    loc~,
  )

  let fn_body : @syntax.Expr = @syntax.Expr::Let(
    pattern=tree_pattern,
    expr=var_expr("self", loc),
    body=match_expr,
    loc~,
  )

  let repr_ty : @syntax.Type = @syntax.Name(
    constr_id={ id: @syntax.LongIdent::Ident(name="R"), loc },
    tys=@list.empty(),
    loc~,
  )

  let sem_param_type : @syntax.Type = @syntax.Name(
    constr_id={ id: @syntax.LongIdent::Ident(name=struct_name), loc },
    tys=@list.from_array([repr_ty]),
    loc~,
  )

  let fun_decl : @syntax.FunDecl = {
    type_name: Some({
      is_object: false,
      loc,
      name: @syntax.LongIdent::Ident(name=tycon),
    }),
    name: { name: "cata", loc },
    is_async: None,
    decl_params: Some(
      @list.from_array([
        @syntax.Parameter::Positional(
          binder={ name: "self", loc },
          ty=Some(
            @syntax.Name(
              constr_id={ id: @syntax.LongIdent::Ident(name=tycon), loc },
              tys=@list.empty(),
              loc~,
            ),
          ),
        ),
        @syntax.Parameter::Positional(
          binder={ name: "s", loc },
          ty=Some(sem_param_type),
        ),
      ]),
    ),
    params_loc: loc,
    quantifiers: @list.from_array([
      { name: "R", name_loc: loc, constraints: @list.empty() },
    ]),
    return_type: Some(repr_ty),
    error_type: @syntax.ErrorType::DefaultErrorType(loc~),
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
fn build_cata_match(
  tycon : String,
  tree_info : TreeInfo,
  descs : Array[ConstrDescriptor],
  loc : @basic.Location,
) -> @syntax.Expr {
  // Split descriptors: regular → top-level cases, ext → nested inside Ext(te)
  let regular = descs.filter(fn(d) { if d.is_ext { false } else { true } })
  let ext = descs.filter(fn(d) { d.is_ext })

  let cases : Array[@syntax.Case] = []
  regular.each(fn(d) { cases.push(cata_case_from_desc(d, tycon, loc)) })

  if tree_info.ext_constr_index >= 0 {
    cases.push(cata_ext_case(ext, tree_info, tycon, loc))
  }

  @syntax.Expr::Match(
    expr=var_expr("t", loc),
    cases=@list.from_array(cases[:]),
    match_loc=loc,
    loc~,
  )
}

///|
fn cata_case_from_desc(
  d : ConstrDescriptor,
  tycon : String,
  loc : @basic.Location,
) -> @syntax.Case {
  // Build pattern: ConstrName(arg0, arg1, ...), respecting labels
  let pat_vars : Array[@syntax.Binder] = []
  let pat_args : Array[@syntax.ConstrPatArg] = []
  d.params.each(fn(p) {
    pat_vars.push({ name: p.name, loc })
    let kind : @syntax.ArgumentKind = match p.label {
      Some(l) => @syntax.ArgumentKind::Labelled(l)
      None => @syntax.ArgumentKind::Positional
    }
    pat_args.push({ pat: @syntax.Pattern::Var({ name: p.name, loc }), kind })
  })

  let constr : @syntax.Constructor = {
    name: { name: d.name, loc },
    extra_info: @syntax.ConstructorExtraInfo::NoExtraInfo,
    loc,
  }
  let args : @list.List[@syntax.ConstrPatArg]? = if pat_args.length() > 0 {
    Some(@list.from_array(pat_args[:]))
  } else {
    None
  }
  let pattern : @syntax.Pattern = @syntax.Pattern::Constr(
    constr~,
    args~,
    is_open=false,
    loc~,
  )

  let body = cata_field_call(d, tycon, loc)
  { pattern, guard_: None, body }
}

///|
fn cata_ext_case(
  ext_descs : Array[ConstrDescriptor],
  tree_info : TreeInfo,
  tycon : String,
  loc : @basic.Location,
) -> @syntax.Case {
  match ext_descs.length() > 0 {
    true => {
      let ext_cases : Array[@syntax.Case] = []
      ext_descs.each(fn(d) {
        ext_cases.push(cata_case_from_desc(d, tycon, loc))
      })

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
        args=Some(@list.from_array([te_pat_arg])),
        is_open=false,
        loc~,
      )

      let nested_match : @syntax.Expr = @syntax.Expr::Match(
        expr=var_expr("te", loc),
        cases=@list.from_array(ext_cases[:]),
        match_loc=loc,
        loc~,
      )

      { pattern: ext_pattern, guard_: None, body: nested_match }
    }
    false => {
      let ext_constr : @syntax.Constructor = {
        name: { name: "Ext", loc },
        extra_info: @syntax.ConstructorExtraInfo::NoExtraInfo,
        loc,
      }
      let any_pat_arg : @syntax.ConstrPatArg = {
        pat: @syntax.Pattern::Any(loc~),
        kind: @syntax.ArgumentKind::Positional,
      }
      let ext_pattern : @syntax.Pattern = @syntax.Pattern::Constr(
        constr=ext_constr,
        args=Some(@list.from_array([any_pat_arg])),
        is_open=false,
        loc~,
      )
      let body : @syntax.Expr = @syntax.Expr::Field(
        record=var_expr("s", loc),
        accessor=@syntax.Accessor::Label({ name: "ext_", loc }),
        loc~,
      )
      { pattern: ext_pattern, guard_: None, body }
    }
  }
}

///|
fn cata_field_call(
  d : ConstrDescriptor,
  tycon : String,
  loc : @basic.Location,
) -> @syntax.Expr {
  let args : Array[@syntax.Argument] = []
  d.params.each(fn(p) {
    let var_e = var_expr(p.name, loc)
    let arg_e = if p.is_self_ref {
      @syntax.Expr::DotApply(
        self=var_e,
        method_name={ name: "cata", loc },
        args=@list.from_array([
          { value: var_expr("s", loc), kind: @syntax.ArgumentKind::Positional },
        ]),
        return_self=false,
        loc~,
      )
    } else {
      var_e
    }
    args.push({ value: arg_e, kind: @syntax.ArgumentKind::Positional })
  })

  @syntax.Expr::DotApply(
    self=var_expr("s", loc),
    method_name={ name: d.field_name, loc },
    args=@list.from_array(args[:]),
    return_self=false,
    loc~,
  )
}
