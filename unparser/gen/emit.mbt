// Emit the four codec functions per type from the shared layout.

///|
/// Build the `Ty::from_sexp` body: an atom branch (zero-arg keywords and
/// single-field scalar atoms tried in source order) and a list branch (head
/// keyword dispatch).
fn gen_from_sexp(
  types : Array[TypeCodegen],
  tc : TypeCodegen,
  tree : @layout.TreeLayout,
) -> String {
  let sb = StringBuilder::new()
  let tycon = tc.tycon

  // `from_sexp` first tries constructor-level `#nano.parse_by` hooks in source
  // order: `Some(v)` wins, `None` falls through, a raised error becomes a stable
  // `HookError`. It then delegates to `from_sexp_without_hooks`, which hooks may
  // also call for safe fallback without re-entering the hook layer.
  sb.write_string("///|\n")
  sb.write_string(
    "pub fn \{tycon}::from_sexp(sexp : @sexp.Sexp) -> \{tycon} raise @sexp.SexpError {\n",
  )
  for cl in tc.constructors {
    match cl.hooks.parse_by {
      Some(hook) => {
        let path = constructor_path(tycon, cl.constr_name)
        sb.write_string("  match (\{hook}(sexp) catch {\n")
        sb.write_string(
          "    _ => @sexp.hook_error(path=\{str_lit(path)}, hook=\{str_lit(hook)}, message=\"parse hook failed\")\n",
        )
        sb.write_string("  }) {\n")
        sb.write_string("    Some(value) => return value\n")
        sb.write_string("    None => ()\n")
        sb.write_string("  }\n")
      }
      None => ()
    }
  }
  sb.write_string("  \{tycon}::from_sexp_without_hooks(sexp)\n")
  sb.write_string("}\n\n")

  // `from_sexp_without_hooks`: declarative surface forms then canonical
  // atom/list handling, with no `parse_by` hooks. Safe for hooks to call as a
  // fallback without infinite recursion.
  sb.write_string("///|\n")
  sb.write_string(
    "pub fn \{tycon}::from_sexp_without_hooks(sexp : @sexp.Sexp) -> \{tycon} raise @sexp.SexpError {\n",
  )

  // Surface forms (declared/inline/infix/name) are tried first, before the
  // canonical atom/list handling below. Each is matched via the sexp runtime's
  // `match_form`; on success the captured fields build the value.
  for cl in tc.constructors {
    let patterns = parse_form_patterns(cl)
    if patterns.length() > 0 {
      let args = constr_args(cl.source_constr)
      for pat in patterns {
        sb.write_string(
          "  match @sexp.match_form(sexp, \{str_lit(pat)}, \{args.length()}, path=\{str_lit(constructor_path(tycon, cl.constr_name))}) {\n",
        )
        sb.write_string("    Some(fields) => {\n")
        let exprs : Array[String] = []
        args.eachi((i, p) => {
          let ty = field_type_name(p.ty)
          let path = "\{constructor_path(tycon, cl.constr_name)}[\{i}]"
          exprs.push(parse_field(types, ty, "fields[\{i}]", path))
        })
        sb.write_string("      return \{construct(cl, tree, exprs, "()")}\n")
        sb.write_string("    }\n")
        sb.write_string("    None => ()\n")
        sb.write_string("  }\n")
      }
    }
  }
  sb.write_string("  match @sexp.atom_text(sexp) {\n")

  // Atom branch: zero-arg keyword constructors match by name.
  sb.write_string("    Some(atom) => {\n")
  for cl in tc.constructors {
    if constr_args(cl.source_constr).length() == 0 {
      sb.write_string(
        "      if atom == \{str_lit(cl.constr_name)} {\n        return \{construct(cl, tree, [], "()")}\n      }\n",
      )
    }
  }
  // Single-field scalar atom constructors: try typed parse in source order.
  let single_atom = tc.constructors.filter(cl => {
    constr_args(cl.source_constr).length() == 1
  })
  for cl in single_atom {
    let arg = constr_args(cl.source_constr)[0]
    let ty = field_type_name(arg.ty)
    if !is_codec_type(types, ty) {
      let parse = parse_field(
        types,
        ty,
        "sexp",
        constructor_path(tycon, cl.constr_name),
      )
      sb.write_string("      try {\n")
      sb.write_string("        let v = \{parse}\n")
      sb.write_string("        return \{construct(cl, tree, ["v"], "()")}\n")
      sb.write_string("      } catch {\n        _ => ()\n      }\n")
    }
  }
  sb.write_string(
    "      @sexp.decode_error(path=\{str_lit(tycon)}, message=\"no atom constructor matched: \" + atom)\n",
  )
  sb.write_string("    }\n")

  // List branch: `(Head field0 field1 ...)`.
  sb.write_string("    None => {\n")
  sb.write_string(
    "      let items = @sexp.expect_list(sexp, path=\{str_lit(tycon)})\n",
  )
  sb.write_string("      guard items.length() > 0 else {\n")
  sb.write_string(
    "        @sexp.decode_error(path=\{str_lit(tycon)}, message=\"empty list\")\n",
  )
  sb.write_string("      }\n")
  sb.write_string(
    "      let head = @sexp.expect_atom(items[0], path=\{str_lit(tycon + ".head")})\n",
  )
  sb.write_string("      match head {\n")
  for cl in tc.constructors {
    if is_list_constructor(cl) {
      let args = constr_args(cl.source_constr)
      sb.write_string("        \{str_lit(cl.constr_name)} => {\n")
      sb.write_string(
        "          @sexp.expect_arity(items, \{args.length() + 1}, path=\{str_lit(constructor_path(tycon, cl.constr_name))})\n",
      )
      let exprs : Array[String] = []
      args.eachi((i, p) => {
        let ty = field_type_name(p.ty)
        let path = "\{constructor_path(tycon, cl.constr_name)}[\{i}]"
        exprs.push(parse_field(types, ty, "items[\{i + 1}]", path))
      })
      sb.write_string("          \{construct(cl, tree, exprs, "()")}\n")
      sb.write_string("        }\n")
    }
  }
  sb.write_string(
    "        _ => @sexp.unknown_head(head, path=\{str_lit(tycon)})\n",
  )
  sb.write_string("      }\n")
  sb.write_string("    }\n")
  sb.write_string("  }\n")
  sb.write_string("}\n\n")
  sb.to_string()
}

