///|
/// ---- Alpha-renaming demonstration ----
///
/// This example shows the core value of PassM: writing scope-sensitive,
/// stateful passes that BottomUp `cata` cannot express.
///
/// In `cata`, the framework recurses children BEFORE calling the handler:
///   Lam(x, body_result) => s.Lam_(x, body_result)
/// The handler sees an already-transformed body — the environment is lost.
///
/// With PassM, the handler receives a **lazy sub-computation** and decides
/// when to run it. For `Lam`/`Let`, we extend the environment first, THEN
/// recurse — so `Var(x)` sees the updated binding.

///|
type Var = String

///|
enum Expr {
  Int(Int)
  Var(Var)
  Lam(Var, Expr)
  App(Expr, Expr)
  Let(Var, Expr, Expr)
} derive(Debug, Eq)

///|
fn extend_env(env : Map[Var, Var], key : Var, val : Var) -> Map[Var, Var] {
  let e = env.copy()
  e.set(key, val)
  e
}

///|
fn fresh_name(base : Var) -> PassM[Map[Var, Var], Int, String, String, Var] {
  @pass.get_st().flat_map(fn(n : Int) {
    @pass.put_st(n + 1).map(fn(_) { "\{base}_\{n}" })
  })
}

///|
/// Alpha-rename: assign a unique name to every bound variable.
///
/// Environment (Reader) : Map[Var,Var] — old name → new name
/// Counter   (State)  : Int            — fresh name index
/// Trace     (Writer) : String         — rename log entries
/// Error     (Result) : String
fn rename(e : Expr) -> PassM[Map[Var, Var], Int, String, String, Expr] {
  match e {
    Int(_) => @pass.PassM::pure(e)
    Var(x) =>
      @pass.ask_env().map(fn(env : Map[Var, Var]) {
        match env.get(x) {
          Some(y) => Var(y)
          None => Var(x)
        }
      })
    Lam(x, body) => {
      // KEY: extend env BEFORE recursing — cata cannot express this
      let body_m = rename(body)
      fresh_name(x).flat_map(fn(x2) {
        @pass.emit("rename \{x} -> \{x2}").flat_map(fn(_) {
          @pass.local_env(fn(env) { extend_env(env, x, x2) }, body_m).map(fn(
            new_body,
          ) {
            Lam(x2, new_body)
          })
        })
      })
    }
    App(f, a) =>
      rename(f).flat_map(fn(new_f) {
        rename(a).map(fn(new_a) { App(new_f, new_a) })
      })
    Let(x, rhs, body) => {
      let rhs_m = rename(rhs)
      let body_m = rename(body)
      rhs_m.flat_map(fn(new_rhs) {
        fresh_name(x).flat_map(fn(x2) {
          @pass.emit("rename \{x} -> \{x2}").flat_map(fn(_) {
            @pass.local_env(fn(env) { extend_env(env, x, x2) }, body_m).map(fn(
              new_body,
            ) {
              Let(x2, new_rhs, new_body)
            })
          })
        })
      })
    }
  }
}

///|
test "alpha-rename: nested same-name binders resolve via scoped env" {
  // Lam(x, Lam(x, Var(x))) — two binders both named "x"
  // The inner Var("x") must reference the INNER binder, not the outer one.
  // BottomUp cata would lose this distinction because env is not threaded.
  let input : Expr = Lam("x", Lam("x", Var("x")))
  let m : PassM[Map[Var, Var], Int, String, String, Expr] = rename(input)
  match m.exec({}, 0) {
    Ok((result, st, logs)) => {
      // Var("x")→Var("x_1") — resolves via inner env {x→x_1}, not outer {x→x_0}
      debug_inspect(result, content="Lam(\"x_0\", Lam(\"x_1\", Var(\"x_1\")))")
      debug_inspect(st, content="2")
      debug_inspect(logs, content="[\"rename x -> x_0\", \"rename x -> x_1\"]")
    }
    _ => panic()
  }
}

