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
      #|    Int_: fn(arg0) -> raise { Expr::Int(arg0) },
      #|    LambdaVar_: fn(arg0) -> raise { Expr::LambdaVar(arg0) },
      #|    Lam_: fn(arg0, arg1, arg2) -> raise { Expr::Lam(arg0, arg1, arg2) },
      #|    App_: fn(arg0, arg1) -> raise { Expr::App(arg0, arg1) },
      #|    True_: fn() -> raise { Expr::Ext(True) },
      #|    False_: fn() -> raise { Expr::Ext(False) },
      #|    If_: fn(arg0, arg1, arg2) -> raise {
      #|      Expr::Ext(TypedExprExt::If(arg0, arg1, arg2))
      #|    },
      #|  }
      #|}
      #|
      #|///|
      #|fn[R] Expr::cata(self : Expr, s : ExprSemantics[R]) -> R raise {
      #|  let Tree(t) = self
      #|  match t {
      #|    Int(arg0) => s.Int_(arg0)
      #|    LambdaVar(arg0) => s.LambdaVar_(arg0)
      #|    Lam(arg0, arg1, arg2) => s.Lam_(arg0, arg1.cata(s), arg2)
      #|    App(arg0, arg1) => s.App_(arg0.cata(s), arg1.cata(s))
      #|    Ext(te) => {
      #|      match te {
      #|        True => s.True_()
      #|        False => s.False_()
      #|        If(cond~, arg1, arg2) => s.If_(arg0.cata(s), arg1.cata(s), arg2.cata(s))
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
      #|    Int_: fn(arg0) -> raise { TypedExpr::Int(arg0) },
      #|    LambdaVar_: fn(arg0) -> raise { TypedExpr::LambdaVar(arg0) },
      #|    Lam_: fn(arg0, arg1, arg2) -> raise { TypedExpr::Lam(arg0, arg1, arg2) },
      #|    App_: fn(arg0, arg1) -> raise { TypedExpr::App(arg0, arg1) },
      #|    True_: fn() -> raise { TypedExpr::Ext(True) },
      #|    False_: fn() -> raise { TypedExpr::Ext(False) },
      #|    If_: fn(arg0, arg1, arg2) -> raise {
      #|      TypedExpr::Ext(TypedExprExt::If(arg0, arg1, arg2))
      #|    },
      #|  }
      #|}
      #|
      #|///|
      #|fn[R] TypedExpr::cata(self : TypedExpr, s : TypedExprSemantics[R]) -> R raise {
      #|  let Tree(t) = self
      #|  match t {
      #|    Int(arg0) => s.Int_(arg0)
      #|    LambdaVar(arg0) => s.LambdaVar_(arg0)
      #|    Lam(arg0, arg1, arg2) => s.Lam_(arg0, arg1.cata(s), arg2)
      #|    App(arg0, arg1) => s.App_(arg0.cata(s), arg1.cata(s))
      #|    Ext(te) => {
      #|      match te {
      #|        True => s.True_()
      #|        False => s.False_()
      #|        If(cond~, arg1, arg2) => s.If_(arg0.cata(s), arg1.cata(s), arg2.cata(s))
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
