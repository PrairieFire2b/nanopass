///|
pub type Var = String

///|
#nanopass.language(name="Lambda")
pub(all) enum Expr {
  /// Terminals
  Var(String)
  /// Nonterminals
  Lam(Var, Expr)
  App(Expr, Expr)
}

///|
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
  Var(String)
  /// Nonterminals
  Lam(Var, Type, TypedExpr)
  App(TypedExpr)
} derive(Debug)

///|
pub enum Extensible {}
