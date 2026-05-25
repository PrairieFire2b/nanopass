///|
/// Wrapper type for @mbti_ast.Mbti with Debug support
pub(all) struct Mbti(@mbti_ast.Mbti)

///|
/// Helper function to convert PackageImport to Repr
fn package_import_to_repr(pkg_import : @mbti_ast.PackageImport) -> Repr {
  let { name, alias_ } = pkg_import
  Repr::record({ "name": to_repr(name), "alias": to_repr(alias_) })
}

///|
/// Helper function to convert Sig to Repr
fn sig_to_repr(sig : @mbti_ast.Sig) -> Repr {
  match sig {
    Func(func_sig) => {
      let { name, .. } = func_sig
      Repr::ctor("Func", [(None, to_repr(name.name))])
    }
    Type(type_sig) => {
      let { name, .. } = type_sig
      Repr::ctor("Type", [(None, to_repr(name.name))])
    }
    Trait(trait_sig) => {
      let { name, .. } = trait_sig
      Repr::ctor("Trait", [(None, to_repr(name.name))])
    }
    Impl(_) => Repr::ctor("Impl", [])
    Value(value_sig) => {
      let { name, .. } = value_sig
      Repr::ctor("Value", [(None, to_repr(name.name))])
    }
    Const(const_sig) => {
      let { name, .. } = const_sig
      Repr::ctor("Const", [(None, to_repr(name.name))])
    }
    Alias(alias_sig) =>
      match alias_sig {
        FuncAlias(name~, ..) =>
          Repr::ctor("FuncAlias", [(None, to_repr(name.name))])
        TypeAlias(name~, ..) =>
          Repr::ctor("TypeAlias", [(None, to_repr(name.name))])
        Using(target~, name~, ..) => {
          let display_name = match name {
            Some(n) => n.name
            None => target.name
          }
          Repr::ctor("Using", [(None, to_repr(display_name))])
        }
      }
  }
}

///|
/// Debug implementation for Mbti wrapper
///
/// Provides a readable representation showing package name, imports, and signatures
pub impl Debug for Mbti with fn to_repr(self) {
  let Mbti(mbti) = self
  let { package_name, imports, sigs, .. } = mbti

  // Convert imports to array of Repr using map
  let imports_repr = Repr::array(
    imports.map(package_import_to_repr).to_array()
  )

  // Convert sigs to array of Repr using map
  let sigs_repr = Repr::array(
    sigs.iter().map(fn(pair) {
      let (sig, _loc) = pair
      sig_to_repr(sig)
    }).collect()
  )

  // Build a readable representation using Repr::record
  Repr::record({
    "package_name": to_repr(package_name),
    "imports": imports_repr,
    "sigs": sigs_repr,
  })
}

///|
/// Resolve SourceLocRepr to Mbti AST
///
/// This function takes a `SourceLocRepr`
/// and parses its package's interface
pub fn resolve_mbti(loc_repr : SourceLocRepr) -> Mbti raise {
  // Construct path to pkg.generated.mbti
  // Format: <pkg>/pkg.generated.mbti
  let mbti_path = @path.Path::join(loc_repr.pkg, "pkg.generated.mbti")

  // Read the file content
  let content = @fs.read_file_to_string(mbti_path.0)

  // Parse the content into Mbti AST
  let (mbti, _reports) = @mbti_parser.parse_string(content)
  mbti
}
