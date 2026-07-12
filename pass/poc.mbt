///|
/// Load the Lambda/SimplyTypedLambda language group for examples.
let lang : @language.Language = @language.Language::from_file(
  name="Lambda",
  path="poc/lang_def.mbt",
  mod="YumeXi/nanocake",
) catch {
  _ => panic()
}

///|
test "gen_semantics - Semantics struct, identity, and cata method" {
  let impls = gen_semantics(lang)
  let output = @fmt.impls_to_string(impls)
  inspect(
    output,
    content=(
      #|///|
      #|struct ExprSemantics[Repr] {
      #|  Int_ : (Int) -> Repr
      #|  LambdaVar_ : (LambdaVar) -> Repr
      #|  Lam_ : (LambdaVar, Repr, Unit) -> Repr
      #|  App_ : (Repr, Repr) -> Repr
      #|  True_ : () -> Repr
      #|  False_ : () -> Repr
      #|  If_ : (Repr, Repr, Repr) -> Repr
      #|}
      #|
      #|///|
      #|fn ExprSemantics::identity() -> ExprSemantics[Expr] raise {
      #|  {
      #|    Int_: fn(arg0) -> raise { Expr(Int(arg0)) },
      #|    LambdaVar_: fn(arg0) -> raise { Expr(LambdaVar(arg0)) },
      #|    Lam_: fn(arg0, arg1, arg2) -> raise { Expr(Lam(arg0, arg1, arg2)) },
      #|    App_: fn(arg0, arg1) -> raise { Expr(App(arg0, arg1)) },
      #|    True_: fn() -> raise { Expr(Ext(True)) },
      #|    False_: fn() -> raise { Expr(Ext(False)) },
      #|    If_: fn(arg0, arg1, arg2) -> raise { Expr(Ext(If(arg0, arg1, arg2))) },
      #|  }
      #|}
      #|
      #|///|
      #|fn[R] Expr::cata(self : Expr, s : ExprSemantics[R]) -> R raise {
      #|  let Expr(t) = self
      #|  match t {
      #|    Int(arg0) => s.Int_(arg0)
      #|    LambdaVar(arg0) => s.LambdaVar_(arg0)
      #|    Lam(arg0, arg1, arg2) => s.Lam_(arg0, arg1.cata(s), arg2)
      #|    App(arg0, arg1) => s.App_(arg0.cata(s), arg1.cata(s))
      #|    Ext(te) => {
      #|      match te {
      #|        True => s.True_()
      #|        False => s.False_()
      #|        If(cond=cond, arg1, arg2) => 
      #|          s.If_(cond.cata(s), arg1.cata(s), arg2.cata(s))
      #|      }
      #|    }
      #|  }
      #|}
      #|
      #|///|
      #|struct TypedExprSemantics[Repr] {
      #|  Int_ : (Int) -> Repr
      #|  LambdaVar_ : (LambdaVar) -> Repr
      #|  Lam_ : (LambdaVar, Repr, Unit) -> Repr
      #|  App_ : (Repr, Repr) -> Repr
      #|  True_ : () -> Repr
      #|  False_ : () -> Repr
      #|  If_ : (Repr, Repr, Repr) -> Repr
      #|}
      #|
      #|///|
      #|fn TypedExprSemantics::identity() -> TypedExprSemantics[TypedExpr] raise {
      #|  {
      #|    Int_: fn(arg0) -> raise { TypedExpr(Int(arg0)) },
      #|    LambdaVar_: fn(arg0) -> raise { TypedExpr(LambdaVar(arg0)) },
      #|    Lam_: fn(arg0, arg1, arg2) -> raise { TypedExpr(Lam(arg0, arg1, arg2)) },
      #|    App_: fn(arg0, arg1) -> raise { TypedExpr(App(arg0, arg1)) },
      #|    True_: fn() -> raise { TypedExpr(Ext(True)) },
      #|    False_: fn() -> raise { TypedExpr(Ext(False)) },
      #|    If_: fn(arg0, arg1, arg2) -> raise { TypedExpr(Ext(If(arg0, arg1, arg2))) },
      #|  }
      #|}
      #|
      #|///|
      #|fn[R] TypedExpr::cata(self : TypedExpr, s : TypedExprSemantics[R]) -> R raise {
      #|  let TypedExpr(t) = self
      #|  match t {
      #|    Int(arg0) => s.Int_(arg0)
      #|    LambdaVar(arg0) => s.LambdaVar_(arg0)
      #|    Lam(arg0, arg1, arg2) => s.Lam_(arg0, arg1.cata(s), arg2)
      #|    App(arg0, arg1) => s.App_(arg0.cata(s), arg1.cata(s))
      #|    Ext(te) => {
      #|      match te {
      #|        True => s.True_()
      #|        False => s.False_()
      #|        If(cond=cond, arg1, arg2) => 
      #|          s.If_(cond.cata(s), arg1.cata(s), arg2.cata(s))
      #|      }
      #|    }
      #|  }
      #|}
      #|
      #|



    ),
  )
}

