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
/// Metadata-independent constructor fields shared by all metadata frontends.
priv struct ProductionMetadata {
  patterns : Array[FormPattern]
  canonical_policy : CanonicalPolicy
  hooks : NanoHooks
  name_alias : String?
  inline : Bool
  infix_operator : String?
  contexts : Array[String]
}

///|
fn production_def_from_metadata(
  owner : String,
  c : @syntax.ConstrDecl,
  metadata : ProductionMetadata,
) -> ProductionDef {
  let constr_name = c.name.name
  let fields = production_fields_from_constr(c)
  {
    owner,
    constr_name,
    fields,
    patterns: metadata.patterns,
    surface_forms: surface_form_rules_from_metadata(
      constr_name,
      fields,
      metadata.patterns,
      metadata.canonical_policy,
      metadata.name_alias,
      metadata.inline,
      metadata.infix_operator,
    ),
    canonical_policy: metadata.canonical_policy,
    hooks: metadata.hooks,
    name_alias: metadata.name_alias,
    inline: metadata.inline,
    infix_operator: metadata.infix_operator,
    contexts: metadata.contexts,
    source_constr: c,
  }
}

///|
fn production_metadata_from_def(def : ProductionDef) -> ProductionMetadata {
  {
    patterns: def.patterns,
    canonical_policy: def.canonical_policy,
    hooks: def.hooks,
    name_alias: def.name_alias,
    inline: def.inline,
    infix_operator: def.infix_operator,
    contexts: def.contexts,
  }
}

///|
/// Rebind a production's source constructor while preserving its metadata.
pub fn ProductionDef::with_constructor(
  self : ProductionDef,
  c : @syntax.ConstrDecl,
) -> ProductionDef {
  production_def_from_metadata(
    self.owner,
    c,
    production_metadata_from_def(self),
  )
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
  production_def_from_metadata(owner, c, {
    patterns: form_patterns_from_attrs(c.attrs),
    canonical_policy: canonical_policy_from_attrs(c.attrs),
    hooks: hooks_from_attrs(owner, constr_name, c.attrs),
    name_alias: name_alias_from_attrs(owner, constr_name, c.attrs),
    inline: c.attrs.any(attr => is_nano_attr(attr, "inline")),
    infix_operator: infix_operator_from_attrs(owner, constr_name, c.attrs),
    contexts: contexts_from_attrs(c.attrs),
  })
}
