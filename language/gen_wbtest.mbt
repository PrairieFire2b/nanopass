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
fn one_trailing_blank(text : String) -> String {
  text.trim_end().to_owned() + "\n"
}

///|
fn field_order_to_string(order : Array[Int]) -> String {
  order.map(i => "\{i}").join(",")
}

///|
fn layout_target_to_string(layout : ConstructorLayout) -> String {
  let extra = match layout.tree_extra_type {
    Some(ty) => type_name(ty)
    None => "-"
  }
  match layout.target {
    TreeTarget =>
      "TreeTarget(order=[\{field_order_to_string(layout.field_order)}], extra=\{extra})"
    ExtTarget(ext) =>
      "ExtTarget(\{ext}, order=[\{field_order_to_string(layout.field_order)}])"
  }
}

///|
test {
  let (tree, ext_enums) = tree_def

  let poc_repr = @meta_parser.SourceLocRepr::for_pkg(
    pkg="poc",
    mod="YumeXi/nanocake",
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
      #|["LambdaVar", "Type"]
    ),
  )

  let impls = @list.List(
    [@syntax.TopTypeDef(tree)] + ext_enums.map(fn(e) { @syntax.TopTypeDef(e) }),
  )
  inspect(
    one_trailing_blank(@fmt.impls_to_string(impls)),
    content=(
      #|///|
      #|enum Tree[Self_, LamE, TreeExt] {
      #|  /// Terminals
      #|  Int(Int)
      #|  LambdaVar(LambdaVar)
      #|  /// Nonterminals
      #|  Lam(LambdaVar, Self_, LamE)
      #|  App(Self_, Self_)
      #|  Ext(TreeExt)
      #|}
      #|
      #|///|
      #|enum TypedExprExt[Self_] {
      #|  /// Terminals
      #|  True
      #|  False
      #|  /// Nonterminals
      #|  If(cond~ : Self_, Self_, Self_)
      #|}
      #|
    ),
  )
}

///|
test "generated language layout records tree wrapper and constructor targets" {
  let poc_repr = @meta_parser.SourceLocRepr::for_pkg(
    pkg="poc",
    mod="YumeXi/nanocake",
  )
  let mbti = @meta_parser.resolve_mbti(poc_repr)
  let lang : Language = { name: "Lambda", group: a, interface: mbti }
  let layout = lang.layout()
  debug_inspect(
    layout.tree.params,
    content=(
      #|["Self_", "LamE", "TreeExt"]
    ),
  )
  debug_inspect(
    layout.wrappers.map(wrapper => {
      "\{wrapper.lang_name}.\{wrapper.tycon}[\{wrapper.tree_args.join(",")}]"
    }),
    content=(
      #|[
      #|  "Lambda.Expr[Expr,Unit,Unit]",
      #|  "SimplyTypedLambda.TypedExpr[TypedExpr,Type,TypedExprExt]",
      #|]
    ),
  )
  debug_inspect(
    layout.ext_enums.map(ext => {
      "\{ext.lang_name}.\{ext.tycon}[\{ext.constructors.join(",")}]"
    }),
    content=(
      #|["SimplyTypedLambda.TypedExprExt[True,False,If]"]
    ),
  )
  debug_inspect(
    layout.constructors.map(constr => {
      "\{constr.lang_name}.\{constr.constr_name}->\{layout_target_to_string(constr)}"
    }),
    content=(
      #|[
      #|  "Lambda.Int->TreeTarget(order=[0], extra=-)",
      #|  "Lambda.LambdaVar->TreeTarget(order=[0], extra=-)",
      #|  "Lambda.Lam->TreeTarget(order=[0,1], extra=-)",
      #|  "Lambda.App->TreeTarget(order=[0,1], extra=-)",
      #|  "SimplyTypedLambda.True->ExtTarget(TypedExprExt, order=[])",
      #|  "SimplyTypedLambda.False->ExtTarget(TypedExprExt, order=[])",
      #|  "SimplyTypedLambda.Int->TreeTarget(order=[0], extra=-)",
      #|  "SimplyTypedLambda.LambdaVar->TreeTarget(order=[0], extra=-)",
      #|  "SimplyTypedLambda.If->ExtTarget(TypedExprExt, order=[0,1,2])",
      #|  "SimplyTypedLambda.Lam->TreeTarget(order=[0,2,1], extra=Type)",
      #|  "SimplyTypedLambda.App->TreeTarget(order=[0,1], extra=-)",
      #|]
    ),
  )
}

///|
test "sig_to_impl" {
  let (tree, _) = tree_def
  let poc_repr = @meta_parser.SourceLocRepr::for_pkg(
    pkg="poc",
    mod="YumeXi/nanocake",
  )
  let mbti = @meta_parser.resolve_mbti(poc_repr)
  let ext = find_external_types(a, tree, mbti)
  let impls : @list.List[@syntax.Impl] = @list.List(ext.filter_map(sig_to_impl))
  let output = one_trailing_blank(@fmt.impls_to_string(impls))
  inspect(
    output,
    content=(
      #|///|
      #|pub typealias String as LambdaVar
      #|
      #|///|
      #|pub enum Type {
      #|  Bool
      #|  Int
      #|  Arrow(Type, Type)
      #|}
      #|
    ),
  )
  let l : Language = { name: "Lambda", group: a, interface: mbti }
  l.gen()
  |> @fmt.impls_to_string
  |> one_trailing_blank
  |> inspect(
    content=(
      #|///|
      #|enum Tree[Self_, LamE, TreeExt] {
      #|  /// Terminals
      #|  Int(Int)
      #|  LambdaVar(LambdaVar)
      #|  /// Nonterminals
      #|  Lam(LambdaVar, Self_, LamE)
      #|  App(Self_, Self_)
      #|  Ext(TreeExt)
      #|}
      #|
      #|///|
      #|struct Expr(Tree[Expr, Unit, Unit])
      #|
      #|///|
      #|struct TypedExpr(Tree[TypedExpr, Type, TypedExprExt[TypedExpr]])
      #|
      #|///|
      #|enum TypedExprExt[Self_] {
      #|  /// Terminals
      #|  True
      #|  False
      #|  /// Nonterminals
      #|  If(cond~ : Self_, Self_, Self_)
      #|}
      #|
      #|///|
      #|pub typealias String as LambdaVar
      #|
      #|///|
      #|pub enum Type {
      #|  Bool
      #|  Int
      #|  Arrow(Type, Type)
      #|}
      #|
    ),
  )
}
