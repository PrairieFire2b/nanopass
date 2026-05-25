///|
pub(all) suberror NanopassParseError {
  InvalidAttribute(String)
} derive(Debug)

///|
/// Result type for language definitions found in a file
pub struct LanguageDefinition {
  name : String
  type_decl : @syntax.TypeDecl
}

///|
pub impl @debug.Debug for LanguageDefinition with fn to_repr(self) {
  @debug.Repr::record({
    "name": @debug.to_repr(self.name),
    "tycon": @debug.to_repr(self.type_decl.tycon),
  })
}

///|
pub fn get_name_from_attr(attr : @attribute.Attribute) -> String raise {
  match attr.parsed {
    Some(Apply(_, props)) => {
      let name_prop = props.find(fn(prop) {
        match prop {
          Labeled("name", String(_)) => true
          _ => false
        }
      })
      match name_prop {
        Some(Labeled(_, String(name))) => name
        _ =>
          raise NanopassParseError::InvalidAttribute(
            "Missing `name` parameter in `#nanopass.language` attribute",
          )
      }
    }
    _ =>
      raise NanopassParseError::InvalidAttribute(
        "Invalid `#nanopass.language` attribute format",
      )
  }
}

///|
pub fn find_languages(src : String) -> Array[LanguageDefinition] raise {
  // Parse the source file
  let (impls, _reports) = @parser.parse_file(src)

  // Collect language definitions
  let results : Array[LanguageDefinition] = []

  // Iterate through all top-level implementations
  for impl_ in impls {
    match impl_ {
      // Only interested in type definitions
      @syntax.TopTypeDef(type_decl) =>
        // Check if it's an enum (Variant)
        match type_decl.components {
          @syntax.Variant(_constructors) =>
            // Check if it has the nanopass.language attribute
            type_decl.attrs.each(attr => {
              match attr.raw {
                [.. "#nanopass.language", ..] => {
                  debug(attr.to_repr())
                  results.push({ name: get_name_from_attr(attr), type_decl })
                }
                _ => ()
              }
            })
          _ => () // Not an enum, skip
        }
      _ => () // Not a type definition, skip
    }
  }

  results
}

///|
test {
  let langs = find_languages("poc/lang_def.mbt")
  inspect(langs.length(), content="2")
  inspect(langs[0].name, content="Lambda")
  inspect(langs[1].name, content="SimplyTypedLambda")
}
