///|
fn type_def_to_type_desc(td : @mbti_ast.TypeDefinition) -> @syntax.TypeDesc {
  match td {
    Abstract => @syntax.Abstract
    Alias(ty) => @syntax.Alias(ty)
    Error(ed) => @syntax.Error(ed)
    ExtensibleEnum(cs) => @syntax.ExtensibleEnum(cs)
    Newtype(ty) => @syntax.Alias(ty)
    Record(fields~) => @syntax.Record(fields~)
    TupleStruct(tys) => @syntax.TupleStruct(tys)
    Variant(cs) => @syntax.Variant(cs)
    ExtendEnum(target~, constructors~) => {
      let ty_name : @syntax.TypeName = {
        is_object: false,
        loc: target.loc,
        name: target.name,
      }
      @syntax.ExtendEnum(target=ty_name, constructors~)
    }
  }
}

///|
fn sig_to_impl(sig : @mbti_ast.Sig) -> @syntax.Impl? {
  match sig {
    Type(type_sig) => {
      let params = type_sig.type_params.map(fn(p) {
        match p {
          Name(name) =>
            @syntax.TypeDeclBinder::{ name: Some(name.name), loc: name.loc }
          Underscore(loc) => @syntax.TypeDeclBinder::{ name: None, loc }
        }
      })
      let type_decl : @syntax.TypeDecl = {
        attrs: type_sig.attrs,
        components: type_def_to_type_desc(type_sig.components),
        deriving: @list.empty(),
        doc: @syntax.DocString::empty(),
        is_declare: false,
        loc: type_sig.name.loc,
        params,
        tycon: type_sig.name.name,
        tycon_loc: type_sig.name.loc,
        type_vis: type_sig.vis,
      }
      Some(@syntax.TopTypeDef(type_decl))
    }
    Alias(alias_sig) =>
      match alias_sig {
        TypeAlias(name~, type_params~, type_~, vis~, attrs~) => {
          let params = type_params.map(fn(p) {
            match p {
              Name(n) =>
                @syntax.TypeDeclBinder::{ name: Some(n.name), loc: n.loc }
              Underscore(loc) => @syntax.TypeDeclBinder::{ name: None, loc }
            }
          })
          let type_decl : @syntax.TypeDecl = {
            attrs,
            components: @syntax.Alias(type_),
            deriving: @list.empty(),
            doc: @syntax.DocString::empty(),
            is_declare: false,
            loc: name.loc,
            params,
            tycon: name.name,
            tycon_loc: name.loc,
            type_vis: vis,
          }
          Some(@syntax.TopTypeDef(type_decl))
        }
        _ => None
      }
    _ => None
  }
}