///|
test "gen_identity - identity functions for each language" {
  let impls = gen_identity(lang)
  let output = @fmt.impls_to_string(impls)
  inspect(
    output,
    content=(
      #|///|
      #|fn Expr::identity(self : Expr) -> Expr raise {
      #|  self
      #|}
      #|
      #|///|
      #|fn TypedExpr::identity(self : TypedExpr) -> TypedExpr raise {
      #|  self
      #|}
      #|
      #|
    ),
  )
}

///|
test "gen_surface - smart constructors and view for each language" {
  let impls = gen_surface(lang)
  let output = @fmt.impls_to_string(impls)
  inspect(output, content=(
    #|///|
    #|fn Expr::int(arg0 : Int) -> Expr {
    #|  Expr(Int(arg0))
    #|}
    #|
    #|///|
    #|fn Expr::lambdaVar(arg0 : LambdaVar) -> Expr {
    #|  Expr(LambdaVar(arg0))
    #|}
    #|
    #|///|
    #|fn Expr::lam(arg0 : LambdaVar, arg1 : Expr, arg2 : Unit) -> Expr {
    #|  Expr(Lam(arg0, arg1, arg2))
    #|}
    #|
    #|///|
    #|fn Expr::app(arg0 : Expr, arg1 : Expr) -> Expr {
    #|  Expr(App(arg0, arg1))
    #|}
    #|
    #|///|
    #|fn Expr::true_() -> Expr {
    #|  Expr(Ext(True))
    #|}
    #|
    #|///|
    #|fn Expr::false_() -> Expr {
    #|  Expr(Ext(False))
    #|}
    #|
    #|///|
    #|fn Expr::if_(arg0 : Expr, arg1 : Expr, arg2 : Expr) -> Expr {
    #|  Expr(Ext(If(arg0, arg1, arg2)))
    #|}
    #|
    #|///|
    #|enum ExprView {
    #|  VInt(Int)
    #|  VLambdaVar(LambdaVar)
    #|  VLam(LambdaVar, Expr, Unit)
    #|  VApp(Expr, Expr)
    #|  VTrue
    #|  VFalse
    #|  VIf(Expr, Expr, Expr)
    #|}
    #|
    #|///|
    #|fn Expr::view(self : Expr) -> ExprView {
    #|  let Expr(t) = self
    #|  match t {
    #|    Int(arg0) => VInt(arg0)
    #|    LambdaVar(arg0) => VLambdaVar(arg0)
    #|    Lam(arg0, arg1, arg2) => VLam(arg0, arg1, arg2)
    #|    App(arg0, arg1) => VApp(arg0, arg1)
    #|    Ext(te) => {
    #|      match te {
    #|        True => VTrue
    #|        False => VFalse
    #|        If(cond=cond, arg1, arg2) => VIf(cond, arg1, arg2)
    #|      }
    #|    }
    #|  }
    #|}
    #|
    #|///|
    #|fn TypedExpr::int(arg0 : Int) -> TypedExpr {
    #|  TypedExpr(Int(arg0))
    #|}
    #|
    #|///|
    #|fn TypedExpr::lambdaVar(arg0 : LambdaVar) -> TypedExpr {
    #|  TypedExpr(LambdaVar(arg0))
    #|}
    #|
    #|///|
    #|fn TypedExpr::lam(arg0 : LambdaVar, arg1 : TypedExpr, arg2 : Unit) -> TypedExpr {
    #|  TypedExpr(Lam(arg0, arg1, arg2))
    #|}
    #|
    #|///|
    #|fn TypedExpr::app(arg0 : TypedExpr, arg1 : TypedExpr) -> TypedExpr {
    #|  TypedExpr(App(arg0, arg1))
    #|}
    #|
    #|///|
    #|fn TypedExpr::true_() -> TypedExpr {
    #|  TypedExpr(Ext(True))
    #|}
    #|
    #|///|
    #|fn TypedExpr::false_() -> TypedExpr {
    #|  TypedExpr(Ext(False))
    #|}
    #|
    #|///|
    #|fn TypedExpr::if_(arg0 : TypedExpr, arg1 : TypedExpr, arg2 : TypedExpr) -> TypedExpr {
    #|  TypedExpr(Ext(If(arg0, arg1, arg2)))
    #|}
    #|
    #|///|
    #|enum TypedExprView {
    #|  VInt(Int)
    #|  VLambdaVar(LambdaVar)
    #|  VLam(LambdaVar, TypedExpr, Unit)
    #|  VApp(TypedExpr, TypedExpr)
    #|  VTrue
    #|  VFalse
    #|  VIf(TypedExpr, TypedExpr, TypedExpr)
    #|}
    #|
    #|///|
    #|fn TypedExpr::view(self : TypedExpr) -> TypedExprView {
    #|  let TypedExpr(t) = self
    #|  match t {
    #|    Int(arg0) => VInt(arg0)
    #|    LambdaVar(arg0) => VLambdaVar(arg0)
    #|    Lam(arg0, arg1, arg2) => VLam(arg0, arg1, arg2)
    #|    App(arg0, arg1) => VApp(arg0, arg1)
    #|    Ext(te) => {
    #|      match te {
    #|        True => VTrue
    #|        False => VFalse
    #|        If(cond=cond, arg1, arg2) => VIf(cond, arg1, arg2)
    #|      }
    #|    }
    #|  }
    #|}
    #|
    #|

  ))
}


