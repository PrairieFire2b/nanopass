///|
priv struct FormPatternParser {
  chars : Array[Char]
  mut pos : Int
}

///|
fn FormPatternParser::eof(self : FormPatternParser) -> Bool {
  self.pos >= self.chars.length()
}

///|
fn FormPatternParser::peek(self : FormPatternParser) -> Char? {
  if self.eof() {
    None
  } else {
    Some(self.chars[self.pos])
  }
}

///|
fn FormPatternParser::advance(self : FormPatternParser) -> Char? {
  if self.eof() {
    None
  } else {
    let c = self.chars[self.pos]
    self.pos = self.pos + 1
    Some(c)
  }
}

///|
fn is_pattern_space(c : Char) -> Bool {
  c == ' ' || c == '\n' || c == '\r' || c == '\t'
}

///|
fn is_placeholder_char(c : Char) -> Bool {
  c.is_ascii_alphabetic() || c.is_ascii_digit() || c == '_' || c == '*'
}

///|
fn FormPatternParser::skip_spaces(self : FormPatternParser) -> Unit {
  while !self.eof() && is_pattern_space(self.chars[self.pos]) {
    self.pos = self.pos + 1
  }
}

///|
fn FormPatternParser::parse(self : FormPatternParser) -> FormPattern raise {
  self.skip_spaces()
  let pattern = self.parse_one()
  self.skip_spaces()
  if !self.eof() {
    raise InvalidAttribute("Unexpected tokens after #nano.form pattern")
  }
  pattern
}

///|
fn FormPatternParser::parse_one(self : FormPatternParser) -> FormPattern raise {
  self.skip_spaces()
  match self.peek() {
    Some('(') => self.parse_list()
    Some(')') => raise InvalidAttribute("Unexpected ')' in #nano.form pattern")
    Some(_) => self.parse_token()
    None => raise InvalidAttribute("Empty #nano.form pattern")
  }
}

///|
fn FormPatternParser::parse_list(self : FormPatternParser) -> FormPattern raise {
  ignore(self.advance())
  let items : Array[FormPattern] = []
  for ;; {
    self.skip_spaces()
    match self.peek() {
      Some(')') => {
        ignore(self.advance())
        break
      }
      Some(_) => {
        let item = self.parse_one()
        match item {
          AtomPattern("...") =>
            match items.pop() {
              Some(prev) =>
                match prev {
                  RepeatPattern(_) =>
                    raise InvalidAttribute(
                      "Ellipsis cannot follow another ellipsis in #nano.form pattern",
                    )
                  _ => items.push(RepeatPattern(prev))
                }
              None =>
                raise InvalidAttribute(
                  "Ellipsis must follow a pattern in #nano.form pattern",
                )
            }
          _ => items.push(item)
        }
      }
      None => raise InvalidAttribute("Unclosed list in #nano.form pattern")
    }
  }
  ListPattern(items)
}

///|
fn FormPatternParser::parse_token(
  self : FormPatternParser,
) -> FormPattern raise {
  let buf : Array[Char] = []
  for ;; {
    match self.peek() {
      Some(c) =>
        if is_pattern_space(c) || c == '(' || c == ')' {
          break
        } else {
          buf.push(c)
          ignore(self.advance())
        }
      None => break
    }
  }
  if buf.length() == 0 {
    raise InvalidAttribute("Expected token in #nano.form pattern")
  }
  compile_form_token(String::from_array(buf))
}

///|
fn find_dollar(chars : Array[Char]) -> Int? {
  for i in 0..<chars.length() {
    if chars[i] == '$' {
      return Some(i)
    }
  }
  None
}

///|
fn placeholder_end(chars : Array[Char], start : Int) -> Int {
  for i in start..<chars.length() {
    if !is_placeholder_char(chars[i]) {
      return i
    }
  }
  chars.length()
}

///|
fn chars_to_string(chars : Array[Char], start : Int, end : Int) -> String {
  if start >= end {
    ""
  } else {
    String::from_array(chars[start:end])
  }
}

///|
fn all_digits(text : String) -> Bool {
  !text.is_empty() && text.all(fn(c) { c.is_ascii_digit() })
}

///|
fn compile_form_token(token : String) -> FormPattern raise {
  let chars = token.to_array()
  match find_dollar(chars) {
    None => AtomPattern(token)
    Some(dollar) => {
      let start = dollar + 1
      if start >= chars.length() {
        raise InvalidAttribute("Missing placeholder name after '$'")
      }
      let end = placeholder_end(chars, start)
      if end == start {
        raise InvalidAttribute("Missing placeholder name after '$'")
      }
      let prefix = chars_to_string(chars, 0, dollar)
      let name = chars_to_string(chars, start, end)
      let suffix = chars_to_string(chars, end, chars.length())
      if all_digits(name) {
        let index = @string.parse_int(name) catch {
          _ =>
            raise InvalidAttribute("Invalid positional placeholder '$\{name}'")
        }
        FieldPattern(index~, prefix~, suffix~)
      } else {
        NamedFieldPattern(name~, prefix~, suffix~)
      }
    }
  }
}

///|
/// Compile a `#nano.form` surface string into a small structural pattern IR.
pub fn compile_form_pattern(input : String) -> FormPattern raise {
  ({ chars: input.to_array(), pos: 0 } : FormPatternParser).parse()
}
