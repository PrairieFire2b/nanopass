///|
pub(all) enum ExprSchema {
  Int(Int)
  Var(String)
  Add(ExprSchema, ExprSchema)
  Mul(ExprSchema, ExprSchema)
}

///|
pub(all) enum OptimizedExprSchema {
  Int(Int)
  Var(String)
  Add(OptimizedExprSchema, OptimizedExprSchema)
  Mul(OptimizedExprSchema, OptimizedExprSchema)
}
