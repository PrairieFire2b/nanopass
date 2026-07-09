///|
pub(all) struct Span {
  start : Int
  end : Int
} derive(Debug, Eq)

///|
pub(all) enum Sexp {
  Atom(String, loc~ : Span?)
  List(Array[Sexp], loc~ : Span?)
} derive(Debug, Eq)

///|
pub(all) enum SexpDoc {
  AtomDoc(String)
  ListDoc(Array[SexpDoc])
} derive(Debug, Eq)

///|
pub(all) suberror SexpError {
  Syntax(path~ : String, message~ : String)
  Decode(path~ : String, message~ : String)
  HookError(path~ : String, hook~ : String, message~ : String)
  GeneratedCode(message~ : String)
} derive(Debug)

///|
pub fn[A] decode_error(path~ : String, message~ : String) -> A raise SexpError {
  raise Decode(path~, message~)
}

///|
pub fn[A] hook_error(
  path~ : String,
  hook~ : String,
  message~ : String,
) -> A raise SexpError {
  raise HookError(path~, hook~, message~)
}

///|
pub fn[A] literal_failure(
  failures : Array[String],
  path~ : String,
) -> A raise SexpError {
  let message = if failures.is_empty() {
    "no literal parser matched"
  } else {
    let details = failures.join("; ")
    "no literal parser matched: \{details}"
  }
  raise Decode(path~, message~)
}

///|
pub fn add_hook_failure(
  failures : Array[String],
  hook : String,
  message : String,
) -> Unit {
  failures.push("\{hook}: \{message}")
}

///|
pub fn[A] unknown_head(head : String, path~ : String) -> A raise SexpError {
  decode_error(path~, message="unknown head `\{head}`")
}

///|
pub fn atom_text(sexp : Sexp) -> String? {
  match sexp {
    Atom(text, loc=_) => Some(text)
    List(_) => None
  }
}

///|
pub fn list_items(sexp : Sexp) -> Array[Sexp]? {
  match sexp {
    List(items, loc=_) => Some(items)
    Atom(_) => None
  }
}

///|
pub fn expect_atom(sexp : Sexp, path~ : String) -> String raise SexpError {
  match atom_text(sexp) {
    Some(text) => text
    None => decode_error(path~, message="expected atom")
  }
}

///|
pub fn expect_list(sexp : Sexp, path~ : String) -> Array[Sexp] raise SexpError {
  match list_items(sexp) {
    Some(items) => items
    None => decode_error(path~, message="expected list")
  }
}

///|
pub fn expect_arity(
  items : Array[Sexp],
  arity : Int,
  path~ : String,
) -> Unit raise SexpError {
  if items.length() != arity {
    decode_error(
      path~,
      message="expected \{arity} item(s), got \{items.length()}",
    )
  }
}

///|
pub fn int_from_atom(sexp : Sexp, path~ : String) -> Int raise SexpError {
  let atom = expect_atom(sexp, path~)
  @string.parse_int(atom[:]) catch {
    _ => decode_error(path~, message="expected Int atom")
  }
}

///|
pub fn string_from_atom(sexp : Sexp, path~ : String) -> String raise SexpError {
  expect_atom(sexp, path~)
}