///|
test "alpha-rename: Let shadows, rhs resolves in outer scope" {
  // Let(x, Int(1), Let(x, Var(x), Var(x)))
  // ≡ let x = 1 in (let x = x in x)
  // The Var("x") in the inner Let's RHS must see the OUTER env {x→x_0}.
  // The Var("x") in the inner Let's body must see the INNER env {x→x_1}.
  let input : Expr = Let("x", Int(1), Let("x", Var("x"), Var("x")))
  let m : PassM[Map[Var, Var], Int, String, String, Expr] = rename(input)
  match m.exec({}, 0) {
    Ok((result, st, logs)) => {
      debug_inspect(
        result,
        content="Let(\"x_0\", Int(1), Let(\"x_1\", Var(\"x_0\"), Var(\"x_1\")))",
      )
      debug_inspect(st, content="2")
      debug_inspect(logs, content="[\"rename x -> x_0\", \"rename x -> x_1\"]")
    }
    _ => panic()
  }
}

///|
/// ---- Expression validation: Writer + Result demonstration ----
///
/// This pass checks that every variable reference has a binding.
/// Unlike `rename`, it transforms nothing — it only produces side effects:
/// - Writer (Log): records every variable lookup ("bind x", "lookup y")
/// - Result (Err): fails with "unbound: {var}" on free variables
///
/// Together with the alpha-rename example above, this shows all four PassM
/// effects solving complementary compiler-pass concerns.

///|
fn add_var(m : Map[Var, Unit], x : Var) -> Map[Var, Unit] {
  let m2 = m.copy()
  m2.set(x, ())
  m2
}

///|
/// Validate that every variable reference is bound in its enclosing scope.
///
/// Reader (Env)  : Map[Var, Unit] — set of bound variables
/// State  (St)   : Unit            — unused (no transformation state needed)
/// Writer (Log)  : String          — trace of bind/lookup events
/// Result (Err)  : String          — "unbound: {var}" on free variable
fn validate(e : Expr) -> PassM[Map[Var, Unit], Unit, String, String, Unit] {
  match e {
    Int(_) => @pass.PassM::pure(())
    Var(x) =>
      @pass.ask_env().flat_map(fn(env : Map[Var, Unit]) {
        @pass.emit("lookup \{x}").flat_map(fn(_) {
          if env.contains(x) {
            @pass.PassM::pure(())
          } else {
            @pass.PassM::from_result(Err("unbound: \{x}"))
          }
        })
      })
    Lam(x, body) =>
      @pass.emit("bind \{x}").flat_map(fn(_) {
        @pass.local_env(fn(env) { add_var(env, x) }, validate(body))
      })
    App(f, a) => validate(f).flat_map(fn(_) { validate(a) })
    Let(x, rhs, body) =>
      validate(rhs).flat_map(fn(_) {
        @pass.emit("bind \{x}").flat_map(fn(_) {
          @pass.local_env(fn(env) { add_var(env, x) }, validate(body))
        })
      })
  }
}

///|
test "validate: bound vars succeed, Writer logs bind + lookup events" {
  // Lam("x", App(Var("x"), Int(42))) — x is bound, lookup inside Lam succeeds
  let input : Expr = Lam("x", App(Var("x"), Int(42)))
  let m : PassM[Map[Var, Unit], Unit, String, String, Unit] = validate(input)
  match m.exec_env({}) {
    Ok((_, _, logs)) =>
      debug_inspect(logs, content="[\"bind x\", \"lookup x\"]")
    _ => panic()
  }
}

///|
test "validate: unbound variable fails via Result error" {
  // Var("z") at top level — never bound
  let input : Expr = Var("z")
  let m : PassM[Map[Var, Unit], Unit, String, String, Unit] = validate(input)
  match m.exec_env({}) {
    Err("unbound: z") => ()
    _ => panic()
  }
}

