///|
/// Direction of recursive traversal in a pass.
pub enum PassDirection {
  /// Process children first, then the node itself.
  BottomUp
  /// Process the node first, then children.
  TopDown
} derive(Eq, Debug)

///|
/// Strategy for handling the `Ext` constructor.
pub enum ExtStrategy {
  /// Keep the ext constructor unchanged.
  Keep
  /// Raise an error when encountering an ext constructor.
  Fail
} derive(Eq, Debug)

///|
/// Metadata describing a pass transformation between languages.
pub struct PassMeta {
  /// Human-readable pass name.
  name : String
  /// Source language name (from `#nanopass.language(name="...")`).
  from_lang : String
  /// Target language name.
  to_lang : String
  /// Traversal direction.
  direction : PassDirection
}

///|
/// A named pass that transforms values of type `In` to type `Out`.
pub struct NamedPass[In, Out] {
  meta : PassMeta
  run : (In) -> Out
}
