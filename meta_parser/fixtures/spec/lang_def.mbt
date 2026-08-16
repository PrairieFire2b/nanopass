///|
pub type LambdaVar = String

///|
pub(all) enum Expr {
  Int(Int)
  LambdaVar(LambdaVar)
  Lam(LambdaVar, Expr)
  App(Expr, Expr)
}

///|
pub enum Type {
  Bool
  Int
  Arrow(Type, Type)
}

///|
enum TypedExpr {
  True
  False
  Int(Int)
  LambdaVar(LambdaVar)
  If(TypedExpr, TypedExpr, TypedExpr)
  Lam(LambdaVar, Type, TypedExpr)
}