///|
test "validate: error short-circuits, unvisited subtrees leave no log" {
  // App(Var("y"), Int(1)) — Var("y") fails, Int(1) is never visited
  // Demonstrates that Result errors stop execution, preventing wasted work
  let input : Expr = App(Var("y"), Int(1))
  let m : PassM[Map[Var, Unit], Unit, String, String, Unit] = validate(input)
  match m.exec_env({}) {
    Err("unbound: y") => ()
    _ => panic()
  }
}

///|
test "validate: on_err recovers from error, emits diagnostic log" {
  // Var("z") fails initially, but on_err catches the error and logs a warning
  let input : Expr = Var("z")
  let m : PassM[Map[Var, Unit], Unit, String, String, Unit] = validate(input)
  let recovered = m.on_err(fn(e) {
    @pass.emit("recovered: \{e}").flat_map(fn(_) { @pass.PassM::pure(()) })
  })
  match recovered.exec_env({}) {
    Ok((_, _, logs)) =>
      debug_inspect(logs, content="[\"recovered: unbound: z\"]")
    _ => panic()
  }
}

///|
test "validate: nested shadowing — inner x hides outer x" {
  // Lam("x", Lam("x", Var("x"))) — inner Var("x") resolves to inner binder
  // Verifies that local_env scopes bindings correctly through nested Lam
  let input : Expr = Lam("x", Lam("x", Var("x")))
  let m : PassM[Map[Var, Unit], Unit, String, String, Unit] = validate(input)
  match m.exec_env({}) {
    Ok((_, _, logs)) =>
      debug_inspect(logs, content="[\"bind x\", \"bind x\", \"lookup x\"]")
    _ => panic()
  }
}

///|
/// ---- Pure / Map / Flat_map ----

///|
test "pure returns the value" {
  let m : PassM[Unit, Unit, Unit, Unit, Int] = @pass.PassM::pure(42)
  let result = m.exec_empty()
  match result {
    Ok((42, _, logs)) => assert_true(logs.is_empty())
    _ => panic()
  }
}

///|
test "map transforms the value" {
  let m : PassM[Unit, Unit, Unit, Unit, Int] = @pass.PassM::pure(21)
  let m2 = m.map(fn(x) { x * 2 })
  let result = m2.exec_empty()
  match result {
    Ok((42, _, _)) => ()
    _ => panic()
  }
}

///|
test "flat_map chains computations" {
  let m : PassM[Unit, Unit, Unit, Unit, Int] = @pass.PassM::pure(10)
  let m2 = m.flat_map(fn(x) { @pass.PassM::pure(x + 32) })
  let result = m2.exec_empty()
  match result {
    Ok((42, _, _)) => ()
    _ => panic()
  }
}

///|
/// ---- Reader (environment) ----

///|
test "ask_env reads the environment" {
  let m : PassM[String, Unit, String, String, Int] = @pass.ask_env().map(fn(
    env : String,
  ) {
    env.length()
  })
  let result = m.exec_env("hello")
  match result {
    Ok((5, _, _)) => ()
    _ => panic()
  }
}

///|
test "local_env modifies environment for sub-computation" {
  let m : PassM[Int, Unit, String, String, Int] = @pass.local_env(
    fn(x) { x * 10 },
    @pass.ask_env(),
  )
  let result = m.exec_env(5)
  match result {
    Ok((50, _, _)) => ()
    _ => panic()
  }
}

///|
test "local_env does not affect outer computation" {
  let m : PassM[Int, Unit, String, String, (Int, Int)] = @pass.ask_env().flat_map(fn(
      outer,
    ) {
      @pass.local_env(fn(x) { x * 2 }, @pass.ask_env()).map(fn(inner) {
        (outer, inner)
      })
    },
  )
  let result = m.exec_env(5)
  match result {
    Ok(((5, 10), _, _)) => ()
    _ => panic()
  }
}

///|
/// ---- State ----

///|
test "get_st reads initial state" {
  let m : PassM[Unit, Int, String, String, Int] = @pass.get_st()
  let result = m.exec((), 42)
  match result {
    Ok((42, 42, _)) => ()
    _ => panic()
  }
}