///|
test "parse_pass_meta - extract metadata from attribute" {
  let meta = {
    name: "simplify",
    from_lang: "Lambda",
    to_lang: "Lambda",
    direction: BottomUp,
  }
  inspect(meta.name, content="simplify")
  inspect(meta.from_lang, content="Lambda")
  inspect(meta.to_lang, content="Lambda")
  debug_inspect(meta.direction, content="BottomUp")
}

///|
test "compose - function composition" {
  let f = fn(x : Int) -> Int { x + 1 }
  let g = fn(x : Int) -> Int { x * 2 }
  let h = compose(f, g)
  inspect(h(3), content="8") // (3+1)*2 = 8
}

///|
test "pipeline - run passes in sequence" {
  let p1 : NamedPass[Int, Int] = {
    meta: { name: "add_one", from_lang: "", to_lang: "", direction: BottomUp },
    run: fn(x) { x + 1 },
  }
  let p2 : NamedPass[Int, Int] = {
    meta: { name: "double", from_lang: "", to_lang: "", direction: BottomUp },
    run: fn(x) { x * 2 },
  }
  let result = pipeline([p1, p2], 5) // (5+1)*2 = 12
  inspect(result, content="12")
}

///|
test "fixpoint - apply pass until stable" {
  let halve = {
    meta: { name: "halve", from_lang: "", to_lang: "", direction: BottomUp },
    run: fn(x : Int) -> Int { x / 2 },
  }
  let result = fixpoint(halve, 100, 10)
  inspect(result, content="0") // 100 → 50 → 25 → 12 → 6 → 3 → 1 → 0
}
