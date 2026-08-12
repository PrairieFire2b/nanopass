///|
priv enum FormPattern {
  AtomPattern(String)
  FieldPattern(Int, String, String)
  ListPattern(Array[FormPattern])
}

///|
pub struct SexpForm {
  priv pattern : FormPattern
  priv path : String
}

///|
fn is_digit_char(ch : Char) -> Bool {
  let code = ch.to_int()
  code >= '0'.to_int() && code <= '9'.to_int()
}

///|
fn form_atom_pattern(text : String) -> FormPattern {
  let view = text[:]
  if view.length() > 1 && view.unsafe_get(0).to_int() == '$'.to_int() {
    let mut end = 1
    while end < view.length() &&
          (match view.get_char(end) {
            Some(ch) => is_digit_char(ch)
            None => false
          }) {
      end = end + 1
    }
    if end > 1 {
      let index = @string.parse_int(view[1:end]) catch { _ => -1 }
      if index >= 0 {
        FieldPattern(index, "", view[end:].to_owned())
      } else {
        AtomPattern(text)
      }
    } else {
      AtomPattern(text)
    }
  } else {
    AtomPattern(text)
  }
}

///|
fn FormPattern::from_sexp(sexp : Sexp) -> FormPattern {
  match sexp {
    Atom(text, loc=_) => form_atom_pattern(text)
    List(items, loc=_) => ListPattern(items.map(FormPattern::from_sexp))
  }
}

///|
pub fn SexpForm::compile(
  pattern : StringView,
  path~ : String,
) -> SexpForm raise SexpError {
  let sexp = parse(pattern) catch {
    _ =>
      raise GeneratedCode(
        message="invalid #nano.form pattern at \{path}: parse failed",
      )
  }
  { pattern: FormPattern::from_sexp(sexp), path }
}

///|
fn strip_form_affixes(sexp : Sexp, prefix : String, suffix : String) -> Sexp? {
  if prefix == "" && suffix == "" {
    Some(sexp)
  } else {
    match atom_text(sexp) {
      Some(atom) => {
        let mut view = atom[:]
        if prefix != "" {
          match view.strip_prefix(prefix[:]) {
            Some(rest) => view = rest
            None => return None
          }
        }
        if suffix != "" {
          match view.strip_suffix(suffix[:]) {
            Some(rest) => view = rest
            None => return None
          }
        }
        if view.is_empty() {
          None
        } else {
          Some(Atom(view.to_owned(), loc=None))
        }
      }
      None => None
    }
  }
}

///|
fn capture_form_field(
  captures : Array[Sexp?],
  index : Int,
  value : Sexp,
  path : String,
) -> Bool raise SexpError {
  if index < 0 || index >= captures.length() {
    raise GeneratedCode(
      message="invalid #nano.form pattern at \{path}: field $\{index} out of range",
    )
  }
  match captures[index] {
    Some(old) => old == value
    None => {
      captures[index] = Some(value)
      true
    }
  }
}

///|
fn FormPattern::matches(
  self : FormPattern,
  sexp : Sexp,
  captures : Array[Sexp?],
  path : String,
) -> Bool raise SexpError {
  match self {
    AtomPattern(text) => atom_text(sexp) == Some(text)
    FieldPattern(index, prefix, suffix) =>
      match strip_form_affixes(sexp, prefix, suffix) {
        Some(value) => capture_form_field(captures, index, value, path)
        None => false
      }
    ListPattern(patterns) =>
      match list_items(sexp) {
        Some(items) =>
          if items.length() == patterns.length() {
            let mut ok = true
            for i in 0..<patterns.length() {
              if ok && !patterns[i].matches(items[i], captures, path) {
                ok = false
              }
            }
            ok
          } else {
            false
          }
        None => false
      }
  }
}

///|
pub fn SexpForm::match_sexp(
  self : SexpForm,
  sexp : Sexp,
  field_count : Int,
) -> Array[Sexp]? raise SexpError {
  let captures : Array[Sexp?] = Array::make(field_count, None)
  if self.pattern.matches(sexp, captures, self.path) {
    let fields : Array[Sexp] = []
    for i in 0..<field_count {
      match captures[i] {
        Some(value) => fields.push(value)
        None =>
          raise GeneratedCode(
            message="invalid #nano.form pattern at \{self.path}: missing field $\{i}",
          )
      }
    }
    Some(fields)
  } else {
    None
  }
}

///|
pub fn match_form(
  sexp : Sexp,
  pattern : StringView,
  field_count : Int,
  path~ : String,
) -> Array[Sexp]? raise SexpError {
  SexpForm::compile(pattern, path~).match_sexp(sexp, field_count)
}

///|
fn affix_form_doc(
  doc : SexpDoc,
  prefix : String,
  suffix : String,
  path : String,
) -> SexpDoc raise SexpError {
  if prefix == "" && suffix == "" {
    doc
  } else {
    match doc {
      AtomDoc(text) => SexpDoc::atom("\{prefix}\{text}\{suffix}")
      ListDoc(_) =>
        decode_error(
          path~,
          message="expected atom doc for affixed #nano.form field",
        )
    }
  }
}

///|
fn FormPattern::to_doc(
  self : FormPattern,
  fields : Array[SexpDoc],
  path : String,
) -> SexpDoc raise SexpError {
  match self {
    AtomPattern(text) => SexpDoc::atom(text)
    FieldPattern(index, prefix, suffix) =>
      match fields.get(index) {
        Some(doc) => affix_form_doc(doc, prefix, suffix, path)
        None =>
          raise GeneratedCode(
            message="invalid #nano.form pattern at \{path}: field $\{index} out of range",
          )
      }
    ListPattern(patterns) => {
      let docs : Array[SexpDoc] = []
      for i in 0..<patterns.length() {
        docs.push(patterns[i].to_doc(fields, path))
      }
      SexpDoc::list(docs)
    }
  }
}

///|
pub fn SexpForm::to_doc(
  self : SexpForm,
  fields : Array[SexpDoc],
) -> SexpDoc raise SexpError {
  self.pattern.to_doc(fields, self.path)
}

///|
pub fn form_doc(
  pattern : StringView,
  fields : Array[SexpDoc],
  path~ : String,
) -> SexpDoc raise SexpError {
  SexpForm::compile(pattern, path~).to_doc(fields)
}
