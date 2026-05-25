///|
pub struct Language[L] {
  language_name : String
  _ignore : L? // Always `None`, just to make the compiler happy
} derive(Debug)

///|
#callsite(autofill(loc, args_loc))
pub fn[L] Language::def(
  name? : String = "",
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Language[L] {
  let _ = loc |> @meta_parser.resolve
  ...
  { language_name: name, _ignore: None }
}
