// Nanopass-style expansion of a language group.
//
// Given the raw `NanoLangDef` group (base first, derived following), produce an
// `ExpandedLanguageGroup` where:
//   - every language carries its resolved entry (explicit / inherited / default),
//   - every constructor is classified by its origin relative to the base
//     language: `Shared` (same constructor name exists in the base) or `Own`
//     (introduced by this derived language).
//
// This first stage implements additive/override semantics only: a derived
// constructor with the same name as a base constructor is treated as `Shared`;
// a derived-only constructor is `Own`. Explicit `+/-` add/remove syntax is a
// later stage.
//
// Production identity is `(owner tycon, constructor name)`.

///|
/// Where a constructor in an expanded language came from.
pub(all) enum ConstructorOrigin {
  /// The constructor name also exists in the base language (merged/overridden).
  Shared
  /// Introduced by this (derived) language only.
  Own
} derive(Eq, Debug)

///|
/// One constructor in an expanded language, tagged with its origin.
pub(all) struct ExpandedConstructor {
  owner : String
  constr : @syntax.ConstrDecl
  origin : ConstructorOrigin
}

///|
/// A single language after inheritance expansion.
pub(all) struct ExpandedLanguage {
  name : String
  extends : String?
  entry : @meta_parser.ResolvedEntry
  constructors : Array[ExpandedConstructor]
  def : @meta_parser.NanoLangDef
}

///|
/// A whole language group after expansion. `languages[0]` is the base.
pub(all) struct ExpandedLanguageGroup {
  languages : Array[ExpandedLanguage]
}

///|
/// The constructor names declared directly in a language's enum body.
fn declared_constr_names(
  lang : @meta_parser.NanoLangDef,
) -> Array[String] {
  let names : Array[String] = []
  match lang.type_decl.components {
    @syntax.Variant(cs) => cs.each(c => names.push(c.name.name))
    _ => ()
  }
  names
}

///|
/// The constructors declared directly in a language's enum body.
fn declared_constrs(
  lang : @meta_parser.NanoLangDef,
) -> Array[@syntax.ConstrDecl] {
  let cs : Array[@syntax.ConstrDecl] = []
  match lang.type_decl.components {
    @syntax.Variant(vs) => vs.each(c => cs.push(c))
    _ => ()
  }
  cs
}

///|
/// Rewrite a constructor's field types, replacing references to `from` with
/// `to`. Used when an inherited constructor (whose self-references point at the
/// parent tycon) is pulled into a deriving language with a different tycon:
/// e.g. inheriting `Add(Expr, Expr)` into `Expr2` yields `Add(Expr2, Expr2)`.
fn retarget_constr(
  c : @syntax.ConstrDecl,
  from : String,
  to : String,
  loc : @basic.Location,
) -> @syntax.ConstrDecl {
  let new_args = match c.args {
    Some(args) => {
      let params : Array[@syntax.ConstrParam] = []
      args.each(p => {
        let new_ty = if field_type_name(p.ty) == from {
          @syntax.Name(
            constr_id={ id: @syntax.LongIdent::Ident(name=to), loc },
            tys=@list.empty(),
            loc~,
          )
        } else {
          p.ty
        }
        params.push({ ..p, ty: new_ty })
      })
      Some(@list.List(params[:]))
    }
    None => None
  }
  { ..c, args: new_args }
}

///|
fn field_type_name(ty : @syntax.Type) -> String {
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
/// Expand the base language: every constructor is `Shared`.
fn expand_base(lang : @meta_parser.NanoLangDef) -> ExpandedLanguage raise {
  let entry = match lang.resolved_entry {
    Some(e) => e
    None => raise NoLanguageFound
  }
  let constructors = declared_constrs(lang).map(c => {
    { owner: lang.type_decl.tycon, constr: c, origin: Shared }
  })
  { name: lang.name, extends: lang.extends, entry, constructors, def: lang }
}

///|
/// Expand a derived language against its already-expanded parent:
///   final constructors = parent constructors
///                        - `#nano.remove(...)`
///                        + this language's own declarations (override by name).
/// Constructors inherited (not re-declared) keep flowing through; a re-declared
/// same-name constructor is `Shared`; a brand new one is `Own`.
fn expand_derived(
  lang : @meta_parser.NanoLangDef,
  parent : ExpandedLanguage,
) -> ExpandedLanguage raise {
  let entry = match lang.resolved_entry {
    Some(e) => e
    None => raise NoLanguageFound
  }
  let tycon = lang.type_decl.tycon
  let own = declared_constrs(lang)
  let own_names = declared_constr_names(lang)
  let removed = lang.removed
  let parent_names = parent.constructors.map(c => c.constr.name.name)
  let constructors : Array[ExpandedConstructor] = []

  // Inherited constructors: keep parent's, unless removed or overridden here.
  // Retarget parent self-references to this language's tycon so the inherited
  // constructor is well-typed here (e.g. `Add(Expr, Expr)` -> `Add(Expr2, Expr2)`).
  let loc = lang.type_decl.loc
  parent.constructors.each(pc => {
    let name = pc.constr.name.name
    if !removed.contains(name) && !own_names.contains(name) {
      let retargeted = retarget_constr(pc.constr, pc.owner, tycon, loc)
      constructors.push({ owner: tycon, constr: retargeted, origin: Shared })
    }
  })
  // Own constructors: same name as parent => Shared (override), else Own.
  own.each(c => {
    let origin = if parent_names.contains(c.name.name) { Shared } else { Own }
    constructors.push({ owner: tycon, constr: c, origin })
  })
  { name: lang.name, extends: lang.extends, entry, constructors, def: lang }
}

///|
/// Expand a raw language group into an `ExpandedLanguageGroup`.
///
/// The input is normalized first (so entries are resolved and definitions are
/// validated). Languages are kept in source order with the base first.
/// Derived languages inherit their parent's constructors; `#nano.remove(...)`
/// drops inherited constructors and same-name declarations override.
pub fn expand_language_group(
  raw : Array[@meta_parser.NanoLangDef],
  extra_known_types~ : Array[String] = [],
) -> ExpandedLanguageGroup raise {
  if raw.length() == 0 {
    raise NoLanguageFound
  }
  // If the group is already normalized (entries resolved), reuse it as-is;
  // otherwise normalize now. This avoids re-running field-type checks with a
  // different set of known types than the original load used.
  let already_resolved = raw.iter().all(l => l.resolved_entry is Some(_))
  let normalized = if already_resolved {
    raw
  } else {
    @meta_parser.normalize_language_defs(raw, extra_known_types~)
  }
  let languages : Array[ExpandedLanguage] = []
  normalized.eachi((i, lang) => {
    let expanded = if i == 0 {
      expand_base(lang)
    } else {
      let parent = match lang.extends {
        Some(pname) => find_expanded(languages, pname)
        None => None
      }
      match parent {
        Some(p) => expand_derived(lang, p)
        None => expand_base(lang) // no parent in group: treat as standalone
      }
    }
    languages.push(expanded)
  })
  { languages, }
}

///|
fn find_expanded(
  langs : Array[ExpandedLanguage],
  name : String,
) -> ExpandedLanguage? {
  for i in 0..<langs.length() {
    if langs[i].name == name {
      return Some(langs[i])
    }
  }
  None
}

///|
/// Expand this `Language`'s group.
pub fn Language::expand(self : Language) -> ExpandedLanguageGroup raise {
  expand_language_group(self.group)
}
