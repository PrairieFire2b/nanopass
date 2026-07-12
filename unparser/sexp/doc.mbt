///|
pub fn SexpDoc::atom(text : String) -> SexpDoc {
  AtomDoc(text)
}

///|
pub fn SexpDoc::list(items : Array[SexpDoc]) -> SexpDoc {
  ListDoc(items)
}

///|
pub fn SexpDoc::int(value : Int) -> SexpDoc {
  SexpDoc::atom(value.to_string())
}

///|
pub fn SexpDoc::string(value : String) -> SexpDoc {
  SexpDoc::atom(value)
}

///|
pub fn atom_doc(text : String) -> SexpDoc {
  SexpDoc::atom(text)
}

///|
pub fn list_doc(items : Array[SexpDoc]) -> SexpDoc {
  SexpDoc::list(items)
}

///|
pub fn int_to_doc(value : Int) -> SexpDoc {
  SexpDoc::int(value)
}

///|
pub fn string_to_doc(value : String) -> SexpDoc {
  SexpDoc::string(value)
}

///|
pub fn SexpDoc::to_pretty(self : SexpDoc) -> @prettyprinter.Document {
  match self {
    AtomDoc(text) => @prettyprinter.text(text)
    ListDoc(items) => {
      let body = @prettyprinter.separate(
        @prettyprinter.line,
        items.map(fn(item) { item.to_pretty() }),
      )
      @prettyprinter.group(
        @prettyprinter.parens(
          @prettyprinter.nest(@prettyprinter.softline + body) +
          @prettyprinter.softline,
        ),
      )
    }
  }
}

///|
pub impl @prettyprinter.Pretty for SexpDoc with fn pretty(self) {
  self.to_pretty()
}

///|
pub fn SexpDoc::render(self : SexpDoc, width? : Int = 80) -> String {
  @prettyprinter.render(self, width~)
}

///|
pub fn render(doc : SexpDoc, width? : Int = 80) -> String {
  doc.render(width~)
}

///|
pub fn Sexp::to_doc(self : Sexp) -> SexpDoc {
  match self {
    Atom(text, loc=_) => SexpDoc::atom(text)
    List(items, loc=_) => SexpDoc::list(items.map(fn(item) { item.to_doc() }))
  }
}
