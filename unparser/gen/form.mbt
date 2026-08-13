// Surface-form driven parsing/unparsing.
//
// `meta_parser` normalizes `#nano.form`, `#nano.inline`, `#nano.infix` and
// `#nano.name` into a single `surface_forms : Array[ProductionFormRule]` on
// each `ConstructorLayout`. The generated code drives these through the sexp
// runtime's `@sexp.match_form` (parse) and `@sexp.form_doc` (unparse), so it
// does not re-implement pattern matching.
//
// Only numeric field placeholders (`$0`, `$1`, ...) are emitted, matching the
// sexp runtime's form pattern language; named placeholders are resolved to a
// field index first.

///|
/// Render a `FormPattern` to the sexp-runtime pattern string (numeric `$N`).
/// `field_index_of` maps a named placeholder to its source field index.
fn form_pattern_string(
  pattern : @meta_parser.FormPattern,
  field_index_of : (String) -> Int?,
) -> String {
  match pattern {
    AtomPattern(text) => text
    FieldPattern(index~, prefix~, suffix~) => "\{prefix}$\{index}\{suffix}"
    NamedFieldPattern(name~, prefix~, suffix~) =>
      match field_index_of(name) {
        Some(i) => "\{prefix}$\{i}\{suffix}"
        None => "\{prefix}$\{name}\{suffix}"
      }
    RepeatPattern(inner) => form_pattern_string(inner, field_index_of) + " ..."
    ListPattern(items) => {
      let parts = items.map(p => form_pattern_string(p, field_index_of))
      "(" + parts.join(" ") + ")"
    }
  }
}

///|
/// Field-index resolver for a constructor: maps a field label or bare numeric
/// name to the source field index.
fn field_index_resolver(c : @syntax.ConstrDecl) -> (String) -> Int? {
  let by_label : Map[String, Int] = Map([])
  constr_args(c).eachi((i, p) => {
    match p.label {
      Some(label) => by_label[label.name] = i
      None => ()
    }
  })
  fn(name) {
    match by_label.get(name) {
      Some(i) => Some(i)
      None => (@string.parse_int(name) |> Some) catch { _ => None }
    }
  }
}

///|
/// Is this form rule usable for parsing (a real surface form, not the plain
/// constructor-headed canonical form which the generator already handles)?
fn is_parse_form(origin : @meta_parser.ProductionFormOrigin) -> Bool {
  match origin {
    DeclaredForm | InlineForm | InfixForm | NameAliasForm => true
    CanonicalForm => false
  }
}

///|
/// The surface-form pattern strings that should drive *parsing*, in priority
/// order (declared first, then inline/infix/name). Excludes the canonical form.
fn parse_form_patterns(cl : @layout.ConstructorLayout) -> Array[String] {
  let resolve = field_index_resolver(cl.source_constr)
  let out : Array[String] = []
  cl.surface_forms.each(rule => {
    if is_parse_form(rule.origin) {
      out.push(form_pattern_string(rule.pattern, resolve))
    }
  })
  out
}

///|
/// The single surface form used for *unparsing*: the first declared form, else
/// the first inline/infix/name form. `None` means fall back to the plain
/// constructor-headed rendering the generator emits by default.
fn unparse_form_pattern(cl : @layout.ConstructorLayout) -> String? {
  let resolve = field_index_resolver(cl.source_constr)
  for rule in cl.surface_forms {
    if rule.origin is DeclaredForm {
      return Some(form_pattern_string(rule.pattern, resolve))
    }
  }
  for rule in cl.surface_forms {
    match rule.origin {
      InlineForm | InfixForm | NameAliasForm =>
        return Some(form_pattern_string(rule.pattern, resolve))
      _ => ()
    }
  }
  None
}
