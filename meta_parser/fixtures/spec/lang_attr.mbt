///|
pub type LambdaVar = String

///|
#nanopass.language(name="Lambda", entry="Expr")
#nano.meta("LambdaVar")
pub(all) enum Expr {
  Int(Int)
  LambdaVar(LambdaVar)
  #nano.form("(lambda $0 $1)")
  Lam(LambdaVar, Expr)
  #nano.form("($0 $1)")
  #nano.form_only
  App(Expr, Expr)
}

///|
#nanopass.nonterminal
pub enum Type {
  Bool
  Int
  Arrow(Type, Type)
}

///|
#nanopass.language(name="SimplyTypedLambda", extends="Lambda", entry="TypedExpr")
enum TypedExpr {
  True
  False
  Int(Int)
  LambdaVar(LambdaVar)
  If(TypedExpr, TypedExpr, TypedExpr)
  Lam(LambdaVar, Type, TypedExpr)
}
