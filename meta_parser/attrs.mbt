///|
/// Get the simple type name from a Type AST node.
fn type_to_name(ty : @syntax.Type) -> String {
  match ty {
    @syntax.Name(constr_id~, ..) =>
      match constr_id.id {
        @syntax.Ident(name~) => name
        @syntax.Dot(id~, ..) => id
      }
    _ => ""
  }
}

///|
fn is_nano_attr(attr : @attribute.Attribute, name : String) -> Bool {
  attr.name() == Some(name) && attr.raw is [.. "#nano.", ..]
}

///|
fn nano_string_payload_from_attr(
  attr : @attribute.Attribute,
  name : String,
) -> String raise {
  let message = "#nano.\{name} expects a string literal payload"
  match attr.parsed {
    Some(Apply(_, props)) =>
      match
        props.find(fn(prop) {
          match prop {
            Expr(String(_)) => true
            _ => false
          }
        }) {
        Some(Expr(String(payload))) => payload
        _ => raise InvalidAttribute(message)
      }
    _ => raise InvalidAttribute(message)
  }
}

///|
fn nano_raw_payload_from_attr(
  attr : @attribute.Attribute,
  name : String,
) -> String raise {
  if !is_nano_attr(attr, name) {
    raise InvalidAttribute("Expected #nano.\{name} attribute")
  }
  match attr.raw.split_once("(") {
    Some((_, rest0)) => {
      let rest = rest0.to_owned()
      match rest.rev_find(")") {
        Some(end) => rest[:end].trim().to_owned()
        None => raise InvalidAttribute("#nano.\{name} expects a payload")
      }
    }
    None => raise InvalidAttribute("#nano.\{name} expects a payload")
  }
}

///|
fn form_string_from_attr(attr : @attribute.Attribute) -> String raise {
  nano_string_payload_from_attr(attr, "form")
}

///|
fn entry_string_from_attr(attr : @attribute.Attribute) -> String raise {
  nano_string_payload_from_attr(attr, "entry")
}

///|
fn meta_string_from_attr(attr : @attribute.Attribute) -> String raise {
  nano_string_payload_from_attr(attr, "meta")
}

///|
fn infix_string_from_attr(attr : @attribute.Attribute) -> String raise {
  nano_string_payload_from_attr(attr, "infix")
}

///|
fn name_string_from_attr(attr : @attribute.Attribute) -> String raise {
  nano_string_payload_from_attr(attr, "name")
}

///|
fn context_string_from_attr(attr : @attribute.Attribute) -> String raise {
  nano_string_payload_from_attr(attr, "context")
}

///|
fn parse_by_payload_from_attr(attr : @attribute.Attribute) -> String raise {
  nano_raw_payload_from_attr(attr, "parse_by")
}

///|
fn unparse_by_payload_from_attr(attr : @attribute.Attribute) -> String raise {
  nano_raw_payload_from_attr(attr, "unparse_by")
}
