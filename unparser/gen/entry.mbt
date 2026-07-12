// Public entry point.

///|
/// Group constructor layouts by their source type, preserving first-seen order.
fn group_by_type(
  layout : @layout.GeneratedLanguageLayout,
) -> Array[TypeCodegen] {
  let types : Array[TypeCodegen] = []
  for cl in layout.constructors {
    let mut found = false
    for t in types {
      if t.tycon == cl.source_tycon {
        t.constructors.push(cl)
        found = true
        break
      }
    }
    if !found {
      types.push({ tycon: cl.source_tycon, constructors: [cl] })
    }
  }
  types
}

///|
/// Emit the codec source text for a whole language group.
pub fn gen_source(lang : @language.Language) -> String raise {
  let layout = lang.layout()
  let types = group_by_type(layout)
  let sb = StringBuilder::new()
  for tc in types {
    sb.write_string(gen_from_sexp(types, tc, layout.tree))
    sb.write_string(gen_to_sexp_doc(types, tc, layout.tree))
    sb.write_string(gen_string_entries(tc.tycon))
  }
  sb.to_string()
}

///|
/// Generate the parser/unparser codecs for `lang` as parsed MoonBit impls.
pub fn gen(lang : @language.Language) -> Array[@syntax.Impl] raise {
  let source = gen_source(lang)
  let (impls, reports) = @parser.parse_string(
    source,
    name="nanocake generated sexp codecs",
  )
  if !reports.is_empty() {
    raise GenError::InvalidGeneratedCode(
      reports.map(r => r.to_string()).join("\n"),
    )
  }
  impls.to_array()
}
