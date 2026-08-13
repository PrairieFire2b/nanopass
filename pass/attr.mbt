///|
/// Parse a `#nanopass.pass(...)` attribute into `PassMeta`.
///
/// # Raises
/// Raises if the `name` parameter is missing or the attribute format is invalid.
pub fn parse_pass_meta(attr : @attribute.Attribute) -> PassMeta raise {
  match attr.parsed {
    Some(Apply(_, props)) => {
      let name = get_string_prop(props, "name")
      match name {
        Some(n) => {
          let from = get_string_prop(props, "from").unwrap_or("")
          let to = get_string_prop(props, "to").unwrap_or("")
          let direction = match get_string_prop(props, "direction") {
            Some("top-down") | Some("TopDown") | Some("topdown") => TopDown
            _ => BottomUp
          }
          { name: n, from_lang: from, to_lang: to, direction }
        }
        None => fail("Missing `name` parameter in `#nanopass.pass` attribute")
      }
    }
    _ => fail("Invalid `#nanopass.pass` attribute format")
  }
}

///|
/// Extract a string value for a labeled prop from the prop list.
fn get_string_prop(
  props : @list.List[@attribute.Prop],
  label : String,
) -> String? {
  props
  .find(fn(prop) {
    match prop {
      Labeled(l, String(_)) => l == label
      _ => false
    }
  })
  .map(fn(prop) {
    match prop {
      Labeled(_, String(s)) => s
      _ => ""
    }
  })
}
