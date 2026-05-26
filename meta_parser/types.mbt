///|
pub(all) suberror NanopassParseError {
  InvalidAttribute(String)
  InvalidMbti(Json)
} derive(Debug)

///|
pub enum NonTerminal {
  Constructor(@list.List[@syntax.ConstrDecl])
  TypeDecl(@syntax.TypeDecl)
}

///|
pub struct Terminal(@list.List[@syntax.ConstrDecl])

///|
/// Result type for language definitions found in a file
pub struct NanoLangDef {
  name : String
  extends : String?
  nonterminals : Array[NonTerminal]
  terminals : Array[Terminal]
  type_decl : @syntax.TypeDecl
}
