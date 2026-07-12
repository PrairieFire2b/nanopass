// Types produced by `@language.Language::gen()` for the poc Lambda /
// SimplyTypedLambda language group. Checked in here so the generated codecs
// (see `codec.mbt`) can be compiled and executed for real roundtrip tests.
//
// This file is the golden output of `language::gen`; if that generator changes
// shape, regenerate this and `codec.mbt` together.

///|
enum Tree[Self_, LamE, TreeExt] {
  Int(Int)
  LambdaVar(LambdaVar)
  Lam(LambdaVar, Self_, LamE)
  App(Self_, Self_)
  Ext(TreeExt)
} derive(Eq, Show)

///|
struct Expr(Tree[Expr, Unit, Unit]) derive(Eq, Show)

///|
struct TypedExpr(Tree[TypedExpr, Type, TypedExprExt[TypedExpr]]) derive(Eq, Show)

///|
enum TypedExprExt[Self_] {
  True
  False
  If(cond~ : Self_, Self_, Self_)
} derive(Eq, Show)

///|
pub typealias String as LambdaVar

///|
pub enum Type {
  Bool
  Int
  Arrow(Type, Type)
} derive(Eq, Show)
