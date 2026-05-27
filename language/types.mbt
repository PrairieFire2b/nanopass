///|
using @meta_parser {type NanoLangDef}

///|
/// Error type for language operations.
pub suberror LangError {
  /// No language definitions matched the given name.
  NoLanguageFound
}

///|
/// A language group consisting of a base language and its extensions.
/// `group[0]` is the base, subsequent entries are derived languages (via `extends`).
pub struct Language {
  name : String
  group : Array[NanoLangDef]
  interface : @meta_parser.Mbti
} derive(Debug)
