///|
/// A parsed nanocake sidecar specification.
pub(all) struct NanoSpec {
  version : Int
  source : String
  nonterminals : Array[String]
  languages : Array[NanoSpecLanguage]
} derive(Debug, Eq)

///|
pub(all) struct NanoSpecLanguage {
  name : String
  tycon : String
  extends : String?
  layer : String?
  entry : String?
  meta_vars : Array[String]
  removed : Array[String]
  productions : Array[NanoSpecProduction]
} derive(Debug, Eq)

///|
pub(all) struct NanoSpecProduction {
  name : String
  forms : Array[FormPattern]
  form_only : Bool
  parse_by : String?
  unparse_by : String?
  contexts : Array[String]
} derive(Debug, Eq)

///|
/// Parse and validate the schema-level structure of a nanocake sidecar.
pub fn parse_nano_spec(input : String) -> NanoSpec raise NanopassParseError {
  let root = parse_spec(input)
  let top = spec_list(root, "root")
  expect_head(top, "nanocake", "root")
  let version = one_int(find_clause(top, "version"), "version")
  let source = one_text(find_clause(top, "source"), "source")
  let nonterminals = clauses(top, "nonterminal").map(node => {
    node_one_text(node, "nonterminal")
  })
  let languages = clauses(top, "language").map(parse_spec_language)
  if languages.length() == 0 {
    raise InvalidLanguage(".cake: at least one language is required")
  }
  { version, source, nonterminals, languages }
}

///|
fn spec_list(
  node : SpecNode,
  path : String,
) -> Array[SpecNode] raise NanopassParseError {
  match node {
    SpecList(items~, ..) => items
    _ => raise InvalidLanguage(".cake: expected list at " + path)
  }
}

///|
fn spec_atom(node : SpecNode, path : String) -> String raise NanopassParseError {
  match node {
    SpecAtom(value~, ..) => value
    _ => raise InvalidLanguage(".cake: expected atom at " + path)
  }
}

///|
fn spec_text(node : SpecNode, path : String) -> String raise NanopassParseError {
  match node {
    SpecAtom(value~, ..) => value
    SpecString(value~, ..) => value
    _ => raise InvalidLanguage(".cake: expected text at " + path)
  }
}

///|
fn expect_head(
  items : Array[SpecNode],
  head : String,
  path : String,
) -> Unit raise NanopassParseError {
  guard items.get(0) is Some(node) else {
    raise InvalidLanguage(".cake: empty list at " + path)
  }
  if spec_atom(node, path) != head {
    raise InvalidLanguage(".cake: expected '" + head + "' at " + path)
  }
}

///|
fn find_clause(items : Array[SpecNode], name : String) -> SpecNode? {
  for node in items[1:] {
    match node {
      SpecList(items~, ..) =>
        match items.get(0) {
          Some(SpecAtom(value~, ..)) => if value == name { return Some(node) }
          _ => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn clauses(items : Array[SpecNode], name : String) -> Array[SpecNode] {
  items[1:].filter(node => {
    match node {
      SpecList(items~, ..) =>
        match items.get(0) {
          Some(SpecAtom(value~, ..)) => value == name
          _ => false
        }
      _ => false
    }
  })
}

///|
fn one_text(node : SpecNode?, path : String) -> String raise NanopassParseError {
  match node {
    Some(value) => node_one_text(value, path)
    None => raise InvalidLanguage(".cake: missing (" + path + " ...)")
  }
}

///|
fn node_one_text(
  node : SpecNode,
  path : String,
) -> String raise NanopassParseError {
  let items = spec_list(node, path)
  if items.length() != 2 {
    raise InvalidLanguage(".cake: (" + path + " ...) expects one value")
  }
  spec_text(items[1], path)
}

///|
fn one_int(node : SpecNode?, path : String) -> Int raise NanopassParseError {
  let text = one_text(node, path)
  @string.parse_int(text[:]) catch {
    _ => raise InvalidLanguage(".cake: invalid integer in (" + path + " ...)")
  }
}

///|
fn parse_spec_language(
  node : SpecNode,
) -> NanoSpecLanguage raise NanopassParseError {
  let items = spec_list(node, "language")
  if items.length() < 2 {
    raise InvalidLanguage(".cake: language requires a name")
  }
  let name = spec_atom(items[1], "language.name")
  let tycon = one_text(find_clause(items, "type"), "type")
  let extends = find_clause(items, "extends").map(node => {
    node_one_text(node, "extends")
  })
  let layer = find_clause(items, "layer").map(node => {
    node_one_text(node, "layer")
  })
  let entry = find_clause(items, "entry").map(node => {
    node_one_text(node, "entry")
  })
  let meta_vars = clauses(items, "meta").map(node => node_one_text(node, "meta"))
  let removed = match find_clause(items, "remove") {
    Some(remove) =>
      spec_list(remove, "remove")[1:].map(node => spec_text(node, "remove"))
    None => []
  }
  let productions = clauses(items, "production").map(parse_spec_production)
  { name, tycon, extends, layer, entry, meta_vars, removed, productions }
}

///|
fn parse_spec_production(
  node : SpecNode,
) -> NanoSpecProduction raise NanopassParseError {
  let items = spec_list(node, "production")
  if items.length() < 2 {
    raise InvalidLanguage(".cake: production requires a name")
  }
  let name = spec_atom(items[1], "production.name")
  let forms = clauses(items, "form").map(node => {
    let form_items = spec_list(node, "form")
    if form_items.length() != 2 {
      raise InvalidLanguage(".cake: form expects one pattern")
    }
    spec_pattern(form_items[1])
  })
  let form_only = find_clause(items, "form-only") is Some(_)
  let parse_by = find_clause(items, "parse-by").map(node => {
    node_one_text(node, "parse-by")
  })
  let unparse_by = find_clause(items, "unparse-by").map(node => {
    node_one_text(node, "unparse-by")
  })
  let contexts = clauses(items, "context").map(node => {
    node_one_text(node, "context")
  })
  { name, forms, form_only, parse_by, unparse_by, contexts }
}

///|
fn spec_pattern(node : SpecNode) -> FormPattern {
  match node {
    SpecAtom(value~, ..) => {
      let chars = value.to_array()
      if chars.length() > 1 && chars[0] == '$' {
        let name = value[1:].to_owned()
        if name.all(c => c.is_ascii_digit()) {
          FieldPattern(
            index=try! @string.parse_int(name[:]),
            prefix="",
            suffix="",
          )
        } else {
          NamedFieldPattern(name~, prefix="", suffix="")
        }
      } else {
        AtomPattern(value)
      }
    }
    SpecString(value~, ..) => AtomPattern(value)
    SpecList(items~, ..) => ListPattern(items.map(spec_pattern))
  }
}
