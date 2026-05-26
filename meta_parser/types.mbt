///|
pub enum Extensible {}

///|
pub(all) suberror NanopassParseError {
  InvalidAttribute(String)
  InvalidMbti(Json)
} derive(Debug)

///|
pub enum NonTerminal {
  Constructor(@syntax.ConstrDecl)
  TypeDecl(@syntax.TypeDecl)
}

///|
pub struct Terminal(@syntax.ConstrDecl)

///|
/// Result type for language definitions found in a file
pub struct NanoLangDef {
  name : String
  extends : String?
  nonterminals : Array[NonTerminal]
  terminals : Array[Terminal]
  type_decl : @syntax.TypeDecl
}

///|
pub(all) struct Modified[T] {
  origin : T
  modified : T
} derive(Debug)

///|
type ModifiedTerminal = Modified[Terminal]

///|
type ModifiedNonTerminal = Modified[NonTerminal]

///|
/// Diff between two language definitions
pub(all) struct Diff {
  origin : NanoLangDef
  deriv : NanoLangDef
  added_nonterminals : Array[NonTerminal]
  removed_nonterminals : Array[NonTerminal]
  changed_nonterminals : Array[Modified[NonTerminal]]
  added_terminals : Array[Terminal]
  removed_terminals : Array[Terminal]
  changed_terminals : Array[Modified[Terminal]]
}
