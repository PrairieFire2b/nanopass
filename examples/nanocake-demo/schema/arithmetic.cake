(nanocake
  (version 1)
  (source language.mbt)
  (language Arithmetic
    (type ExprSchema)
    (entry ExprSchema)
    (production Add
      (form (+ $0 $1))
      (form-only))
    (production Mul
      (form (* $0 $1))
      (form-only)))
  (language OptimizedArithmetic
    (type OptimizedExprSchema)
    (extends Arithmetic)
    (entry OptimizedExprSchema)))
