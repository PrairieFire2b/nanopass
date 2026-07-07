///|
fn form_patterns_from_attrs(
  attrs : @list.List[@attribute.Attribute],
) -> Array[FormPattern] raise {
  let patterns : Array[FormPattern] = []
  attrs.each(attr => {
    if is_nano_attr(attr, "form") {
      patterns.push(compile_form_pattern(form_string_from_attr(attr)))
    }
  })
  patterns
}

///|
fn canonical_policy_from_attrs(
  attrs : @list.List[@attribute.Attribute],
) -> CanonicalPolicy {
  if attrs.any(attr => is_nano_attr(attr, "form_only")) {
    FormOnly
  } else {
    Canonical
  }
}

///|
fn single_attr_payload(
  owner : String,
  constr_name : String,
  attrs : @list.List[@attribute.Attribute],
  attr_name : String,
  read_payload : (@attribute.Attribute) -> String raise,
) -> String? raise {
  let values : Array[String] = []
  attrs.each(attr => {
    if is_nano_attr(attr, attr_name) {
      let value = read_payload(attr)
      if value.is_empty() {
        let message = if attr_name == "infix" || attr_name == "name" {
          "#nano.\{attr_name} expects a non-empty string literal payload"
        } else {
          "#nano.\{attr_name} expects a non-empty payload"
        }
        raise InvalidAttribute(message)
      }
      values.push(value)
    }
  })
  match values.length() {
    0 => None
    1 => Some(values[0])
    _ =>
      raise InvalidLanguage(
        "Production '\{owner}.\{constr_name}' declares #nano.\{attr_name} more than once",
      )
  }
}

///|
fn hooks_from_attrs(
  owner : String,
  constr_name : String,
  attrs : @list.List[@attribute.Attribute],
) -> NanoHooks raise {
  {
    parse_by: single_attr_payload(
      owner, constr_name, attrs, "parse_by", parse_by_payload_from_attr,
    ),
    unparse_by: single_attr_payload(
      owner, constr_name, attrs, "unparse_by", unparse_by_payload_from_attr,
    ),
  }
}

///|
fn name_alias_from_attrs(
  owner : String,
  constr_name : String,
  attrs : @list.List[@attribute.Attribute],
) -> String? raise {
  single_attr_payload(owner, constr_name, attrs, "name", name_string_from_attr)
}

///|
fn infix_operator_from_attrs(
  owner : String,
  constr_name : String,
  attrs : @list.List[@attribute.Attribute],
) -> String? raise {
  single_attr_payload(
    owner, constr_name, attrs, "infix", infix_string_from_attr,
  )
}

///|
fn production_fields_from_constr(
  c : @syntax.ConstrDecl,
) -> Array[ProductionField] {
  let fields : Array[ProductionField] = []
  match c.args {
    Some(args) =>
      args.eachi(fn(index, param) {
        let label = match param.label {
          Some(label) => Some(label.name)
          None => None
        }
        fields.push({ index, label, type_name: type_to_name(param.ty) })
      })
    None => ()
  }
  fields
}

///|
fn production_def_from_constr(
  owner : String,
  c : @syntax.ConstrDecl,
) -> ProductionDef raise {
  {
    owner,
    constr_name: c.name.name,
    fields: production_fields_from_constr(c),
    patterns: form_patterns_from_attrs(c.attrs),
    canonical_policy: canonical_policy_from_attrs(c.attrs),
    hooks: hooks_from_attrs(owner, c.name.name, c.attrs),
    name_alias: name_alias_from_attrs(owner, c.name.name, c.attrs),
    inline: c.attrs.any(attr => is_nano_attr(attr, "inline")),
    infix_operator: infix_operator_from_attrs(owner, c.name.name, c.attrs),
    source_constr: c,
  }
}
