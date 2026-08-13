// Types produced by `@language.Language::gen()` for the HookBase/HookChild
// group (all constructors shared -> no ext enum). Checked in so the generated
// hook-driven codec can be compiled and executed for real roundtrip tests.

///|
enum Tree[Self_] {
  Num(Int)
  Sym(String)
  App(Self_, Self_)
} derive(Eq, Debug)

///|
struct HExpr(Tree[HExpr]) derive(Eq, Debug)

///|
struct HExpr2(Tree[HExpr2]) derive(Eq, Debug)

///|
test "child wrapper constructor remains usable" {
  debug_inspect(HExpr2(Num(0)), content="HExpr2(Num(0))")
}
