///|
priv suberror CodegenError {
  InvalidGeneratedCode(String)
}

///|
fn generated_reports_message(reports : Array[@basic.Report]) -> String {
  reports.map(report => report.to_string()).join("\n")
}

///|
fn parse_generated_impls(source : String) -> Array[@syntax.Impl] raise {
  let (impls, reports) = @parser.parse_string(
    source,
    name="nanocake generated parse/unparse entries",
  )
  if !reports.is_empty() {
    raise InvalidGeneratedCode(generated_reports_message(reports))
  }
  impls.to_array()
}

///|
fn entry_source(lang : @meta_parser.NanoLangDef) -> String {
  let lang_name = lang.name
  let tycon = lang.type_decl.tycon
  [
    "///|",
    "pub fn parse_\{lang_name}(sexp : @sexp.Sexp) -> \{tycon} raise @sexp.Cause {",
    "  @sexp.with_context(\"parse \{lang_name}\", () => parse_\{lang_name}_raw(sexp))",
    "}",
    "",
    "///|",
    "fn parse_\{lang_name}_raw(_sexp : @sexp.Sexp) -> \{tycon} raise @sexp.SexpError {",
    "  raise @sexp.GeneratedCode(message=\"parse \{lang_name} is not generated yet\")",
    "}",
    "",
    "///|",
    "pub fn unparse_\{lang_name}(value : \{tycon}) -> @sexp.SexpDoc raise @sexp.Cause {",
    "  @sexp.with_context(\"unparse \{lang_name}\", () => unparse_\{lang_name}_raw(value))",
    "}",
    "",
    "///|",
    "fn unparse_\{lang_name}_raw(_value : \{tycon}) -> @sexp.SexpDoc raise @sexp.SexpError {",
    "  raise @sexp.GeneratedCode(message=\"unparse \{lang_name} is not generated yet\")",
    "}",
  ].join("\n")
}

///|
pub fn parse_unparse_entry_impls(
  langs : Array[@meta_parser.NanoLangDef],
) -> Array[@syntax.Impl] raise {
  parse_generated_impls(langs.map(entry_source).join("\n\n"))
}
