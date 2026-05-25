///|
pub(all) suberror NanopassParseError {
  InvalidAttribute(String)
  InvalidMbti(Json)
} derive(Debug)

///|
/// Result type for language definitions found in a file
pub struct LanguageDef {
  name : String
  type_decl : @syntax.TypeDecl
}