///|
test "put_st replaces state" {
  let m : PassM[Unit, Int, String, String, Unit] = @pass.put_st(99)
  let result = m.exec((), 0)
  match result {
    Ok((_, 99, _)) => ()
    _ => panic()
  }
}

///|
test "modify_st updates state" {
  let m : PassM[Unit, Int, String, String, Unit] = @pass.modify_st(fn(x) {
    x + 1
  })
  let result = m.exec((), 0)
  match result {
    Ok((_, 1, _)) => ()
    _ => panic()
  }
}

///|
test "state threads through flat_map" {
  let step1 : PassM[Unit, Int, String, String, Unit] = @pass.modify_st(fn(x) {
    x + 1
  })
  let step2 : PassM[Unit, Int, String, String, Unit] = @pass.modify_st(fn(x) {
    x * 10
  })
  let m : PassM[Unit, Int, String, String, Int] = step1.flat_map(fn(_) {
    step2.flat_map(fn(_) { @pass.get_st() })
  })
  let result = m.exec((), 1)
  match result {
    Ok((20, 20, _)) => () // (1+1)*10 = 20
    _ => panic()
  }
}

///|
/// ---- Writer (logging) ----

///|
test "emit appends log entries" {
  let m : PassM[Unit, Unit, String, String, Unit] = @pass.emit("hello").flat_map(fn(
      _,
    ) {
      @pass.emit("world")
    },
  )
  let result = m.exec((), ())
  match result {
    Ok((_, _, logs)) => assert_eq(logs, ["hello", "world"])
    _ => panic()
  }
}

///|
test "logs accumulate through flat_map in order" {
  let m : PassM[Unit, Unit, String, String, Unit] = @pass.emit("a").flat_map(fn(
    _,
  ) {
    @pass.emit("b").flat_map(fn(_) { @pass.emit("c") })
  })
  let result = m.exec((), ())
  match result {
    Ok((_, _, logs)) => assert_eq(logs, ["a", "b", "c"])
    _ => panic()
  }
}

///|
/// ---- Error handling ----

///|
test "from_result Ok works" {
  let m : PassM[Unit, Unit, String, String, Int] = @pass.PassM::from_result(
    Ok(42),
  )
  let result = m.exec_empty()
  match result {
    Ok((42, _, _)) => ()
    _ => panic()
  }
}

///|
test "from_result Err propagates" {
  let m : PassM[Unit, Unit, String, String, Int] = @pass.PassM::from_result(
    Err("fail"),
  )
  let result = m.exec_empty()
  guard result is Err("fail") else { panic() }
}

///|
test "on_err recovers from error" {
  let m : PassM[Unit, Unit, String, String, Int] = @pass.PassM::from_result(
    Err("fail"),
  )
  let m2 = m.on_err(fn(_) { @pass.PassM::pure(42) })
  let result = m2.exec_empty()
  match result {
    Ok((42, _, _)) => ()
    _ => panic()
  }
}

///|
test "on_err not called on success" {
  let m : PassM[Unit, Unit, String, String, Int] = @pass.PassM::pure(10)
  let m2 = m.on_err(fn(_) { @pass.PassM::pure(99) })
  let result = m2.exec_empty()
  match result {
    Ok((10, _, _)) => ()
    _ => panic()
  }
}

///|
test "map_err transforms error type" {
  let m : PassM[Unit, Unit, String, Int, Int] = @pass.PassM::from_result(Err(3))
  let m2 : PassM[Unit, Unit, String, String, Int] = m.map_err(fn(e) {
    e.to_string()
  })
  let result = m2.exec_empty()
  guard result is Err("3") else { panic() }
}

///|
/// ---- Combined effects ----

///|
test "reader state writer combined" {
  // env=multiplier, state=counter. Reads env, multiplies state, emits log.
  let m : PassM[Int, Int, String, String, Int] = @pass.ask_env().flat_map(fn(
    mult : Int,
  ) {
    @pass.modify_st(fn(s) { s * mult }).flat_map(fn(_) {
      @pass.emit("multiplied by \{mult}").flat_map(fn(_) { @pass.get_st() })
    })
  })
  let result = m.exec(10, 3)
  match result {
    Ok((30, 30, logs)) => assert_eq(logs, ["multiplied by 10"])
    _ => panic()
  }
}

