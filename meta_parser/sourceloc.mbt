///|
/// SourceLoc representation with module and package information
///
/// SourceLoc.to_string() outputs format: "path/file.mbt:line:col-line:col@username/module"
///
/// Fields:
/// - filename: relative file path (e.g., "language/def_test.mbt")
/// - mod: module name (e.g., "YumeXi/nanopass")
/// - pkg: package name (e.g., "language")
pub struct SourceLocRepr {
  filename : String
  line_start : Int
  col_start : Int
  line_end : Int
  col_end : Int
  mod : String
  pkg : String
} derive(Debug)

///|
/// Resolve SourceLoc to SourceLocRepr with module and package information
/// Parses the SourceLoc.to_string() format and extracts all components.
pub fn resolve(loc : SourceLoc) -> SourceLocRepr {
  let loc_str = loc.to_string()

  // Split by '@' to separate path from module name
  // Format: "path/file.mbt:line:col-line:col@module_name"
  let parts = loc_str.split("@").collect()

  let module_name = if parts.length() >= 2 {
    parts[1].to_owned()
  } else {
    "<UNKNOWN_MODULE_NAME>"
  }

  // The first part contains "path/file.mbt:line:col-line:col"
  let path = if parts.length() >= 1 { parts[0] } else { "<UNKOWN_PATH>" }

  guard path.split_once(":") is Some((file_path, info))

  let line_col = info
    .replace(old="-", new=":")
    .split(":")
    .map(s => @string.parse_int(s) catch { _ => -1 })
    .collect()

  // Extract package name from file path
  // Package is the first directory component (e.g., "language" from "language/define_test.mbt")
  let dir_array = file_path.split("/").collect()

  let package_name = if dir_array.length() >= 2 {
    dir_array[0].to_owned()
  } else {
    "<UNKNOWN_PKG_NAME>"
  }

  {
    filename: file_path.to_owned(),
    line_start: line_col[0],
    col_start: line_col[1],
    line_end: line_col[2],
    col_end: line_col[3],
    mod: module_name,
    pkg: package_name,
  }
}
