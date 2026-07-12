///|
pub(all) enum ConstructorTarget {
  /// A plain enum constructor: the value is built directly with
  /// `Ty::Constr(...)`. Used for external nonterminals that are not merged
  /// into the shared `Tree` wrapper.
  RawTarget
  /// A constructor merged into the shared `Tree`: built as `Ty(Tree::Constr(...))`,
  /// with `field_order` describing how source fields map onto tree slots.
  TreeTarget
  /// A derived-only constructor routed through the per-language ext enum:
  /// built as `Ty(Tree::Ext(TyExt::Constr(...)))`.
  ExtTarget(String)
} derive(Debug, Eq)

///|
pub(all) struct ConstructorLayout {
  lang_name : String
  source_tycon : String
  constr_name : String
  source_constr : @syntax.ConstrDecl
  target : ConstructorTarget
  field_order : Array[Int]
  tree_extra_type : @syntax.Type?
  /// Surface-syntax rules (declared `#nano.form`, name alias, canonical, inline,
  /// infix), already normalized by `meta_parser`. Empty for external-nonterminal
  /// (`RawTarget`) constructors and for constructors with no declared syntax.
  surface_forms : Array[@meta_parser.ProductionFormRule]
  /// Constructor-level `#nano.parse_by` / `#nano.unparse_by` hook escape hatches.
  hooks : @meta_parser.NanoHooks
}

///|
pub(all) struct TreeConstructorLayout {
  constr_name : String
  field_types : Array[String]
}

///|
pub(all) struct TreeLayout {
  tycon : String
  params : Array[String]
  constructors : Array[TreeConstructorLayout]
  decl : @syntax.TypeDecl
}

///|
pub(all) struct WrapperLayout {
  lang_name : String
  tycon : String
  tree_args : Array[String]
  decl : @syntax.TypeDecl
}

///|
pub(all) struct ExtEnumLayout {
  lang_name : String
  tycon : String
  constructors : Array[String]
  decl : @syntax.TypeDecl
}

///|
pub(all) struct GeneratedLanguageLayout {
  group : Array[@meta_parser.NanoLangDef]
  tree : TreeLayout
  wrappers : Array[WrapperLayout]
  ext_enums : Array[ExtEnumLayout]
  constructors : Array[ConstructorLayout]
  external_types : Array[@mbti_ast.Sig]
}
