///|
pub enum Extensible {}

///|
pub(all) suberror NanopassParseError {
  InvalidAttribute(String) // invalid #nanopass.language attribute
  InvalidMbti(Json) // failed to parse .mbti interface file
} derive(Debug)

///|
/// A nonterminal in a language definition.
///
/// # Variants
/// - `Constructor` — a constructor referencing a nonterminal
/// - `TypeDecl` — an external type marked `#nanopass.nonterminal`
pub enum NonTerminal {
  Constructor(@syntax.ConstrDecl)
  TypeDecl(@syntax.TypeDecl)
}

///|
/// A leaf / non-recursive constructor in a language definition.
pub struct Terminal(@syntax.ConstrDecl)

///|
/// A language definition extracted from a single annotated enum.
pub struct NanoLangDef {
  name : String // from `#nanopass.language(name="...")`
  extends : String? // optional parent language (from `extends="..."`)
  nonterminals : Array[NonTerminal] // self-referencing constructors and referenced external types
  terminals : Array[Terminal] // leaf/non-recursive constructors
  type_decl : @syntax.TypeDecl // the raw parsed enum AST node
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
/// Result of comparing two `NanoLangDef`s via `NanoLangDef::diff`.
///
/// Implements `Show` as compact enum-like format with `+`/`-` prefixes.
pub(all) struct Diff {
  origin : NanoLangDef // the base language
  deriv : NanoLangDef // the compared language
  added_nonterminals : Array[NonTerminal] // only in deriv
  removed_nonterminals : Array[NonTerminal] // only in origin
  changed_nonterminals : Array[Modified[NonTerminal]] // same name, different params
  added_terminals : Array[Terminal] // only in deriv
  removed_terminals : Array[Terminal] // only in origin
  changed_terminals : Array[Modified[Terminal]] // same name, different params
} derive(Debug)
