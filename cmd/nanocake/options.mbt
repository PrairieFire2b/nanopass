///|
priv struct GenerateOptions {
  spec : String
  language : String
  module_name : String
  pkg : String
  out_dir : String
  check : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage:
    #|  nanocake generate --spec <file.cake> --language <name> --module <module>
    #|                    [--pkg <package>] [--out-dir <directory>] [--check]
    #|
    #|Options:
    #|  --spec       Path to the .cake metadata sidecar.
    #|  --language   Root language name to generate.
    #|  --module     MoonBit module containing the source enums.
    #|  --pkg        Package containing pkg.generated.mbti (default: inferred).
    #|  --out-dir    Generated package directory (default: generated).
    #|  --check      Fail if generated files are missing or stale; do not write.
    #|
  text
}

///|
fn option_value(
  args : Array[String],
  index : Int,
  name : String,
) -> String raise {
  match args.get(index + 1) {
    Some(value) => value
    None => fail("missing value for \{name}\n\{usage()}")
  }
}

///|
fn parse_generate_options(args : Array[String]) -> GenerateOptions raise {
  let mut spec = ""
  let mut language = ""
  let mut module_name = ""
  let mut pkg = ""
  let mut out_dir = "generated"
  let mut check = false
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--spec" => {
        spec = option_value(args, index, "--spec")
        index = index + 2
      }
      "--language" => {
        language = option_value(args, index, "--language")
        index = index + 2
      }
      "--module" => {
        module_name = option_value(args, index, "--module")
        index = index + 2
      }
      "--pkg" => {
        pkg = option_value(args, index, "--pkg")
        index = index + 2
      }
      "--out-dir" => {
        out_dir = option_value(args, index, "--out-dir")
        index = index + 2
      }
      "--check" => {
        check = true
        index = index + 1
      }
      "--help" | "-h" => fail(usage())
      option => fail("unknown option '\{option}'\n\{usage()}")
    }
  }
  if spec == "" || language == "" || module_name == "" {
    fail("--spec, --language, and --module are required\n\{usage()}")
  }
  { spec, language, module_name, pkg, out_dir, check }
}
