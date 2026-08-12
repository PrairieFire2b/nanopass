///|
priv struct Cursor {
  src : String
  mut pos : Int
}

///|
fn Cursor::eof(self : Cursor) -> Bool {
  self.pos >= self.src.length()
}

///|
fn Cursor::peek(self : Cursor) -> Char? {
  if self.eof() {
    None
  } else {
    self.src.get_char(self.pos)
  }
}

///|
fn Cursor::bump(self : Cursor) -> Char? {
  match self.peek() {
    Some(ch) => {
      self.pos = self.pos + 1
      Some(ch)
    }
    None => None
  }
}

///|
fn is_space(ch : Char) -> Bool {
  ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t'
}

///|
fn is_delim(ch : Char) -> Bool {
  is_space(ch) || ch == '(' || ch == ')'
}

///|
fn Cursor::skip_space(self : Cursor) -> Unit {
  while (match self.peek() {
          Some(ch) => is_space(ch)
          None => false
        }) {
    ignore(self.bump())
  }
}

///|
fn Cursor::parse_atom(self : Cursor) -> Sexp raise SexpError {
  let start = self.pos
  let buf = StringBuilder::new()
  while (match self.peek() {
          Some(ch) => !is_delim(ch)
          None => false
        }) {
    match self.bump() {
      Some(ch) => buf.write_char(ch)
      None => ()
    }
  }
  let text = buf.to_string()
  if text == "" {
    raise Syntax(path="", message="expected atom")
  }
  Atom(text, loc=Some({ start, end: self.pos }))
}

///|
fn Cursor::parse_list(self : Cursor) -> Sexp raise SexpError {
  let start = self.pos
  ignore(self.bump())
  let items : Array[Sexp] = []
  self.skip_space()
  while (match self.peek() {
          Some(ch) => ch != ')'
          None => false
        }) {
    items.push(self.parse_one())
    self.skip_space()
  }
  match self.bump() {
    Some(')') => List(items, loc=Some({ start, end: self.pos }))
    _ => raise Syntax(path="", message="unterminated list")
  }
}

///|
fn Cursor::parse_one(self : Cursor) -> Sexp raise SexpError {
  self.skip_space()
  match self.peek() {
    Some('(') => self.parse_list()
    Some(')') => raise Syntax(path="", message="unexpected `)`")
    Some(_) => self.parse_atom()
    None => raise Syntax(path="", message="unexpected end of input")
  }
}

///|
pub fn parse(src : StringView) -> Sexp raise SexpError {
  let cursor = { src: src.to_owned(), pos: 0 }
  let sexp = cursor.parse_one()
  cursor.skip_space()
  if !cursor.eof() {
    raise Syntax(path="", message="trailing input")
  }
  sexp
}
