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
fn layout_target_to_string(layout : @layout.ConstructorLayout) -> String {
  let extra = match layout.tree_extra_type {
    Some(ty) => type_name(ty)
    None => "-"
  }
  match layout.target {
    @layout.RawTarget =>
      "RawTarget(order=[\{field_order_to_string(layout.field_order)}])"
    @layout.TreeTarget =>
      "TreeTarget(order=[\{field_order_to_string(layout.field_order)}], extra=\{extra})"
    @layout.ExtTarget(ext) =>
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
    layout.group.map(lang => "\{lang.name}:\{lang.type_decl.tycon}"),
    content=(
      #|["Lambda:Expr", "SimplyTypedLambda:TypedExpr"]
    ),
  )
  debug_inspect(
    layout.tree.params,
    content=(
      #|["Self_", "LamE", "TreeExt"]
    ),
  )
  debug_inspect(
    layout.tree.constructors.map(constr => {
      "\{constr.constr_name}(\{constr.field_types.join(",")})"
    }),
    content=(
      #|[
      #|  "Int(Int)",
      #|  "LambdaVar(LambdaVar)",
      #|  "Lam(LambdaVar,Self_,LamE)",
      #|  "App(Self_,Self_)",
      #|  "Ext(TreeExt)",
      #|]
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
    layout.external_types.map(fn(sig) {
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
  debug_inspect(
    layout.constructors.map(constr => {
      "\{constr.lang_name}.\{constr.source_tycon}.\{constr.constr_name}->\{layout_target_to_string(constr)}"
    }),
    content=(
      #|[
      #|  "Lambda.Expr.Int->TreeTarget(order=[0], extra=-)",
      #|  "Lambda.Expr.LambdaVar->TreeTarget(order=[0], extra=-)",
      #|  "Lambda.Expr.Lam->TreeTarget(order=[0,1], extra=-)",
      #|  "Lambda.Expr.App->TreeTarget(order=[0,1], extra=-)",
      #|  "SimplyTypedLambda.TypedExpr.True->ExtTarget(TypedExprExt, order=[])",
      #|  "SimplyTypedLambda.TypedExpr.False->ExtTarget(TypedExprExt, order=[])",
      #|  "SimplyTypedLambda.TypedExpr.Int->TreeTarget(order=[0], extra=-)",
      #|  "SimplyTypedLambda.TypedExpr.LambdaVar->TreeTarget(order=[0], extra=-)",
      #|  "SimplyTypedLambda.TypedExpr.If->ExtTarget(TypedExprExt, order=[0,1,2])",
      #|  "SimplyTypedLambda.TypedExpr.Lam->TreeTarget(order=[0,2,1], extra=Type)",
      #|  "SimplyTypedLambda.TypedExpr.App->TreeTarget(order=[0,1], extra=-)",
      #|  "SimplyTypedLambda.Type.Bool->RawTarget(order=[])",
      #|  "SimplyTypedLambda.Type.Int->RawTarget(order=[])",
      #|  "SimplyTypedLambda.Type.Arrow->RawTarget(order=[0,1])",
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
      #|///|
      #|pub fn parse_Lambda(sexp : @sexp.Sexp) -> Expr raise @sexp.Cause {
      #|  @sexp.with_context("parse Lambda", () => parse_Lambda_raw(sexp))
      #|}
      #|
      #|///|
      #|fn parse_Lambda_raw(_sexp : @sexp.Sexp) -> Expr raise @sexp.SexpError {
      #|  raise  @sexp.GeneratedCode(message="parse Lambda is not generated yet")
      #|}
      #|
      #|///|
      #|pub fn unparse_Lambda(value : Expr) -> @sexp.SexpDoc raise @sexp.Cause {
      #|  @sexp.with_context("unparse Lambda", () => unparse_Lambda_raw(value))
      #|}
      #|
      #|///|
      #|fn unparse_Lambda_raw(_value : Expr) -> @sexp.SexpDoc raise @sexp.SexpError {
      #|  raise  @sexp.GeneratedCode(message="unparse Lambda is not generated yet")
      #|}
      #|
      #|///|
      #|pub fn parse_SimplyTypedLambda(sexp : @sexp.Sexp) -> TypedExpr raise @sexp.Cause {
      #|  @sexp.with_context("parse SimplyTypedLambda", () => {
      #|    parse_SimplyTypedLambda_raw(sexp)
      #|  })
      #|}
      #|
      #|///|
      #|fn parse_SimplyTypedLambda_raw(_sexp : @sexp.Sexp) -> TypedExpr raise @sexp.SexpError {
      #|  raise  
      #|    @sexp.GeneratedCode(message="parse SimplyTypedLambda is not generated yet")
      #|}
      #|
      #|///|
      #|pub fn unparse_SimplyTypedLambda(value : TypedExpr) -> @sexp.SexpDoc raise @sexp.Cause {
      #|  @sexp.with_context("unparse SimplyTypedLambda", () => {
      #|    unparse_SimplyTypedLambda_raw(value)
      #|  })
      #|}
      #|
      #|///|
      #|fn unparse_SimplyTypedLambda_raw(_value : TypedExpr) -> @sexp.SexpDoc raise @sexp.SexpError {
      #|  raise  @sexp.GeneratedCode(
      #|    message="unparse SimplyTypedLambda is not generated yet",
      #|  )
      #|}
      #|
    ),
  )
}
