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
fn infix_operator_from_attrs(
  owner : String,
  constr_name : String,
  attrs : @list.List[@attribute.Attribute],
) -> String? raise {
  let operators : Array[String] = []
  attrs.each(attr => {
    if is_nano_attr(attr, "infix") {
      let op = infix_string_from_attr(attr)
      if op.is_empty() {
        raise InvalidAttribute(
          "#nano.infix expects a non-empty string literal payload",
        )
      }
      operators.push(op)
    }
  })
  match operators.length() {
    0 => None
    1 => Some(operators[0])
    _ =>
      raise InvalidLanguage(
        "Production '\{owner}.\{constr_name}' declares #nano.infix more than once",
      )
  }
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
    infix_operator: infix_operator_from_attrs(owner, c.name.name, c.attrs),
    contexts: context_specs_from_attrs(owner, c.name.name, c.attrs),
    source_constr: c,
  }
}
