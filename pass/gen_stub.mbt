///|
/// M4: Diff-driven minimal-coverage rewrite stub.
///
/// Given a language group whose derived language `extends` a base, the `Diff`
/// tells us exactly which constructors changed or were added. A pass author
/// should only have to write handlers for those; everything else is identity.
///
/// `gen_rewrite_stub` emits, for the derived language `Deriv`:
///
///   fn[Env, St, Log, Err] <pass_name>() -> DerivRewriteAlg[Env, St, Log, Err] {
///     let base = DerivRewriteAlg::identity()
///     // Override the changed/added constructors below:
///     { ..base, Lam_: base.Lam_, If_: base.If_, True_: base.True_, ... }
///   }
///
/// Each re-listed field is an identity placeholder (`base.<field>`) that the
/// author replaces with real logic. Unchanged constructors are covered by the
/// `..base` spread and never appear, which is the whole point: the stub's
/// surface is the minimal coverage set.

///|
/// The set of constructor field names (e.g. "Lam_", "If_") that changed or were
/// added between the base and derived language, per `Diff`. `TypeDecl`
/// nonterminals (external types like `Type`) are skipped: they are not Tree
/// constructors and have no rewrite handler.
pub fn changed_and_added_fields(diff : @meta_parser.Diff) -> Array[String] {
  let names : Array[String] = []
  let push_unique = fn(n : String) { if !names.contains(n) { names.push(n) } }

  // changed / added nonterminals (constructors only)
  diff.changed_nonterminals.each(fn(m) {
    match m.modified {
      Constructor(c) => push_unique(field_name(c.name.name))
      TypeDecl(_) => ()
    }
  })
  diff.added_nonterminals.each(fn(nt) {
    match nt {
      Constructor(c) => push_unique(field_name(c.name.name))
      TypeDecl(_) => ()
    }
  })

  // changed / added terminals
  diff.changed_terminals.each(fn(m) {
    let Terminal(c) = m.modified
    push_unique(field_name(c.name.name))
  })
  diff.added_terminals.each(fn(t) {
    let Terminal(c) = t
    push_unique(field_name(c.name.name))
  })
  names
}

///|
/// Generate a minimal-coverage rewrite stub for the derived language.
///
/// The language group must have at least two languages (base + derived). The
/// `Diff` between `group[0]` and `group[1]` drives the coverage set.
pub fn gen_rewrite_stub(
  lang : @language.Language,
  pass_name : String,
) -> @list.List[@syntax.Impl] raise {
  if lang.group.length() < 2 {
    fail("gen_rewrite_stub: needs a base + derived language pair")
  }
  let loc = lang.group[0].type_decl.loc
  let deriv_tycon = lang.group[1].type_decl.tycon
  let struct_name = deriv_tycon + "RewriteAlg"
  let diff = lang.group[0].diff(lang.group[1])
  let fields = changed_and_added_fields(diff)

  // let base = DerivRewriteAlg::identity()
  let identity_call = @syntax.Expr::Apply(
    func=Method(
      type_name={ is_object: false, loc, name: Ident(name=struct_name) },
      method_name={ name: "identity", loc },
      loc~,
    ),
    args=@list.empty(),
    loc~,
  )

  // TypedExprRewriteAlg::{ ..base, Field_: base.Field_, ... }
  let spread_fields : Array[@syntax.FieldDef] = []
  fields.each(fn(f) {
    let access = @syntax.Expr::Field(
      record=var_expr("base", loc),
      accessor=Label({ name: f, loc }),
      loc~,
    )
    spread_fields.push({
      label: { name: f, loc },
      expr: access,
      is_pun: false,
      loc,
    })
  })
  let record_expr : @syntax.Expr = RecordUpdate(
    type_name=Some({ name: Ident(name=struct_name), is_object: false, loc }),
    record=var_expr("base", loc),
    fields=List(spread_fields[:]),
    loc~,
  )

  let body : @syntax.Expr = Let(
    pattern=Var({ name: "base", loc }),
    expr=identity_call,
    body=record_expr,
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
    type_name: None,
    name: { name: pass_name, loc },
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
  List([
    TopFuncDef(
      fun_decl~,
      decl_body=DeclBody(expr=body),
      where_clause=None,
      loc~,
    ),
  ])
}
