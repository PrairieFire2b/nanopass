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

///|
/// Run an array of effectful pass steps sequentially.
///
/// Each step is `(In) -> PassM[..., In]`. Steps are chained via `flat_map`;
/// if any step fails with `Err`, the pipeline short-circuits. Logs from all
/// steps that ran are concatenated in order.
///
/// # Example
/// ```
/// let steps = [rename_step, constant_fold_step, validate_step]
/// let result = pipeline_m(steps, expr).exec(env, 0)
/// ```
pub fn[In, Env, St, Log, Err] pipeline_m(
  steps : Array[(In) -> PassM[Env, St, Log, Err, In]],
  input : In,
) -> PassM[Env, St, Log, Err, In] {
  steps.fold(init=PassM::pure(input), fn(acc, step) { acc.flat_map(step) })
}

///|
/// Lift a conditional guard around an effectful step.
/// If `cond(input)` is false the step is skipped and the input is returned
/// unchanged (as `PassM::pure`).
pub fn[In, Env, St, Log, Err] when_m(
  cond : (In) -> Bool,
  step : (In) -> PassM[Env, St, Log, Err, In],
) -> (In) -> PassM[Env, St, Log, Err, In] {
  fn(input) {
    if cond(input) {
      step(input)
    } else {
      PassM::pure(input)
    }
  }
}
