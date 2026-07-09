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
fn render_doc(doc : SexpDoc, sb : StringBuilder) -> Unit {
  match doc {
    AtomDoc(text) => sb.write_string(text)
    ListDoc(items) => {
      sb.write_char('(')
      items.eachi(fn(i, item) {
        if i > 0 {
          sb.write_char(' ')
        }
        render_doc(item, sb)
      })
      sb.write_char(')')
    }
  }
}

///|
pub fn SexpDoc::render(self : SexpDoc, width? : Int = 80) -> String {
  ignore(width)
  let sb = StringBuilder::new()
  render_doc(self, sb)
  sb.to_string()
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

