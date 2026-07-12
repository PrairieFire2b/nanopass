///|
/// Generate a `SyntaxKind` enum (backed by `UInt16`) for a language group.
///
/// Each Tree constructor and Ext enum constructor gets a unique variant.
/// The enum is generated as part of the pass infrastructure so that
/// `GreenStore` can reference kinds by a compact tag.
pub fn gen_syntax_kind(
  lang : @language.Language,
) -> @list.List[@syntax.Impl] raise {
  let tree_info = compute_tree_params(lang.group)
  let loc = lang.group[0].type_decl.loc
  let descs = collect_all_descriptors(lang, tree_info, loc)
  let enum_decl = build_syntax_kind_enum(descs, loc)
  @list.from_array([@syntax.TopTypeDef(enum_decl)])
}

///|
/// Collect unique descriptors from all constructors across the language group.
/// Deduplicates by field_name to avoid repeated shared constructors.
fn collect_all_descriptors(
  lang : @language.Language,
  tree_info : TreeInfo,
  loc : @basic.Location,
) -> Array[ConstrDescriptor] {
  let seen : Map[String, ConstrDescriptor] = {}
  lang.group.eachi(fn(i, nl) {
    let tycon = nl.type_decl.tycon
    let is_base = i == 0
    let ext_enum_name = match tree_info.ext_enum {
      Some(ee) => Some(ee.name)
      None => None
    }
    let descs = collect_descriptors(
      tree_info, tycon, is_base, ext_enum_name, loc,
    )
    descs.each(fn(d) {
      if seen.contains(d.field_name) {
        ()
      } else {
        seen[d.field_name] = d
      }
    })
  })
  let results : Array[ConstrDescriptor] = []
  seen.each(fn(_, d) { results.push(d) })
  results
}

///|
/// Build the SyntaxKind enum type declaration.
fn build_syntax_kind_enum(
  descs : Array[ConstrDescriptor],
  loc : @basic.Location,
) -> @syntax.TypeDecl {
  let variants : Array[@syntax.ConstrDecl] = []
  descs.each(fn(d) {
    let name = if d.is_ext {
      match d.ext_enum_name {
        Some(ext_name) => ext_name + "_" + d.name
        None => "Tree_" + d.name
      }
    } else {
      "Tree_" + d.name
    }
    variants.push({
      args: None,
      attrs: @list.empty(),
      doc: @syntax.DocString::empty(),
      loc,
      name: @syntax.ConstrName::{ name, loc },
      tag: None,
    })
  })
  {
    attrs: @list.empty(),
    components: @syntax.Variant(@list.from_array(variants[:])),
    deriving: @list.empty(),
    doc: @syntax.DocString::empty(),
    is_declare: false,
    loc,
    params: @list.empty(),
    tycon: "SyntaxKind",
    tycon_loc: loc,
    type_vis: @syntax.Visibility::Default,
  }
}
