///|
pub impl @debug.Debug for LanguageDef with fn to_repr(self) {
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
pub fn find_languages(src : String) -> Array[LanguageDef] raise {
  let (impls, _reports) = @parser.parse_file(src)
  impls
  .filter_map(impl_ => {
    match impl_ {
      @syntax.TopTypeDef(type_decl) =>
        match type_decl.components {
          @syntax.Variant(_constructors) =>
            type_decl.attrs
            .iter()
            .find_first(attr => attr.raw is [.. "#nanopass.language", ..])
            .map(
              // debug(attr.to_repr())
              attr => { name: get_name_from_attr(attr), type_decl },
            )
          _ => None
        }
      _ => None
    }
  })
  .to_array()
}

///|
test {
  let langs = find_languages("poc/lang_def.mbt")
  inspect(langs.length(), content="2")
  inspect(langs[0].name, content="Lambda")
  inspect(langs[1].name, content="SimplyTypedLambda")
}
