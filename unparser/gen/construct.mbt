// Construct / destructure expressions driven by the shared layout target.

///|
/// Reorder `args` by `order`, i.e. `result[k] = args[order[k]]`.
fn reorder(args : Array[String], order : Array[Int]) -> Array[String] {
  let result : Array[String] = []
  order.each(i => {
    match args.get(i) {
      Some(arg) => result.push(arg)
      None => ()
    }
  })
  result
}

///|
fn call_expr(path : String, args : Array[String]) -> String {
  if args.length() == 0 {
    path
  } else {
    "\{path}(\{args.join(", ")})"
  }
}

///|
/// Reattach constructor field labels (`cond~ : ...` becomes `cond=<arg>`) so
/// the generated code matches the declared constructor shape.
fn labeled(args : Array[String], c : @syntax.ConstrDecl) -> Array[String] {
  let params = constr_args(c)
  let result : Array[String] = []
  args.eachi((i, arg) => {
    match params.get(i) {
      Some(p) =>
        match p.label {
          Some(label) => result.push("\{label.name}=\{arg}")
          None => result.push(arg)
        }
      None => result.push(arg)
    }
  })
  result
}

///|
/// Build a value of the constructor from field expressions `args` (already in
/// source order), using the layout target, field reorder and tree padding.
fn construct(
  cl : @layout.ConstructorLayout,
  tree : @layout.TreeLayout,
  args : Array[String],
  filler : String,
) -> String {
  match cl.target {
    @layout.RawTarget =>
      call_expr(cl.constr_name, labeled(args, cl.source_constr))
    @layout.TreeTarget => {
      let ordered = reorder(args, cl.field_order)
      let slots = tree_slot_count(tree, cl.constr_name)
      while ordered.length() < slots {
        ordered.push(filler)
      }
      "\{cl.source_tycon}(Tree::\{call_expr(cl.constr_name, ordered)})"
    }
    @layout.ExtTarget(ext_tycon) => {
      let ext = call_expr(
        "\{ext_tycon}::\{cl.constr_name}",
        labeled(args, cl.source_constr),
      )
      "\{cl.source_tycon}(Tree::Ext(\{ext}))"
    }
  }
}

///|
/// The field names bound when pattern matching a value of this constructor,
/// in source-field order.
fn field_names(c : @syntax.ConstrDecl) -> Array[String] {
  constr_args(c).mapi((i, p) => {
    match p.label {
      Some(label) => label.name
      None => "x\{i}"
    }
  })
}

///|
/// A pattern that binds each source field to its name, for use in `match`.
fn destructure(
  cl : @layout.ConstructorLayout,
  tree : @layout.TreeLayout,
) -> String {
  let names = field_names(cl.source_constr)
  construct(cl, tree, names, "_")
}
