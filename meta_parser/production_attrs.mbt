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
fn contexts_from_attrs(
  attrs : @list.List[@attribute.Attribute],
) -> Array[String] raise {
  let contexts : Array[String] = []
  attrs.each(attr => {
    if is_nano_attr(attr, "context") {
      let context = context_string_from_attr(attr)
      if context.is_empty() {
        raise InvalidAttribute(
          "#nano.context expects a non-empty string literal payload",
        )
      }
      contexts.push(context)
    }
  })
  contexts
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
fn field_pattern_from_index(index : Int) -> FormPattern {
  FieldPattern(index~, prefix="", suffix="")
}

///|
fn field_patterns_from_fields(
  fields : Array[ProductionField],
) -> Array[FormPattern] {
  let patterns : Array[FormPattern] = []
  fields.each(field => patterns.push(field_pattern_from_index(field.index)))
  patterns
}

///|
fn constructor_form_pattern(
  head : String,
  fields : Array[ProductionField],
) -> FormPattern {
  let items : Array[FormPattern] = [AtomPattern(head)]
  fields.each(field => items.push(field_pattern_from_index(field.index)))
  ListPattern(items)
}

///|
fn add_declared_form_rules(
  rules : Array[ProductionFormRule],
  patterns : Array[FormPattern],
) -> Unit {
  patterns.each(pattern => rules.push({ origin: DeclaredForm, pattern }))
}

///|
fn add_canonical_form_rules(
  rules : Array[ProductionFormRule],
  constr_name : String,
  fields : Array[ProductionField],
  canonical_policy : CanonicalPolicy,
  name_alias : String?,
) -> Unit {
  if canonical_policy is Canonical {
    match name_alias {
      Some(alias_name) =>
        rules.push({
          origin: NameAliasForm,
          pattern: constructor_form_pattern(alias_name, fields),
        })
      None => ()
    }
    rules.push({
      origin: CanonicalForm,
      pattern: constructor_form_pattern(constr_name, fields),
    })
  }
}

///|
fn add_inline_form_rule(
  rules : Array[ProductionFormRule],
  fields : Array[ProductionField],
  inline : Bool,
) -> Unit {
  if inline {
    rules.push({
      origin: InlineForm,
      pattern: ListPattern(field_patterns_from_fields(fields)),
    })
  }
}

///|
fn add_infix_form_rule(
  rules : Array[ProductionFormRule],
  infix_operator : String?,
) -> Unit {
  match infix_operator {
    Some(operator) =>
      rules.push({
        origin: InfixForm,
        pattern: ListPattern([
          field_pattern_from_index(0),
          AtomPattern(operator),
          field_pattern_from_index(1),
        ]),
      })
    None => ()
  }
}

///|
fn surface_form_rules_from_metadata(
  constr_name : String,
  fields : Array[ProductionField],
  patterns : Array[FormPattern],
  canonical_policy : CanonicalPolicy,
  name_alias : String?,
  inline : Bool,
  infix_operator : String?,
) -> Array[ProductionFormRule] {
  let rules : Array[ProductionFormRule] = []
  add_declared_form_rules(rules, patterns)
  add_canonical_form_rules(
    rules, constr_name, fields, canonical_policy, name_alias,
  )
  add_inline_form_rule(rules, fields, inline)
  add_infix_form_rule(rules, infix_operator)
  rules
}

///|
fn production_def_from_constr(
  owner : String,
  c : @syntax.ConstrDecl,
) -> ProductionDef raise {
  let constr_name = c.name.name
  let fields = production_fields_from_constr(c)
  let patterns = form_patterns_from_attrs(c.attrs)
  let canonical_policy = canonical_policy_from_attrs(c.attrs)
  let hooks = hooks_from_attrs(owner, constr_name, c.attrs)
  let name_alias = name_alias_from_attrs(owner, constr_name, c.attrs)
  let inline = c.attrs.any(attr => is_nano_attr(attr, "inline"))
  let infix_operator = infix_operator_from_attrs(owner, constr_name, c.attrs)
  let contexts = contexts_from_attrs(c.attrs)
  {
    owner,
    constr_name,
    fields,
    patterns,
    surface_forms: surface_form_rules_from_metadata(
      constr_name, fields, patterns, canonical_policy, name_alias, inline, infix_operator,
    ),
    canonical_policy,
    hooks,
    name_alias,
    inline,
    infix_operator,
    contexts,
    source_constr: c,
  }
}
