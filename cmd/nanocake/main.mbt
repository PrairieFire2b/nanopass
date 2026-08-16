///|
fn main raise {
  let argv = @env.args()
  let args = if argv.length() > 0 { argv[1:].to_owned() } else { [] }
  match args {
    ["generate", .. rest] => {
      let options = parse_generate_options(rest.to_owned())
      let changed = write_generated_files(options)
      if options.check {
        if changed.length() > 0 {
          fail("generated files are stale:\n" + changed.join("\n"))
        }
        println("generated files are up to date")
      } else if changed.length() == 0 {
        println("generated files are already up to date")
      } else {
        for path in changed {
          println("wrote \{path}")
        }
      }
    }
    ["--help" | "-h"] | [] => println(usage())
    [command, ..] => fail("unknown command '\{command}'\n\{usage()}")
  }
}
