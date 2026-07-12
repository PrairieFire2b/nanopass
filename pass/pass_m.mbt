///|
/// Effect monad for nanopass: Reader + State + Writer + Result.
///
/// `PassM[Env, St, Log, Err, A]` is a computation that:
/// - reads from an `Env` (e.g. variable bindings)
/// - reads/writes a `St` (e.g. fresh-name counters)
/// - appends `Log` entries (e.g. traces, diagnostics)
/// - may fail with `Err`
/// - produces a value of type `A`
///
/// # Example
/// ```
/// type Env = Map[Var, Var]
/// type St = Int
/// type Log = String
/// suberror E { BadBinder(Var) }
///
/// fn rename_lam(x, body_m) {
///   fresh_like(x).flat_map(fn(x2) {
///     local_env(fn(env) { env.set(x, x2) }, body_m).map(fn(body) {
///       Expr::lam(x2, body)
///     })
///   })
/// }
/// ```
pub(all) struct PassM[Env, St, Log, Err, A] {
  _run : (Env, St) -> Result[(A, St, Array[Log]), Err]
}

///|
/// ---- Monadic combinators ----

///|
/// Lift a pure value into `PassM`.
pub fn[Env, St, Log, Err, A] PassM::pure(x : A) -> PassM[Env, St, Log, Err, A] {
  { _run: fn(_env, st) { Ok((x, st, [])) } }
}

///|
/// Functor map.
pub fn[Env, St, Log, Err, A, B] PassM::map(
  self : PassM[Env, St, Log, Err, A],
  f : (A) -> B,
) -> PassM[Env, St, Log, Err, B] {
  {
    _run: fn(env, st) {
      match (self._run)(env, st) {
        Ok((a, st2, logs)) => Ok((f(a), st2, logs))
        Err(e) => Err(e)
      }
    },
  }
}

///|
/// Monadic bind. Logs are concatenated left-to-right.
pub fn[Env, St, Log, Err, A, B] PassM::flat_map(
  self : PassM[Env, St, Log, Err, A],
  f : (A) -> PassM[Env, St, Log, Err, B],
) -> PassM[Env, St, Log, Err, B] {
  {
    _run: fn(env, st) {
      match (self._run)(env, st) {
        Ok((a, st2, logs1)) =>
          match (f(a)._run)(env, st2) {
            Ok((b, st3, logs2)) => {
              let combined = logs1 + logs2
              Ok((b, st3, combined))
            }
            Err(e) => Err(e)
          }
        Err(e) => Err(e)
      }
    },
  }
}

///|
/// Lift a `Result` into `PassM`.
pub fn[Env, St, Log, Err, A] PassM::from_result(
  r : Result[A, Err],
) -> PassM[Env, St, Log, Err, A] {
  {
    _run: fn(_env, st) {
      match r {
        Ok(a) => Ok((a, st, []))
        Err(e) => Err(e)
      }
    },
  }
}

///|
/// Handle errors with a recovery function.
pub fn[Env, St, Log, Err, A] PassM::on_err(
  self : PassM[Env, St, Log, Err, A],
  handler : (Err) -> PassM[Env, St, Log, Err, A],
) -> PassM[Env, St, Log, Err, A] {
  {
    _run: fn(env, st) {
      match (self._run)(env, st) {
        Ok(x) => Ok(x)
        Err(e) => (handler(e)._run)(env, st)
      }
    },
  }
}

///|
/// Map the error type.
pub fn[Env, St, Log, Err1, Err2, A] PassM::map_err(
  self : PassM[Env, St, Log, Err1, A],
  f : (Err1) -> Err2,
) -> PassM[Env, St, Log, Err2, A] {
  {
    _run: fn(env, st) {
      match (self._run)(env, st) {
        Ok(x) => Ok(x)
        Err(e) => Err(f(e))
      }
    },
  }
}

///|
/// ---- Reader (environment) ----

///|
/// Read the current environment.
pub fn[Env, St, Log, Err] ask_env() -> PassM[Env, St, Log, Err, Env] {
  { _run: fn(env, st) { Ok((env, st, [])) } }
}

///|
/// Run a sub-computation with a modified environment.
pub fn[Env, St, Log, Err, A] local_env(
  f : (Env) -> Env,
  m : PassM[Env, St, Log, Err, A],
) -> PassM[Env, St, Log, Err, A] {
  { _run: fn(env, st) { (m._run)(f(env), st) } }
}

///|
/// ---- State ----

///|
/// Read the current state.
pub fn[Env, St, Log, Err] get_st() -> PassM[Env, St, Log, Err, St] {
  { _run: fn(_env, st) { Ok((st, st, [])) } }
}

///|
/// Replace the state.
pub fn[Env, St, Log, Err] put_st(st : St) -> PassM[Env, St, Log, Err, Unit] {
  { _run: fn(_env, _st) { Ok(((), st, [])) } }
}

///|
/// Modify the state with a function.
pub fn[Env, St, Log, Err] modify_st(
  f : (St) -> St,
) -> PassM[Env, St, Log, Err, Unit] {
  { _run: fn(_env, st) { Ok(((), f(st), [])) } }
}

///|
/// ---- Writer (logging) ----

///|
/// Emit a log entry.
pub fn[Env, St, Log, Err] emit(log : Log) -> PassM[Env, St, Log, Err, Unit] {
  { _run: fn(_env, st) { Ok(((), st, [log])) } }
}

///|
/// ---- Execution ----

///|
/// Execute a `PassM` computation with initial environment and state.
pub fn[Env, St, Log, Err, A] PassM::exec(
  self : PassM[Env, St, Log, Err, A],
  env : Env,
  st : St,
) -> Result[(A, St, Array[Log]), Err] {
  (self._run)(env, st)
}

///|
/// Execute with only an environment (state = Unit).
pub fn[Env, Log, Err, A] PassM::exec_env(
  self : PassM[Env, Unit, Log, Err, A],
  env : Env,
) -> Result[(A, Unit, Array[Log]), Err] {
  (self._run)(env, ())
}

///|
/// Execute with no environment or state (both Unit).
pub fn[Log, Err, A] PassM::exec_empty(
  self : PassM[Unit, Unit, Log, Err, A],
) -> Result[(A, Unit, Array[Log]), Err] {
  (self._run)((), ())
}
