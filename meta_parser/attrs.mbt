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
