///|
test "sexp doc helpers render" {
  let doc = SexpDoc::list([
    SexpDoc::atom("Lam"),
    SexpDoc::string("x"),
    SexpDoc::list([
      SexpDoc::atom("Arrow"),
      SexpDoc::atom("Bool"),
      SexpDoc::atom("Int"),
    ]),
    SexpDoc::int(42),
  ])
  inspect(doc.render(), content="(Lam x (Arrow Bool Int) 42)")
  inspect(
    render(
      list_doc([
        atom_doc("Lam"),
        string_to_doc("x"),
        list_doc([atom_doc("Arrow"), atom_doc("Bool"), atom_doc("Int")]),
        int_to_doc(42),
      ]),
    ),
    content="(Lam x (Arrow Bool Int) 42)",
  )
  inspect(
    parse("(Lam x (Arrow Bool Int) 42)").to_doc().render(),
    content="(Lam x (Arrow Bool Int) 42)",
  )
}

///|
test "sexp doc render uses width-aware pretty printing" {
  let doc = SexpDoc::list([
    SexpDoc::atom("Lam"),
    SexpDoc::string("x"),
    SexpDoc::list([
      SexpDoc::atom("Arrow"),
      SexpDoc::atom("Bool"),
      SexpDoc::atom("Int"),
    ]),
    SexpDoc::int(42),
  ])
  inspect(
    doc.render(width=12),
    content=(
      #|(
      #|  Lam
      #|  x
      #|  (
      #|    Arrow
      #|    Bool
      #|    Int
      #|  )
      #|  42
      #|)
    ),
  )
  inspect(
    @prettyprinter.render(doc.to_pretty(), width=80),
    content="(Lam x (Arrow Bool Int) 42)",
  )
}