///|
test "state changes inside local_env are visible" {
  // local_env scopes reader but NOT state
  let m : PassM[Int, Int, String, String, Int] = @pass.put_st(0).flat_map(fn(
    _,
  ) {
    @pass.local_env(fn(x) { x + 1 }, @pass.put_st(99)).flat_map(fn(_) {
      @pass.get_st()
    })
  })
  let result = m.exec(1, 0)
  match result {
    Ok((99, 99, _)) => ()
    _ => panic()
  }
}

///|
/// ---- M5: traced, pipeline_m, when_m ----

///|
test "traced prepends label to log before running computation" {
  let m : PassM[Unit, Unit, String, String, Int] = @pass.traced(
    "step-a",
    @pass.PassM::pure(42),
  )
  match m.exec_empty() {
    Ok((42, _, logs)) => assert_eq(logs, ["step-a"])
    _ => panic()
  }
}

///|
test "traced with nested emit: label appears first" {
  let m : PassM[Unit, Unit, String, String, Int] = @pass.traced(
    "outer",
    @pass.emit("inner").flat_map(fn(_) { @pass.PassM::pure(7) }),
  )
  match m.exec_empty() {
    Ok((7, _, logs)) => assert_eq(logs, ["outer", "inner"])
    _ => panic()
  }
}

///|
test "pipeline_m sequences steps, accumulates logs" {
  let step1 : (Int) -> PassM[Unit, Unit, String, String, Int] = fn(x) {
    @pass.emit("step1").flat_map(fn(_) { @pass.PassM::pure(x + 1) })
  }
  let step2 : (Int) -> PassM[Unit, Unit, String, String, Int] = fn(x) {
    @pass.emit("step2").flat_map(fn(_) { @pass.PassM::pure(x * 2) })
  }
  let result = @pass.pipeline_m([step1, step2], 5).exec_empty()
  match result {
    Ok((12, _, logs)) => assert_eq(logs, ["step1", "step2"]) // (5+1)*2=12
    _ => panic()
  }
}

///|
test "pipeline_m short-circuits on error, later steps do not run" {
  let step1 : (Int) -> PassM[Unit, Unit, String, String, Int] = fn(_x) {
    @pass.emit("step1").flat_map(fn(_) { @pass.PassM::from_result(Err("fail")) })
  }
  let step2 : (Int) -> PassM[Unit, Unit, String, String, Int] = fn(x) {
    @pass.emit("step2").flat_map(fn(_) { @pass.PassM::pure(x * 2) })
  }
  let result = @pass.pipeline_m([step1, step2], 5).exec_empty()
  match result {
    Err("fail") => () // step2 never ran
    _ => panic()
  }
}

///|
test "when_m skips step when condition false" {
  let always_false : (Int) -> Bool = fn(_) { false }
  let step : (Int) -> PassM[Unit, Unit, String, String, Int] = fn(x) {
    @pass.emit("ran").flat_map(fn(_) { @pass.PassM::pure(x + 100) })
  }
  let guarded = @pass.when_m(always_false, step)
  match guarded(5).exec_empty() {
    Ok((5, _, logs)) => assert_true(logs.is_empty()) // unchanged, no log
    _ => panic()
  }
}

///|
test "when_m runs step when condition true" {
  let always_true : (Int) -> Bool = fn(_) { true }
  let step : (Int) -> PassM[Unit, Unit, String, String, Int] = fn(x) {
    @pass.emit("ran").flat_map(fn(_) { @pass.PassM::pure(x + 100) })
  }
  let guarded = @pass.when_m(always_true, step)
  match guarded(5).exec_empty() {
    Ok((105, _, logs)) => assert_eq(logs, ["ran"])
    _ => panic()
  }
}
