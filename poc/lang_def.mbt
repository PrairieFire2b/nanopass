///|
pub type Var = String

///|
#nanopass.language(name="Lambda")
pub(all) enum Expr {
  /// Terminals
  Int(Int)
  Var(String)
  /// Nonterminals
  Lam(Var, Expr)
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
  Var(String)
  /// Nonterminals
  If(TypedExpr, TypedExpr)
  Lam(Var, Type, TypedExpr)
  App(TypedExpr)
} derive(Debug)

///|
pub enum Extensible {} derive(Debug)
