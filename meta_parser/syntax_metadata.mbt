///|
fn syntax_layer_from_name(name : String) -> SyntaxLayer raise {
  if name.is_empty() {
    raise InvalidAttribute(
      "#nano.layer expects a non-empty string literal payload",
    )
  }
  match name {
    "lexeme" => LexemeLayer
    "datum" => DatumLayer
    "surface" => SurfaceLayer
    "expanded-core" => ExpandedCoreLayer
    "typed-core" => TypedCoreLayer
    _ => raise InvalidAttribute("Unknown #nano.layer '\{name}'")
  }
}

///|
fn syntax_layer_from_attrs(
  lang_name : String,
  attrs : @list.List[@attribute.Attribute],
) -> SyntaxLayer? raise {
  let layers : Array[SyntaxLayer] = []
  attrs.each(attr => {
    if is_nano_attr(attr, "layer") {
      layers.push(syntax_layer_from_name(layer_string_from_attr(attr)))
    }
  })
  match layers.length() {
    0 => None
    1 => Some(layers[0])
    _ =>
      raise InvalidLanguage(
        "Language '\{lang_name}' declares #nano.layer more than once",
      )
  }
}

///|
fn context_spec_from_name(name : String) -> ContextSpec raise {
  if name.is_empty() {
    raise InvalidAttribute(
      "#nano.context expects a non-empty string literal payload",
    )
  }
  { name, }
}

///|
fn context_specs_from_attrs(
  owner : String,
  constr_name : String,
  attrs : @list.List[@attribute.Attribute],
) -> Array[ContextSpec] raise {
  let contexts : Array[ContextSpec] = []
  attrs.each(attr => {
    if is_nano_attr(attr, "context") {
      let context = context_spec_from_name(context_string_from_attr(attr))
      if contexts.any(existing => existing.name == context.name) {
        raise InvalidLanguage(
          "Production '\{owner}.\{constr_name}' declares #nano.context '\{context.name}' more than once",
        )
      }
      contexts.push(context)
    }
  })
  contexts
}
