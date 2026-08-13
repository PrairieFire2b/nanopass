// Consistency lock between `layout` and `expand`.
//
// `layout.constructor_layouts` and `expand` independently decide whether a
// derived constructor is merged into the shared `Tree` (`TreeTarget` / `Shared`)
// or routed through the ext enum (`ExtTarget` / `Own`). This is intentional
// duplication: layout also needs field-reorder/padding info derived from the
// base constructor and the tree shape, which cannot live in `expand` without
// coupling `expand` to the tree layout.
//
// This test locks the shared invariant: for every language-wrapper constructor,
// the layout target kind must agree with the expand origin. If either side's
// classification drifts, this test fails.

///|
fn target_kind(t : @layout.ConstructorTarget) -> String {
  match t {
    RawTarget => "raw"
    TreeTarget => "tree"
    ExtTarget(_) => "ext"
  }
}

///|
fn expected_kind(o : ConstructorOrigin) -> String {
  match o {
    Shared => "tree"
    Own => "ext"
  }
}

///|
test "layout target kind agrees with expand origin" {
  let langs = @meta_parser.find_languages_by_file("poc/lang_def.mbt")
  let lang : Language = Language::from_file(
    name="Lambda",
    path="poc/lang_def.mbt",
    mod="YumeXi/nanocake",
  )
  let layout = lang.layout()
  let group = expand_language_group(langs, extra_known_types=[
    "Type", "LambdaVar",
  ])

  // Build (tycon.constr -> origin) from expand, restricted to language wrappers.
  let origin_of : Map[String, ConstructorOrigin] = Map([])
  group.languages.each(l => {
    l.constructors.each(c => {
      origin_of[l.def.type_decl.tycon + "." + c.constr.name.name] = c.origin
    })
  })

  // Every layout constructor that belongs to a language wrapper must match.
  let checked : Array[String] = []
  layout.constructors.each(cl => {
    let key = cl.source_tycon + "." + cl.constr_name
    match origin_of.get(key) {
      Some(origin) => {
        let got = target_kind(cl.target)
        let want = expected_kind(origin)
        if got != want {
          fail(
            "target/origin mismatch for \{key}: layout=\{got}, expand=\{want}",
          )
        }
        checked.push(key)
      }
      None =>
        // RawTarget external nonterminals (e.g. Type.*) are not language
        // wrappers; they have no expand origin. Assert they are indeed raw.
        if target_kind(cl.target) != "raw" {
          fail(
            "layout constructor \{key} has no expand origin but is not RawTarget",
          )
        }
    }
  })
  // Ensure we actually exercised the language-wrapper constructors.
  assert_true(checked.length() > 0)
}
