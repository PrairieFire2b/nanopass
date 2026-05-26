///|
pub type Var = String

///|
#nanopass.language(name="Lambda")
pub(all) enum Expr {
  /// Terminals
  Int(Int)
  Var(Var)
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
  Var(Var)
  /// Nonterminals
  If(cond~ : TypedExpr, TypedExpr, TypedExpr)
  Lam(Var, Type, TypedExpr)
  App(TypedExpr, TypedExpr)
} derive(Debug)

///|
pub enum Extensible {} derive(Debug)
