///|
pub(all) enum ConstructorTarget {
  TreeTarget
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