///|
/// Build `Ty::to_sexp_doc`: match each constructor's stored (tree/ext/raw)
/// shape and render its surface form.
fn gen_to_sexp_doc(
  types : Array[TypeCodegen],
  tc : TypeCodegen,
  tree : @layout.TreeLayout,
) -> String {
  let sb = StringBuilder::new()
  let tycon = tc.tycon
  sb.write_string("///|\n")
  sb.write_string(
    "pub fn \{tycon}::to_sexp_doc(self : \{tycon}) -> @sexp.SexpDoc raise @sexp.SexpError {\n",
  )
  sb.write_string("  match self {\n")
  for cl in tc.constructors {
    let pattern = destructure(cl, tree)
    let names = field_names(cl.source_constr)
    let args = constr_args(cl.source_constr)
    // Constructor-level `#nano.unparse_by` takes priority over declarative
    // forms: the hook renders the whole constructor. A raised error is wrapped
    // as a stable `HookError`.
    match cl.hooks.unparse_by {
      Some(hook) => {
        let path = constructor_path(tycon, cl.constr_name)
        // Bind the whole matched value so the hook receives the wrapper value.
        sb.write_string(
          "    \{pattern} as bound => \{hook}(bound) catch {\n      _ => @sexp.hook_error(path=\{str_lit(path)}, hook=\{str_lit(hook)}, message=\"unparse hook failed\")\n    }\n",
        )
      }
      None =>
        match unparse_form_pattern(cl) {
          // A custom surface form renders via the sexp runtime's `form_doc`, with
          // each source field rendered to a doc first.
          Some(form) => {
            let field_docs : Array[String] = []
            args.eachi((i, p) => {
              let ty = field_type_name(p.ty)
              field_docs.push(doc_field(types, ty, names[i]))
            })
            let path = constructor_path(tycon, cl.constr_name)
            sb.write_string(
              "    \{pattern} => @sexp.form_doc(\{str_lit(form)}, [\{field_docs.join(", ")}], path=\{str_lit(path)})\n",
            )
          }
          None =>
            if args.length() == 0 {
              sb.write_string(
                "    \{pattern} => @sexp.atom_doc(\{str_lit(cl.constr_name)})\n",
              )
            } else if args.length() == 1 {
              let ty = field_type_name(args[0].ty)
              sb.write_string(
                "    \{pattern} => \{doc_field(types, ty, names[0])}\n",
              )
            } else {
              let parts : Array[String] = [
                "@sexp.atom_doc(\{str_lit(cl.constr_name)})",
              ]
              args.eachi((i, p) => {
                let ty = field_type_name(p.ty)
                parts.push(doc_field(types, ty, names[i]))
              })
              sb.write_string(
                "    \{pattern} => @sexp.list_doc([\{parts.join(", ")}])\n",
              )
            }
        }
    }
  }
  // A language wrapper stores a `Tree`, whose `Ext` variant is always present
  // in the type even when this language leaves it as `Unit` (base language).
  // Such an inhabitant is unreachable at runtime but the match must be total.
  if wraps_tree(tc) {
    sb.write_string(
      "    _ => @sexp.decode_error(path=\{str_lit(tycon)}, message=\"unreachable tree ext\")\n",
    )
  }
  sb.write_string("  }\n")
  sb.write_string("}\n\n")
  sb.to_string()
}

///|
/// Does this type store a shared `Tree` (i.e. has any Tree/Ext constructor)?
fn wraps_tree(tc : TypeCodegen) -> Bool {
  tc.constructors.any(cl => {
    match cl.target {
      RawTarget => false
      _ => true
    }
  })
}

///|
/// The thin `parse_sexp` / `unparse_sexp` string entry points.
fn gen_string_entries(tycon : String) -> String {
  [
    "///|",
    "pub fn \{tycon}::parse_sexp(input : StringView) -> \{tycon} raise @sexp.SexpError {",
    "  \{tycon}::from_sexp(@sexp.parse(input))",
    "}",
    "",
    "///|",
    "pub fn \{tycon}::unparse_sexp(self : \{tycon}, width? : Int) -> String raise @sexp.SexpError {",
    "  @sexp.render(\{tycon}::to_sexp_doc(self), width?)",
    "}",
    "",
    "",
  ].join("\n")
}
