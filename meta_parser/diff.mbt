///|
fn type_name(ty : @syntax.Type) -> String {
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
fn constr_eq(a : @syntax.ConstrDecl, b : @syntax.ConstrDecl) -> Bool {
  if a.name.name != b.name.name {
    return false
  }
  match (a.args, b.args) {
    (None, None) => true
    (Some(a_args), Some(b_args)) => {
      if a_args.length() != b_args.length() {
        return false
      }
      let a_names : Array[String] = []
      let b_names : Array[String] = []
      a_args.each(fn(p) { a_names.push(type_name(p.ty)) })
      b_args.each(fn(p) { b_names.push(type_name(p.ty)) })
      if a_names.length() != b_names.length() {
        return false
      }
      for i in 0..<a_names.length() {
        if a_names[i] != b_names[i] {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn nt_name(nt : NonTerminal) -> String {
  match nt {
    Constructor(c) => c.name.name
    TypeDecl(td) => td.tycon
  }
}

///|
fn nt_eq(a : NonTerminal, b : NonTerminal) -> Bool {
  match (a, b) {
    (Constructor(c1), Constructor(c2)) => constr_eq(c1, c2)
    (TypeDecl(td1), TypeDecl(td2)) => td1.tycon == td2.tycon
    _ => false
  }
}

///|
fn t_name(t : Terminal) -> String {
  let Terminal(c) = t
  c.name.name
}

///|
fn t_eq(a : Terminal, b : Terminal) -> Bool {
  let Terminal(c1) = a
  let Terminal(c2) = b
  constr_eq(c1, c2)
}

///|
fn find_nt_by_name(nts : Array[NonTerminal], name : String) -> NonTerminal? {
  for i in 0..<nts.length() {
    if nt_name(nts[i]) == name {
      return Some(nts[i])
    }
  }
  None
}

///|
fn find_t_by_name(ts : Array[Terminal], name : String) -> Terminal? {
  for i in 0..<ts.length() {
    if t_name(ts[i]) == name {
      return Some(ts[i])
    }
  }
  None
}

///|
pub fn NanoLangDef::diff(self : NanoLangDef, other : NanoLangDef) -> Diff {
  let self_nt_names : Array[String] = self.nonterminals.map(nt_name)
  let other_nt_names : Array[String] = other.nonterminals.map(nt_name)

  let added_nonterminals : Array[NonTerminal] = []
  let removed_nonterminals : Array[NonTerminal] = []
  let changed_nonterminals : Array[ModifiedNonTerminal] = []

  self.nonterminals.each(fn(nt) {
    let name = nt_name(nt)
    if other_nt_names.contains(name) {
      match find_nt_by_name(other.nonterminals, name) {
        Some(other_nt) =>
          if !nt_eq(nt, other_nt) {
            changed_nonterminals.push({ origin: nt, modified: other_nt })
          }
        None => ()
      }
    } else {
      removed_nonterminals.push(nt)
    }
  })
  other.nonterminals.each(fn(nt) {
    if !self_nt_names.contains(nt_name(nt)) {
      added_nonterminals.push(nt)
    }
  })

  let self_t_names : Array[String] = self.terminals.map(t_name)
  let other_t_names : Array[String] = other.terminals.map(t_name)

  let added_terminals : Array[Terminal] = []
  let removed_terminals : Array[Terminal] = []
  let changed_terminals : Array[ModifiedTerminal] = []

  self.terminals.each(fn(t) {
    let name = t_name(t)
    if other_t_names.contains(name) {
      match find_t_by_name(other.terminals, name) {
        Some(other_t) =>
          if !t_eq(t, other_t) {
            changed_terminals.push({ origin: t, modified: other_t })
          }
        None => ()
      }
    } else {
      removed_terminals.push(t)
    }
  })
  other.terminals.each(fn(t) {
    if !self_t_names.contains(t_name(t)) {
      added_terminals.push(t)
    }
  })

  {
    origin: self,
    deriv: other,
    added_nonterminals,
    removed_nonterminals,
    changed_nonterminals,
    added_terminals,
    removed_terminals,
    changed_terminals,
  }
}

///|
fn format_constr(c : @syntax.ConstrDecl) -> String {
  let name = c.name.name
  match c.args {
    Some(args) => {
      let params = StringBuilder::new()
      args.eachi(fn(i, p) {
        if i > 0 {
          params.write_string(", ")
        }
        match p.ty {
          @syntax.Name(constr_id~, ..) =>
            match constr_id.id {
              @syntax.Ident(name~) => params.write_string(name)
              @syntax.Dot(id~, ..) => params.write_string(id)
            }
          _ => params.write_string("_")
        }
      })
      "\{name}(\{params.to_string()})"
    }
    None => name
  }
}

///|
fn format_nt(nt : NonTerminal) -> String {
  match nt {
    Constructor(c) => format_constr(c)
    TypeDecl(td) => td.tycon
  }
}

///|
fn format_t(t : Terminal) -> String {
  let Terminal(c) = t
  format_constr(c)
}

///|
fn write_line(sb : StringBuilder, prefix : String, body : String) -> Unit {
  sb.write_string(prefix)
  sb.write_string(body)
  sb.write_string("\n")
}

///|
pub impl Show for Diff with fn output(self, logger : &Logger) -> Unit {
  let tycon = self.deriv.type_decl.tycon
  let changed_nt_orig_names : Array[String] = self.changed_nonterminals.map(fn(
    c,
  ) {
    nt_name(c.origin)
  })
  let changed_t_orig_names : Array[String] = self.changed_terminals.map(fn(c) {
    t_name(c.origin)
  })
  let removed_nt_names : Array[String] = self.removed_nonterminals.map(nt_name)
  let removed_t_names : Array[String] = self.removed_terminals.map(t_name)

  let sb = StringBuilder::new()
  sb.write_string("enum ")
  sb.write_string(tycon)
  sb.write_string(" {\n")

  // ==== terminals ====
  // unchanged
  self.origin.terminals.each(fn(t) {
    let name = t_name(t)
    if !removed_t_names.contains(name) && !changed_t_orig_names.contains(name) {
      write_line(sb, "  ", format_t(t))
    }
  })
  // changed
  self.changed_terminals.each(fn(c) {
    write_line(sb, "- ", format_t(c.origin))
    write_line(sb, "+ ", format_t(c.modified))
  })
  // added
  self.added_terminals.each(fn(t) { write_line(sb, "+ ", format_t(t)) })
  // removed
  self.removed_terminals.each(fn(t) { write_line(sb, "- ", format_t(t)) })

  // ==== nonterminals ====
  // unchanged
  self.origin.nonterminals.each(fn(nt) {
    let name = nt_name(nt)
    if !removed_nt_names.contains(name) && !changed_nt_orig_names.contains(name) {
      write_line(sb, "  ", format_nt(nt))
    }
  })
  // changed
  self.changed_nonterminals.each(fn(c) {
    write_line(sb, "- ", format_nt(c.origin))
    write_line(sb, "+ ", format_nt(c.modified))
  })
  // added
  self.added_nonterminals.each(fn(nt) { write_line(sb, "+ ", format_nt(nt)) })
  // removed
  self.removed_nonterminals.each(fn(nt) { write_line(sb, "- ", format_nt(nt)) })

  sb.write_string("}")
  logger.write_string(sb.to_string())
}

///|
test {
  let langs = find_languages_by_file("poc/lang_def.mbt")
  inspect(langs.length(), content="2")
  @debug.debug_inspect(
    langs[0].diff(langs[1]),
    content=(
      #|{
      #|  origin: "Lambda",
      #|  deriv: "SimplyTypedLambda",
      #|  added_nonterminals: [TypeDecl("Type"), Constructor(If(TypedExpr, TypedExpr, TypedExpr))],
      #|  removed_nonterminals: [],
      #|  changed_nonterminals: [
      #|    {
      #|      origin: Constructor(Lam(Var, Expr)),
      #|      modified: Constructor(Lam(Var, Type, TypedExpr)),
      #|    },
      #|    {
      #|      origin: Constructor(App(Expr, Expr)),
      #|      modified: Constructor(App(TypedExpr, TypedExpr)),
      #|    },
      #|  ],
      #|  added_terminals: [True, False],
      #|  removed_terminals: [],
      #|  changed_terminals: [],
      #|}
    ),
  )
  inspect(
    langs[0].diff(langs[1]),
    content=(
      #|enum TypedExpr {
      #|  Int(Int)
      #|  Var(Var)
      #|+ True
      #|+ False
      #|- Lam(Var, Expr)
      #|+ Lam(Var, Type, TypedExpr)
      #|- App(Expr, Expr)
      #|+ App(TypedExpr, TypedExpr)
      #|+ Type
      #|+ If(TypedExpr, TypedExpr, TypedExpr)
      #|}
    ),
  )
  langs[0].diff(langs[1]) |> println
}
