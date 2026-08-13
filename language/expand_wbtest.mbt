///|
fn load_expand_group() -> ExpandedLanguageGroup raise {
  let langs = @meta_parser.find_languages_by_file("poc/lang_def.mbt")
  expand_language_group(langs, extra_known_types=["Type", "LambdaVar"])
}

///|
// Verifies inheritance + `#nano.remove`:
//   - `Lit` is inherited from the parent (not re-declared in the child) => shared
//   - `Add` is re-declared in the child (override) => shared
//   - `Mul` is new in the child => own
//   - `Neg` is removed via `#nano.remove("Neg")` => absent
test "expand applies #nano.remove and inherits undeclared constructors" {
  let langs = @meta_parser.find_languages_by_file(
    "language/fixtures/remove_lang.mbt",
  )
  let group = expand_language_group(langs)
  inspect(
    "[" +
    group.languages
    .map(l => {
      let cs = l.constructors
        .map(c => "\{c.constr.name.name}:\{origin_tag(c.origin)}")
        .join(", ")
      "\{l.name} -> [\{cs}]"
    })
    .join(", ") +
    "]",
    content=(
      #|[RemoveBase -> [Lit:shared, Add:shared, Neg:shared], RemoveChild -> [Lit:shared, Add:shared, Mul:own]]
    ),
  )
}

///|
fn origin_tag(o : ConstructorOrigin) -> String {
  match o {
    Shared => "shared"
    Own => "own"
  }
}

///|
fn entry_tag(e : @meta_parser.ResolvedEntry) -> String {
  let origin = match e.origin {
    DefaultEntry => "default"
    ExplicitEntry => "explicit"
    InheritedEntry(p) => "inherited(\{p})"
  }
  "\{e.target.name}<-\{origin}"
}

///|
// Records current expansion behavior:
//
// - Constructor origins: base language constructors are all `shared`; a derived
//   constructor whose name also exists in the base is `shared` (merged into the
//   tree), otherwise `own` (routed through the ext enum).
//
// - Entry: `SimplyTypedLambda` declares no explicit `#nano.entry`, so it inherits
//   the parent entry name `Expr` (kept reachable as an inherited nonterminal
//   position). This is the current meta_parser behavior; a later stage may
//   default a derived language to its own tycon (`TypedExpr`) instead.
test "expand records entry inheritance and constructor origins" {
  let group = load_expand_group()
  inspect(
    "[" +
    group.languages
    .map(l => "\{l.name}: entry=\{entry_tag(l.entry)}")
    .join(", ") +
    "]",
    content=(
      #|[Lambda: entry=Expr<-default, SimplyTypedLambda: entry=Expr<-inherited(Lambda)]
    ),
  )
  inspect(
    "[" +
    group.languages
    .map(l => {
      let cs = l.constructors
        .map(c => "\{c.constr.name.name}:\{origin_tag(c.origin)}")
        .join(", ")
      "\{l.name} -> [\{cs}]"
    })
    .join(", ") +
    "]",
    content=(
      #|[Lambda -> [Int:shared, LambdaVar:shared, Lam:shared, App:shared], SimplyTypedLambda -> [True:own, False:own, Int:shared, LambdaVar:shared, If:own, Lam:shared, App:shared]]
    ),
  )
}
