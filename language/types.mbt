///|
using @meta_parser {type NanoLangDef}

///|
pub suberror LangError {
  NoLanguageFound
}

///|
pub struct Language {
  name : String
  group : Array[NanoLangDef]
} derive(Debug)
