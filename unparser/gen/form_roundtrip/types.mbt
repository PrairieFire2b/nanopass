// Types produced by `@language.Language::gen()` for the FormBase / FormChild
// language group. Checked in so the generated codecs (form_codec.mbt) can be
// compiled and executed for real roundtrip tests of custom surface forms.

///|
enum Tree[Self_] {
  Num(Int)
  Var(String)
  Lam(String, Self_)
  App(Self_, Self_)
} derive(Eq, Show)

///|
struct FExpr(Tree[FExpr]) derive(Eq, Show)

///|
struct FExpr2(Tree[FExpr2]) derive(Eq, Show)
