///|
pub impl Debug for NonTerminal with fn to_repr(self) -> Repr {
  match self {
    Constructor(constrs) => {
      let arr : Array[Repr] = []
      constrs.each(fn(c) { arr.push(Repr::string(c.name.name)) })
      Repr::ctor("Constructor", [(None, Repr::array(arr))])
    }
    TypeDecl(td) => Repr::ctor("TypeDecl", [(None, Repr::string(td.tycon))])
  }
}

///|
pub impl Debug for Terminal with fn to_repr(self) -> Repr {
  let Terminal(constrs) = self
  let arr : Array[Repr] = []
  constrs.each(fn(c) { arr.push(Repr::string(c.name.name)) })
  Repr::record({ "constructors": Repr::array(arr) })
}

///|
pub impl Debug for NanoLangDef with fn to_repr(self) -> Repr {
  Repr::record({
    "name": Repr::string(self.name),
    "extends": @debug.to_repr(self.extends),
    "nonterminals": @debug.to_repr(self.nonterminals),
    "terminals": @debug.to_repr(self.terminals),
    "tycon": Repr::string(self.type_decl.tycon),
  })
}
