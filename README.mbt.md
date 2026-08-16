# YumeXi/nanocake

[![Check and Test](https://github.com/PrairieFire2b/nanocake/actions/workflows/check.yml/badge.svg?branch=master)](https://github.com/PrairieFire2b/nanocake/actions/workflows/check.yml)
[![mooncakes.io](https://img.shields.io/badge/mooncakes.io-v0.3.3-blue)](https://mooncakes.io/docs/YumeXi/nanocake)
[![License](https://img.shields.io/badge/license-BSD--2--Clause-green)](LICENSE)

A metaprogramming framework for defining composable, type-safe AST transformations.

Given ordinary MoonBit enums and a `.cake` metadata sidecar, the library
generates unified `Tree` types that merge shared constructors across language
extensions, plus S-expression parsers/unparsers and transformation-pass
scaffolding for the resulting ASTs. The original attribute frontend remains
available for compatibility.

- GitHub: <https://github.com/PrairieFire2b/nanocake>
- Package: <https://mooncakes.io/docs/YumeXi/nanocake>

## Installation

Install a current MoonBit toolchain, then add nanocake to a MoonBit module:

```bash
moon add YumeXi/nanocake@0.3.3
```

Install the generator command from mooncakes.io:

```bash
moon install YumeXi/nanocake/cmd/nanocake@0.3.3
nanocake --help
```

The repository currently targets the `wasm` backend by default. To work from
source instead, clone the repository and fetch its declared dependencies:

```bash
git clone https://github.com/PrairieFire2b/nanocake.git
cd nanocake
moon update
moon check
moon test
```

## Architecture

```
                   ┌─────────────┐
 .cake / attributes│ meta_parser │  parse metadata, resolve extends chains,
                   └──────┬──────┘  apply removals, resolve entries/.mbti
                          │ NanoLangDef[]
                          ▼
                   ┌─────────────┐
                   │  language   │  expand inheritance -> a layout, then
                   └──────┬──────┘  generate the unified Tree + wrappers
                          │ GeneratedLanguageLayout
              ┌───────────┼───────────┐
              ▼                       ▼
     ┌─────────────┐          ┌─────────────┐
     │unparser/gen │          │    pass     │  transform/fold scaffolding,
     └──────┬──────┘          └─────────────┘  smart constructors, PassM
            │ from_sexp / to_sexp_doc
            ▼
     ┌─────────────┐
     │unparser/sexp│  S-expression runtime: parse, doc render, form matching
     └─────────────┘
```

- **`meta_parser`** — Parses `.cake` sidecars or the compatibility attribute
  syntax. Resolves language definitions, inheritance, constructor removals,
  effective entries, surface forms, hooks, and `.mbti` interfaces.
- **`language`** — Expands each language against its parent (inheritance,
  override, and `#nano.remove`) into a `GeneratedLanguageLayout`, then generates
  the AST scaffolding: unified syntax trees, per-language wrappers, extension
  enums, and terminal aliases.
- **`unparser/sexp`** — S-expression runtime shared by generated code: a parser,
  a pretty-printing document model, structural `.cake` form matching, and
  layered parse/decode/hook errors.
- **`unparser/gen`** — Generates concrete `from_sexp` / `to_sexp_doc` /
  `parse_sexp` / `unparse_sexp` codecs from a language's layout, honoring custom
  surface syntax and hooks.
- **`pass`** — Transformation-pass scaffolding built on the layout (smart
  constructors, catamorphisms, delayed-subtree rewrites, and the effectful
  `PassM` pipeline). See `pass/README.mbt.md`.

The `poc` package is kept as a fixture/example package for `.mbti`-backed tests.
It is not part of the first-round public package split.

## Quick Start

Nanocake is a code-generation library. Define ordinary MoonBit enums plus a
`.cake` metadata sidecar, then generate a package containing the typed AST,
S-expression codecs, and pass APIs.

### Generate MoonBit sources

With an installed CLI:

```bash
nanocake generate \
  --spec schema/arithmetic.cake \
  --language Arithmetic \
  --module user/compiler \
  --pkg schema \
  --out-dir generated
```

The equivalent command from a nanocake source checkout is:

```bash
moon run cmd/nanocake -- generate \
  --spec examples/nanocake-demo/schema/arithmetic.cake \
  --language Arithmetic \
  --module YumeXi/nanocake-demo \
  --pkg examples/nanocake-demo/schema \
  --out-dir examples/nanocake-demo/generated
```

This writes:

```text
generated/
  ast.mbt
  codec.mbt
  pass.mbt
  moon.pkg
```

| File | Contents |
|------|----------|
| `ast.mbt` | Shared `Tree`, language wrappers, extension enums, external type aliases, and language entry stubs |
| `codec.mbt` | `from_sexp`, `parse_sexp`, `to_sexp_doc`, and `unparse_sexp` implementations |
| `pass.mbt` | Smart constructors, flat views, pure `cata` semantics, and effectful rewrite APIs |
| `moon.pkg` | Imports, generated-source formatter exclusions, and warning policy for the generated package |

Generator options:

| Option | Required | Meaning |
|--------|----------|---------|
| `--spec <file.cake>` | Yes | Metadata sidecar; its `(source ...)` path is resolved relative to this file |
| `--language <name>` | Yes | Root language to generate, including its derived language group |
| `--module <name>` | Yes | MoonBit module containing the source enums |
| `--pkg <path>` | No | Package containing `pkg.generated.mbti`; use this for nested or external packages |
| `--out-dir <path>` | No | Generated package directory; defaults to `generated` |
| `--check` | No | Compare expected output with disk without writing |

Run the command from the module or workspace root so `--spec`, `--pkg`, and
`--out-dir` resolve consistently. Generation is deterministic and only rewrites
files whose content changed.

Use `--check` in CI to fail when any generated file is missing or stale:

```bash
moon run cmd/nanocake -- generate \
  --spec examples/nanocake-demo/schema/arithmetic.cake \
  --language Arithmetic \
  --module YumeXi/nanocake-demo \
  --pkg examples/nanocake-demo/schema \
  --out-dir examples/nanocake-demo/generated \
  --check
```

The generated `moon.pkg` marks generated `.mbt` files as formatter-managed, so
`moon fmt` leaves them unchanged. Add the generated directory to the consuming
workspace and run `moon check` to compile the actual generated output.

### Run the demo

Run the end-to-end expression pipeline from a source checkout:

```bash
moon -C examples/nanocake-demo run .
```

You can also install the standalone demo binary from the checkout:

```bash
moon install ./examples/nanocake-demo
nanocake-demo
```

The demo is a separate `YumeXi/nanocake-demo` module. The root `moon.work`
resolves its `YumeXi/nanocake@0.3.3` dependency to the local source checkout.
It parses `(+ 1 (* 2 3))` with nanocake's S-expression runtime, decodes it
into a wrapper-based typed AST in the shape emitted by the language generator,
runs a bottom-up constant-folding algebra through the generated `cata` API, and
renders the result as `7`. It is self-contained after installation and does not
read repository fixtures at runtime. See `examples/nanocake-demo/generated/`
for checked-in CLI output and `semantics.mbt` for the user-authored algebra.

### Compatibility: define languages with attributes

```mbt nocheck
///|
pub type LambdaVar = String

///|
#nanopass.language(name="Lambda")
pub(all) enum Expr {
  Int(Int)
  LambdaVar(LambdaVar)
  Lam(LambdaVar, Expr)
  App(Expr, Expr)
}

///|
#nanopass.language(name="SimplyTypedLambda", extends="Lambda")
enum TypedExpr {
  True
  False
  Int(Int)
  LambdaVar(LambdaVar)
  If(cond~ : TypedExpr, TypedExpr, TypedExpr)
  Lam(LambdaVar, Type, TypedExpr)
  App(TypedExpr, TypedExpr)
}
```

Surface syntax can be declared alongside constructors with `#nano.*` attributes:

```mbt nocheck
  #nano.form("(lambda ($0 : $1) $2)")
  #nano.form_only
  Lam(LambdaVar, Type, TypedExpr)

  #nano.inline           // renders as ($0 $1) — no constructor head
  App(TypedExpr, TypedExpr)
```

To remove an inherited constructor in a derived language, declare it at the top of the enum:

```mbt nocheck
#nanopass.language(name="NoApp", extends="Lambda")
#nano.remove("App")
enum NoAppExpr {
  // only Lam, Int, LambdaVar are inherited; App is dropped
}
```

### Library API: generate AST scaffolding

```mbt nocheck
let lang = @language.Language::from_file(
  name="Lambda", path="poc/lang_def.mbt", mod="YumeXi/nanocake",
)
let impls = lang.gen()
@fmt.impls_to_string(impls) // format and write to file
```

This produces a unified `Tree[Self_, LamE, TreeExt]` enum, per-language structs
(`Expr`, `TypedExpr`), extension enums (`TypedExprExt`), external terminal
aliases, and stub parse/unparse entry functions.

### Library API: generate S-expression codecs

```mbt nocheck
let lang = @language.Language::from_file(...)
// Generate from_sexp / parse_sexp / to_sexp_doc / unparse_sexp per type.
let codec_impls = @gen.gen(lang)
```

The generator honours `#nano.form`, `#nano.inline`, `#nano.infix`, `#nano.name`
surface syntax and `#nano.parse_by` / `#nano.unparse_by` hook escape hatches.
It also emits a `from_sexp_without_hooks` variant so hooks can call back into
the generated parser without infinite recursion.

### Library API: write passes

See the `pass` package for transform/fold scaffolding and the `PassM` effectful
pipeline combinator.

## Development

Run the same checks used by CI before submitting a change:

```bash
moon check --deny-warn
moon build
moon test --deny-warn
moon fmt --check
moon info
git diff --exit-code
```

The test suite includes parser validation, inheritance and removal semantics,
layout consistency, pass generation, S-expression forms and hooks, plus compiled
roundtrip tests for generated codecs. Generated interfaces
(`pkg.generated.mbti`) are versioned and must remain synchronized with the public
API.

## Repository Layout

| Path | Purpose |
|------|---------|
| `meta_parser/` | Parse and validate `#nanopass` / `#nano` annotations |
| `language/` | Expand language inheritance and generate typed AST layouts |
| `unparser/sexp/` | S-expression runtime, form matching, rendering, and errors |
| `unparser/gen/` | Generate S-expression codecs from a language layout |
| `pass/` | Generate transformation APIs and provide pass composition runtime |
| `poc/` | Language definitions used by interface-backed integration tests |
| `examples/nanocake-demo/` | Independent installable constant-folding module |

See [SOURCES.md](SOURCES.md) for generated-file ownership, fixture provenance,
third-party dependencies, and regeneration notes.

The metadata DSL MVP is documented in
[meta_parser/README.cake.md](meta_parser/README.cake.md). It replaces
verbose nanopass attributes with a structured sidecar while preserving ordinary
MoonBit enum definitions.

## Package Reference

### `@meta_parser` — Parse annotations

| API | Description |
|-----|-------------|
| `find_languages_by_spec_file(path)` | Parse and lower a `.cake` sidecar with its referenced MoonBit source |
| `parse_nano_spec(source)` | Parse `.cake` text into the schema-level `NanoSpec` model |
| `find_languages(src)` | Parse `#nanopass.language` annotations from a `SourceLocRepr` |
| `find_languages_by_file(path)` | Parse language annotations from a file path |
| `normalize_language_defs(langs)` | Validate and resolve entries; returns langs with `resolved_entry` populated |
| `resolve(loc)` | Convert a `SourceLoc` to a structured `SourceLocRepr` |
| `resolve_mbti(repr)` | Parse the `.mbti` interface for a package |
| `NanoLangDef::diff(base, deriv)` | Compute the structural diff between two language definitions |
| `NanoLangDef::with_constructors(self, constrs)` | Return a copy with a new constructor set (rebuilds `production_defs`) |

Key types: `NanoLangDef` (with `removed : Array[String]` for `#nano.remove`),
`ProductionDef` (with `surface_forms`, `hooks`), `FormPattern`, `NanoHooks`.

### `@language` — Generate AST scaffolding

| API | Description |
|-----|-------------|
| `Language::from_spec(name?, path~, mod~, pkg?)` | Resolve a language group from a `.cake` sidecar |
| `Language::def(name?, loc~)` | Resolve languages from the callsite file |
| `Language::from_file(name?, path~, mod~)` | Resolve languages from an explicit file |
| `Language::gen()` | Generate AST definitions (Tree, wrappers, ext enums, terminals, entry stubs) |
| `Language::layout()` | Compute `GeneratedLanguageLayout` (shared by gen and codec generator) |
| `Language::expand()` | Expand the group into `ExpandedLanguageGroup` (inheritance + remove applied) |
| `expand_language_group(raw)` | Standalone expansion without a `Language` object |

`GeneratedLanguageLayout` carries `ConstructorLayout` per constructor: `target`
(`RawTarget` / `TreeTarget` / `ExtTarget`), `field_order`, `surface_forms`, and
`hooks`.

### `@unparser/sexp` — S-expression runtime

| API | Description |
|-----|-------------|
| `parse(src)` | Parse a `StringView` into a `Sexp` |
| `match_form(sexp, pattern, field_count)` | Match a sexp against a `$0`/`$1`-placeholder pattern |
| `form_doc(pattern, fields)` | Render field docs into a surface form |
| `expect_atom / expect_list / expect_arity` | Structural decode helpers |
| `hook_error / decode_error / literal_failure` | Structured error constructors |
| `SexpDoc::render(self, width?)` | Pretty-print a doc to a string |

Error hierarchy: `SexpError { Syntax | Decode | HookError | GeneratedCode }`.
Cause-chained context via `with_context`.

### `@unparser/gen` — Codec generator

| API | Description |
|-----|-------------|
| `gen(lang)` | Generate `Array[@syntax.Impl]` codecs for all types in a language group |
| `gen_source(lang)` | Return the generated source as a `String` (for inspection/snapshotting) |

Generated per type: `Ty::from_sexp`, `Ty::from_sexp_without_hooks` (safe hook
fallback), `Ty::parse_sexp`, `Ty::to_sexp_doc`, `Ty::unparse_sexp`.

### `nanocake` — Generator CLI

| Command | Description |
|---------|-------------|
| `nanocake generate ...` | Generate `ast.mbt`, `codec.mbt`, `pass.mbt`, and `moon.pkg` from a `.cake` sidecar |
| `nanocake generate ... --check` | Verify checked-in generated files without modifying them |

The executable package is `YumeXi/nanocake/cmd/nanocake`.

### `@pass` — Transformation-pass scaffolding

See `pass/README.mbt.md` for the full API. Highlights:

| Capability | API |
|------------|-----|
| Stable AST construction and inspection | Smart constructors, flat view enums, and `view()` |
| Pure bottom-up folds and transforms | `{Lang}Semantics[Repr]` and `cata` |
| Scope-sensitive effectful rewrites | `{Lang}RewriteAlg` and `rewrite_m` |
| Focused pass templates | Diff-driven rewrite stub generation |
| Stateful and logged pipelines | `PassM`, `pipeline_m`, `when_m`, and `traced` |

## Design Rationale

### Why code generation instead of a generic runtime?

The generated `Tree` has per-language-group type parameter lists. A generic runtime library cannot express typed operations over arbitrary tree shapes without higher-kinded types. Code generation produces exactly-typed syntax scaffolding per language group; the same layout decisions drive AST generation, S-expression codec generation, and pass scaffolding.

### How extra type variables work

When a derived language adds arguments to an inherited constructor (e.g., `Lam` gains a `Type` parameter in SimplyTypedLambda), the codegen introduces a fresh type variable (`LamE`). For base languages, it's filled with `Unit`. This keeps the Tree enum generic while preserving type safety per concrete language.

## Goals

### TODOs

- **`#nano.form` named placeholders** — `$x` / `$body` by meta-var name, repeat
  (`...`), optional, and dotted-list patterns are parsed by `meta_parser` but not
  yet consumed by the codec generator.
- **`+/-` extension syntax** — explicit add/remove in the enum body (current
  `#nano.remove` covers top-level removal; inline `+/-` markers are not yet
  supported).
- **`layout.group` type convergence** — `GeneratedLanguageLayout.group` is still
  `Array[NanoLangDef]`; migrating to `ExpandedLanguageGroup` would eliminate the
  parallel shared/own derivation in the layout builder.

### Continued improvements

- **Better codegen ergonomics** — reduce `raise` noise in generated output,
  improve formatting, and add docstrings to generated methods.
- **Error handling in passes** — allow passes to raise typed errors, with
  ergonomic error propagation across the pipeline.
- **Pass composition** — a higher-level API for chaining passes with shared
  state, dependency tracking, and short-circuit on error.

### Incremental computation

Nanopass decomposes a compiler into dozens of small, single-purpose passes. Maybe this can be a natural fit for incremental computation: when a source file changes, only the passes whose inputs are affected need to re-run — the rest can reuse cached results.

However, how to achieve this remains to be explored.

We aim to explore:

- **Pass dependency tracking** — each pass declares its input and output language; the framework can infer a dependency graph and determine the minimal set of passes to re-execute.
- **Granular caching** — cache pass results per AST node or subtree. When a leaf changes, only the ancestor nodes on the path to the root need re-computation.
- **Dirtying and invalidation** — integrate with editor tooling (LSP) to mark specific AST regions as dirty and incrementally re-run passes on just those regions.

The long-term vision is a compiler that responds to each keystroke with near-instant feedback — reusing as much prior work as possible, recomputing only what changed.

## References

[1] A. Keep. A Nanopass Framework for Commercial Compiler Development. Doctoral dissertation, Indiana University, Bloomington, Indiana, USA, Feb. 2013.

[2] S. Najd, S. Peyton Jones. Trees that Grow. Journal of Universal Computer Science, Vol. 23, No. 1, pp. 47-62, Jan. 2017.
