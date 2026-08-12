///|
fn constr_to_string(c : @syntax.ConstrDecl) -> String {
  let name = c.name.name
  match c.args {
    Some(args) => {
      let params = StringBuilder::new()
      args.eachi(fn(i, p) {
        if i > 0 {
          params.write_string(", ")
        }
        match p.ty {
          Name(constr_id~, ..) =>
            match constr_id.id {
              Ident(name~) => params.write_string(name)
              Dot(id~, ..) => params.write_string(id)
            }
          _ => params.write_string("_")
        }
      })
      "\{name}(\{params.to_string()})"
    }
    None => name
  }
}

///|
pub impl Debug for NonTerminal with fn to_repr(self) -> Repr {
  match self {
    Constructor(c) =>
      Repr::ctor("Constructor", [(None, Repr::literal(constr_to_string(c)))])
    TypeDecl(td) => Repr::ctor("TypeDecl", [(None, Repr::string(td.tycon))])
  }
}

///|
pub impl Debug for Terminal with fn to_repr(self) -> Repr {
  let Terminal(c) = self
  Repr::literal(constr_to_string(c))
}

///|
pub impl Debug for NanoLangDef with fn to_repr(self) -> Repr {
  Repr::record({
    "name": Repr::string(self.name),
    "extends": Repr(self.extends),
    "nonterminals": Repr(self.nonterminals),
    "terminals": Repr(self.terminals),
    "tycon": Repr::string(self.type_decl.tycon),
  })
}
