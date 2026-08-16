///|
fn SpecParser::eof(self : SpecParser) -> Bool {
  self.pos >= self.input.length()
}

///|
fn SpecParser::peek(self : SpecParser) -> Char? {
  self.input.get_char(self.pos)
}

///|
fn SpecParser::bump(self : SpecParser) -> Char? {
  match self.peek() {
    Some(c) => {
      self.pos = self.pos + 1
      Some(c)
    }
    None => None
  }
}

///|
fn spec_error(offset : Int, message : String) -> NanopassParseError {
  InvalidLanguage(".cake at offset \{offset}: \{message}")
}

///|
fn is_spec_space(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t'
}

///|
fn SpecParser::skip_space(self : SpecParser) -> Unit {
  for ;; {
    while (match self.peek() {
            Some(c) => is_spec_space(c)
            None => false
          }) {
      ignore(self.bump())
    }
    if self.peek() is Some(';') {
      while self.peek() is Some(c) && c != '\n' {
        ignore(self.bump())
      }
    } else {
      break
    }
  }
}

///|
fn SpecParser::parse_document(
  self : SpecParser,
) -> SpecNode raise NanopassParseError {
  self.skip_space()
  let node = self.parse_one()
  self.skip_space()
  if !self.eof() {
    raise spec_error(self.pos, "trailing input")
  }
  node
}

///|
fn SpecParser::parse_one(
  self : SpecParser,
) -> SpecNode raise NanopassParseError {
  self.skip_space()
  let start = self.pos
  match self.peek() {
    Some('(') => self.parse_list(start)
    Some(')') => raise spec_error(self.pos, "unexpected ')'")
    Some('"') => self.parse_string(start)
    Some(_) => self.parse_atom(start)
    None => raise spec_error(self.pos, "unexpected end of input")
  }
}

///|
fn SpecParser::parse_list(
  self : SpecParser,
  start : Int,
) -> SpecNode raise NanopassParseError {
  ignore(self.bump())
  let items : Array[SpecNode] = []
  self.skip_space()
  while self.peek() is Some(c) && c != ')' {
    items.push(self.parse_one())
    self.skip_space()
  }
  match self.bump() {
    Some(')') => SpecList(items~, span={ start, end: self.pos })
    _ => raise spec_error(self.pos, "unclosed list")
  }
}

///|
fn SpecParser::parse_string(
  self : SpecParser,
  start : Int,
) -> SpecNode raise NanopassParseError {
  ignore(self.bump())
  let buf = StringBuilder::new()
  while (match self.peek() {
          Some('"') => false
          Some(_) => true
          None => false
        }) {
    match self.bump() {
      Some('\\') =>
        match self.bump() {
          Some('"') => buf.write_char('"')
          Some('\\') => buf.write_char('\\')
          Some('n') => buf.write_char('\n')
          Some('r') => buf.write_char('\r')
          Some('t') => buf.write_char('\t')
          _ => raise spec_error(self.pos, "unsupported string escape")
        }
      Some(c) => buf.write_char(c)
      None => raise spec_error(self.pos, "unclosed string")
    }
  }
  match self.bump() {
    Some('"') =>
      SpecString(value=buf.to_string(), span={ start, end: self.pos })
    _ => raise spec_error(self.pos, "unclosed string")
  }
}

///|
fn SpecParser::parse_atom(self : SpecParser, start : Int) -> SpecNode {
  let buf = StringBuilder::new()
  while (match self.peek() {
          Some(c) => !is_spec_space(c) && c != '(' && c != ')' && c != ';'
          None => false
        }) {
    match self.bump() {
      Some(c) => buf.write_char(c)
      None => break
    }
  }
  SpecAtom(value=buf.to_string(), span={ start, end: self.pos })
}
