///|
pub struct Language[L] {
  language_name : String
  _ignore : L? // Always `None`, just to make the compiler happy
} derive(Debug)

///|
#callsite(autofill(loc, _args_loc))
pub fn[L] Language::def(
  name? : String = "",
  loc~ : SourceLoc,
  _args_loc~ : ArgsLoc,
) -> Language[L] {
  let repr = loc |> @meta_parser.resolve
  let mbti = @meta_parser.resolve_mbti(repr) catch { _ => ... }
  ...
  { language_name: name, _ignore: None }
}
