///|
pub enum Extensible {}

///|
pub(all) suberror NanopassParseError {
  InvalidAttribute(String) // invalid #nanopass.language attribute
  InvalidMbti(Json) // failed to parse .mbti interface file
  InvalidLanguage(String) // invalid language definition
} derive(Debug)

///|
/// A compiled S-expression form pattern from `#nano.form("...")`.
///
/// The initial IR is intentionally small: it captures atoms, list structure,
/// positional fields, and named fields. Later phases can extend it with repeat,
/// optional, dotted-list, vector, and datum-literal forms without changing the
/// parser/unparser contract.
pub(all) enum FormPattern {
  AtomPattern(String)
  FieldPattern(index~ : Int, prefix~ : String, suffix~ : String)
  NamedFieldPattern(name~ : String, prefix~ : String, suffix~ : String)
  RepeatPattern(FormPattern)
  ListPattern(Array[FormPattern])
} derive(Debug, Eq)

///|
pub(all) enum CanonicalPolicy {
  Canonical
  FormOnly
} derive(Debug, Eq)

///|
pub(all) enum ProductionFormOrigin {
  DeclaredForm
  NameAliasForm
  CanonicalForm
  InlineForm
  InfixForm
} derive(Debug, Eq)

///|
pub(all) struct ProductionFormRule {
  origin : ProductionFormOrigin
  pattern : FormPattern
} derive(Debug, Eq)

///|
pub(all) struct NanoHooks {
  parse_by : String?
  unparse_by : String?
} derive(Debug, Eq)

///|
pub(all) struct ProductionField {
  index : Int
  label : String?
  type_name : String
} derive(Debug, Eq)

///|
pub(all) struct ProductionDef {
  owner : String
  constr_name : String
  fields : Array[ProductionField]
  patterns : Array[FormPattern]
  surface_forms : Array[ProductionFormRule]
  canonical_policy : CanonicalPolicy
  hooks : NanoHooks
  name_alias : String?
  inline : Bool
  infix_operator : String?
  source_constr : @syntax.ConstrDecl
}

///|
pub(all) struct MetaVarDecl {
  owner : String
  name : String
} derive(Debug, Eq)

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
  entry : String? // optional entry nonterminal (from `#nano.entry` or `entry="..."`)
  meta_vars : Array[MetaVarDecl] // declared meta-variable names in this raw language
  nonterminals : Array[NonTerminal] // self-referencing constructors and referenced external types
  terminals : Array[Terminal] // leaf/non-recursive constructors
  production_defs : Array[ProductionDef] // normalized constructor metadata
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
