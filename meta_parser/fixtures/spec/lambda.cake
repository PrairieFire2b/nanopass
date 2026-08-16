(nanocake
  (version 1)
  (source lang_def.mbt)
  (nonterminal Type)
  (language Lambda
    (type Expr)
    (entry Expr)
    (meta LambdaVar)
    (production Lam
      (form (lambda $0 $1)))
    (production App
      (form ($0 $1))
      (form-only)))
  (language SimplyTypedLambda
    (type TypedExpr)
    (extends Lambda)
    (entry TypedExpr)))
