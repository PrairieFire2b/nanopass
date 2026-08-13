///|
/// Generate identity transformation functions for each concrete language.
pub fn gen_identity(lang : @language.Language) -> @list.List[@syntax.Impl] {
  let impls : Array[@syntax.Impl] = []
  let loc = lang.group[0].type_decl.loc
  lang.group.each(fn(nl) {
    let tycon = nl.type_decl.tycon
    let ret_ty : @syntax.Type = Name(
      constr_id={ id: Ident(name=tycon), loc },
      tys=@list.empty(),
      loc~,
    )
    let fun_decl : @syntax.FunDecl = {
      type_name: Some({ is_object: false, loc, name: Ident(name=tycon) }),
      name: { name: "identity", loc },
      is_async: None,
      decl_params: Some(
        List([Positional(binder={ name: "self", loc }, ty=Some(ret_ty))]),
      ),
      params_loc: loc,
      quantifiers: @list.empty(),
      return_type: Some(ret_ty),
      error_type: DefaultErrorType(loc~),
      vis: Default,
      attrs: @list.empty(),
      doc: @syntax.DocString::empty(),
      loc,
    }
    impls.push(
      TopFuncDef(
        fun_decl~,
        decl_body=DeclBody(
          expr=Ident(id={ name: Ident(name="self"), loc }, loc~),
        ),
        where_clause=None,
        loc~,
      ),
    )
  })
  List(impls[:])
}
