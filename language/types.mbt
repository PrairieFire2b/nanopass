///|
pub struct Language[L] {
  language_name : String
  _ignore : L? // Always `None`, just to make the compiler happy
} derive(Debug)
