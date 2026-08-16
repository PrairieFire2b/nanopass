///|
/// A source span in a `.cake` specification.
pub(all) struct SpecSpan {
  start : Int
  end : Int
} derive(Debug, Eq)

///|
/// The small S-expression tree used by the nanocake metadata DSL.
pub(all) enum SpecNode {
  SpecAtom(value~ : String, span~ : SpecSpan)
  SpecString(value~ : String, span~ : SpecSpan)
  SpecList(items~ : Array[SpecNode], span~ : SpecSpan)
} derive(Debug, Eq)

///|
/// Parse a complete nanocake metadata document.
pub fn parse_spec(input : String) -> SpecNode raise NanopassParseError {
  let parser : SpecParser = { input, pos: 0 }
  parser.parse_document()
}

///|
priv struct SpecParser {
  input : String
  mut pos : Int
}
