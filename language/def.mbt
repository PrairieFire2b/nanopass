///|
#callsite(autofill(loc, _args_loc))
pub fn Language::def(
  name? : String = "",
  loc~ : SourceLoc,
  _args_loc~ : ArgsLoc,
) -> Language raise {
  let repr = loc |> @meta_parser.resolve
  let mbti = @meta_parser.resolve_mbti(repr)
  let langs = @meta_parser.find_languages(repr)
  let _tree = gen_tree_def(langs, _mbti=mbti)
  { name, group: langs }
}

///|
fn type_name(ty : @syntax.Type) -> String {
  match ty {
    @syntax.Name(constr_id~, ..) =>
      match constr_id.id {
        @syntax.Ident(name~) => name
        @syntax.Dot(id~, ..) => id
      }
    _ => ""
  }
}

///|
fn self_type(loc : @basic.Location) -> @syntax.Type {
  @syntax.Name(
    constr_id={ id: @syntax.LongIdent::Ident(name="Self_"), loc },
    tys=@list.empty(),
    loc~,
  )
}

///|
fn gen_tree_def(
  langs : Array[@meta_parser.NanoLangDef],
  _mbti? : @meta_parser.Mbti,
) -> @syntax.TypeDecl {
  ...
}

///|
test {
  let a = @meta_parser.find_languages_by_file("poc/lang_def.mbt")
  let t = gen_tree_def(a)
  @fmt.impls_to_string(@list.from_array([TopTypeDef(t)])) |> println
}
