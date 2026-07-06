///|
pub type LambdaVar = String

///|
#nanopass.language(name="Lambda")
pub(all) enum Expr {
  /// Terminals
  Int(Int)
  LambdaVar(LambdaVar)
  /// Nonterminals
  Lam(LambdaVar, Expr)
  App(Expr, Expr)
}

///|
/// Nonterminal (should be auto-detected)
#nanopass.nonterminal
pub enum Type {
  Bool
  Int
  Arrow(Type, Type)
} derive(Debug)

///|
#nanopass.language(name="SimplyTypedLambda", extends="Lambda")
enum TypedExpr {
  /// Terminals
  True
  False
  Int(Int)
  LambdaVar(LambdaVar)
  /// Nonterminals
  If(cond~ : TypedExpr, TypedExpr, TypedExpr)
  Lam(LambdaVar, Type, TypedExpr)
  App(TypedExpr, TypedExpr)
} derive(Debug)

///|
pub enum Extensible {} derive(Debug)
