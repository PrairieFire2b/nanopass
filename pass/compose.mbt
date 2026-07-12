///|
/// Compose two transformation functions sequentially.
pub fn[A, B, C] compose(first : (A) -> B, second : (B) -> C) -> (A) -> C {
  fn(input) { second(first(input)) }
}

///|
/// Run an array of passes in sequence.
pub fn[In] pipeline(passes : Array[NamedPass[In, In]], input : In) -> In {
  passes.fold(init=input, fn(acc, p) { (p.run)(acc) })
}

///|
/// Conditionally apply a pass based on a predicate.
pub fn[In] when(
  cond : (In) -> Bool,
  pass : NamedPass[In, In],
) -> NamedPass[In, In] {
  {
    meta: pass.meta,
    run: fn(input) { if cond(input) { (pass.run)(input) } else { input } },
  }
}

///|
/// Apply a pass repeatedly until a fixpoint is reached or max iterations exceeded.
pub fn[In : Eq] fixpoint(
  pass : NamedPass[In, In],
  input : In,
  max_iters : Int,
) -> In {
  let mut current = input
  for _i in 0..<max_iters {
    let next = (pass.run)(current)
    if next == current {
      break
    }
    current = next
  }
  current
}
