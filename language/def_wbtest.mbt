///|
let a : Array[@meta_parser.NanoLangDef] = @meta_parser.find_languages_by_file(
  "poc/lang_def.mbt",
) catch {
  _ => panic()
}

///|
let tree_def : (@syntax.TypeDecl, Array[@syntax.TypeDecl]) = gen_tree_def(a) catch {
  _ => panic()
}

///|
test {
  let (tree, ext_enums) = tree_def

  let poc_repr = @meta_parser.SourceLocRepr::for_pkg(
    pkg="poc",
    mod="YumeXi/nanopass",
  )
  let ext = find_external_types(a, tree, @meta_parser.resolve_mbti(poc_repr))
  debug_inspect(
    ext.map(fn(sig) {
      match sig {
        Type(type_sig) => type_sig.name.name
        Alias(alias_sig) =>
          match alias_sig {
            TypeAlias(name~, ..) => name.name
            _ => "?"
          }
        _ => "?"
      }
    }),
    content=(
      #|["Var", "Type"]
    ),
  )

  let impls = @list.from_array(
    [@syntax.TopTypeDef(tree)] + ext_enums.map(fn(e) { @syntax.TopTypeDef(e) }),
  )
  inspect(
    @fmt.impls_to_string(impls),
    content=(
      #|///|
      #|enum Tree[LamE, TreeExt] {
      #|  /// Terminals
      #|  Int(Int)
      #|  Var(Var)
      #|  /// Nonterminals
      #|  Lam(Var, Self_, LamE)
      #|  App(Self_, Self_)
      #|  Ext(TreeExt)
      #|}
      #|
      #|///|
      #|enum TypedExprExt {
      #|  /// Terminals
      #|  True
      #|  False
      #|  /// Nonterminals
      #|  If(cond~ : Self_, Self_, Self_)
      #|}
      #|
      #|
    ),
  )
}

///|
test "sig_to_impl" {
  let (tree, _) = tree_def
  let poc_repr = @meta_parser.SourceLocRepr::for_pkg(
    pkg="poc",
    mod="YumeXi/nanopass",
  )
  let ext = find_external_types(a, tree, @meta_parser.resolve_mbti(poc_repr))
  let impls : @list.List[@syntax.Impl] = @list.from_array(
    ext.filter_map(sig_to_impl),
  )
  let output = @fmt.impls_to_string(impls)
  inspect(
    output,
    content=(
      #|///|
      #|pub typealias String as Var
      #|
      #|///|
      #|pub enum Type {
      #|  Bool
      #|  Int
      #|  Arrow(Type, Type)
      #|}
      #|
      #|
    ),
  )
}
