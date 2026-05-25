///|
#callsite(autofill(loc, _args_loc))
pub fn[L] Language::def(
  name? : String = "",
  loc~ : SourceLoc,
  _args_loc~ : ArgsLoc,
) -> Language[L] raise {
  let repr = loc |> @meta_parser.resolve
  let _mbti = @meta_parser.resolve_mbti(repr)
  let _langs = @meta_parser.find_languages(repr.file_path())
  ...
  { language_name: name, _ignore: None }
}
