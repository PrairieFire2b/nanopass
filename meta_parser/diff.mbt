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
fn normalize(
  name : String,
  origin_tycon : String,
  deriv_tycon : String,
) -> String {
  if name == origin_tycon {
    deriv_tycon
  } else {
    name
  }
}

///|
fn constr_eq(
  a : @syntax.ConstrDecl,
  b : @syntax.ConstrDecl,
  origin_tycon : String,
  deriv_tycon : String,
) -> Bool {
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
      a_args.each(fn(p) {
        a_names.push(normalize(type_name(p.ty), origin_tycon, deriv_tycon))
      })
      b_args.each(fn(p) {
        b_names.push(normalize(type_name(p.ty), origin_tycon, deriv_tycon))
      })
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
fn nt_eq(
  a : NonTerminal,
  b : NonTerminal,
  origin_tycon : String,
  deriv_tycon : String,
) -> Bool {
  match (a, b) {
    (Constructor(c1), Constructor(c2)) =>
      constr_eq(c1, c2, origin_tycon, deriv_tycon)
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
fn t_eq(
  a : Terminal,
  b : Terminal,
  origin_tycon : String,
  deriv_tycon : String,
) -> Bool {
  let Terminal(c1) = a
  let Terminal(c2) = b
  constr_eq(c1, c2, origin_tycon, deriv_tycon)
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
/// Compare two language definitions and return a structured `Diff`
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
          if !nt_eq(nt, other_nt, self.type_decl.tycon, other.type_decl.tycon) {
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
          if !t_eq(t, other_t, self.type_decl.tycon, other.type_decl.tycon) {
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
    TypeDecl(td) => format_typedecl(td)
  }
}

///|
fn format_typedecl(td : @syntax.TypeDecl) -> String {
  match td.components {
    @syntax.Variant(constrs) => {
      let parts = StringBuilder::new()
      constrs.eachi(fn(i, c) {
        if i > 0 {
          parts.write_string(", ")
        }
        parts.write_string(format_constr(c))
      })
      let body = parts.to_string()
      "\{td.tycon} { \{body} }"
    }
    _ => td.tycon
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
  let changed_t_mod_names : Array[String] = self.changed_terminals.map(fn(c) {
    t_name(c.modified)
  })
  let changed_nt_mod_names : Array[String] = self.changed_nonterminals.map(fn(
    c,
  ) {
    nt_name(c.modified)
  })
  let added_t_names : Array[String] = self.added_terminals.map(t_name)
  let added_nt_names : Array[String] = self.added_nonterminals.map(nt_name)
  let sb = StringBuilder::new()
  sb.write_string("enum ")
  sb.write_string(tycon)
  sb.write_string(" {\n")

  // ==== terminals ====
  // unchanged (from deriv, not added and not changed)
  self.deriv.terminals.each(fn(t) {
    let name = t_name(t)
    if !added_t_names.contains(name) && !changed_t_mod_names.contains(name) {
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

  // ==== nonterminals (Constructor only, inside enum) ====
  // unchanged
  self.deriv.nonterminals.each(fn(nt) {
    let name = nt_name(nt)
    if !added_nt_names.contains(name) && !changed_nt_mod_names.contains(name) {
      match nt {
        Constructor(_) => write_line(sb, "  ", format_nt(nt))
        _ => ()
      }
    }
  })
  // changed
  self.changed_nonterminals.each(fn(c) {
    match c.origin {
      Constructor(_) => {
        write_line(sb, "- ", format_nt(c.origin))
        write_line(sb, "+ ", format_nt(c.modified))
      }
      _ => ()
    }
  })
  // added
  self.added_nonterminals.each(fn(nt) {
    match nt {
      Constructor(_) => write_line(sb, "+ ", format_nt(nt))
      _ => ()
    }
  })
  // removed
  self.removed_nonterminals.each(fn(nt) {
    match nt {
      Constructor(_) => write_line(sb, "- ", format_nt(nt))
      _ => ()
    }
  })

  sb.write_string("}")

  // ==== external TypeDecl nonterminals ====
  let td_unchanged = self.deriv.nonterminals.filter(fn(nt) {
    let name = nt_name(nt)
    if !added_nt_names.contains(name) && !changed_nt_mod_names.contains(name) {
      match nt {
        TypeDecl(_) => true
        _ => false
      }
    } else {
      false
    }
  })
  let td_added = self.added_nonterminals.filter(fn(nt) {
    match nt {
      TypeDecl(_) => true
      _ => false
    }
  })
  let td_removed = self.removed_nonterminals.filter(fn(nt) {
    match nt {
      TypeDecl(_) => true
      _ => false
    }
  })
  if td_unchanged.length() + td_added.length() + td_removed.length() > 0 {
    sb.write_string("\n")
    td_unchanged.each(fn(nt) { write_line(sb, "  ", format_nt(nt)) })
    td_added.each(fn(nt) { write_line(sb, "+ ", format_nt(nt)) })
    td_removed.each(fn(nt) { write_line(sb, "- ", format_nt(nt)) })
  }
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
      #|  origin: {
      #|    name: "Lambda",
      #|    extends: None,
      #|    nonterminals: [Constructor(Lam(Var, Expr)), Constructor(App(Expr, Expr))],
      #|    terminals: [Int(Int), Var(Var)],
      #|    tycon: "Expr",
      #|  },
      #|  deriv: {
      #|    name: "SimplyTypedLambda",
      #|    extends: Some("Lambda"),
      #|    nonterminals: [
      #|      TypeDecl("Type"),
      #|      Constructor(If(TypedExpr, TypedExpr, TypedExpr)),
      #|      Constructor(Lam(Var, Type, TypedExpr)),
      #|      Constructor(App(TypedExpr, TypedExpr)),
      #|    ],
      #|    terminals: [True, False, Int(Int), Var(Var)],
      #|    tycon: "TypedExpr",
      #|  },
      #|  added_nonterminals: [TypeDecl("Type"), Constructor(If(TypedExpr, TypedExpr, TypedExpr))],
      #|  removed_nonterminals: [],
      #|  changed_nonterminals: [
      #|    {
      #|      origin: Constructor(Lam(Var, Expr)),
      #|      modified: Constructor(Lam(Var, Type, TypedExpr)),
      #|    },
      #|  ],
      #|  added_terminals: [True, False],
      #|  removed_terminals: [],
      #|  changed_terminals: [],
      #|}
    ),
  )
  inspect(
    langs[0].diff(langs[1]).to_string(),
    content=(
      #|enum TypedExpr {
      #|  Int(Int)
      #|  Var(Var)
      #|+ True
      #|+ False
      #|  App(TypedExpr, TypedExpr)
      #|- Lam(Var, Expr)
      #|+ Lam(Var, Type, TypedExpr)
      #|+ If(TypedExpr, TypedExpr, TypedExpr)
      #|}
      #|+ Type { Bool, Int, Arrow(Type, Type) }
      #|
    ),
  )
}
