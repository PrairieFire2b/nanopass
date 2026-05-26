///|
enum LispT[Self_, SymbolE, ListE, CaseT] {
  True
  False
  Integer(BigInt)
  Symbol(String, SymbolE)
  List(Array[Self_], ListE)
  Cases(CaseT)
} derive(Debug)

///|
struct Lisp[SymbolE, ListE, CaseT](
  LispT[Lisp[SymbolE, ListE, CaseT], SymbolE, ListE, CaseT]
) derive(Debug)

///|
type UnannotatedLisp = Lisp[Unit, Unit, Unit]

///|
struct SourceLocation {
  line : Int
  column : Int
} derive(Debug, Default, Eq)

///|
type SourceRange = (SourceLocation, SourceLocation)

///|
type SourcedLisp = Lisp[SourceRange, SourceRange, Unit]

///|
test {
  let base_tree : UnannotatedLisp = List(
    [
      Symbol("lambda", ()),
      List([Symbol("x", ()), Symbol("y", ())], ()),
      List([Symbol("+", ()), Symbol("x", ()), Symbol("y", ())], ()),
    ],
    (),
  )
  debug_inspect(
    base_tree,
    content=(
      #|Lisp(
      #|  List(
      #|    [
      #|      Lisp(Symbol("lambda", ())),
      #|      Lisp(List([Lisp(Symbol("x", ())), Lisp(Symbol("y", ()))], ())),
      #|      Lisp(
      #|        List(
      #|          [Lisp(Symbol("+", ())), Lisp(Symbol("x", ())), Lisp(Symbol("y", ()))],
      #|          (),
      #|        ),
      #|      ),
      #|    ],
      #|    (),
      #|  ),
      #|)
    ),
  )
}
