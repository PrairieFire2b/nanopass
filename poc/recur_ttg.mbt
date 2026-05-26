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
fn main {
  let base_tree : UnannotatedLisp = List(
    [
      Symbol("lambda", ()),
      List([Symbol("x", ()), Symbol("y", ())], ()),
      List([Symbol("+", ()), Symbol("x", ()), Symbol("y", ())], ()),
    ],
    (),
  )
  debug(base_tree)
}
