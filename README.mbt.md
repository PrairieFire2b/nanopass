# YumeXi/nanocake

A metaprogramming framework for defining composable, type-safe AST transformations.

Given MoonBit enums annotated with `#nanopass.language`, the library generates:

1. **Unified Tree types** — merged enums combining shared constructors across language extensions
2. **NanoPass boilerplate** — typed transform/fold structs with traversal logic, ready for user-defined passes

## Architecture

```
                  ┌─────────────┐
#nanopass.language │ meta_parser │  parse annotations, resolve extends chains
                  └──────┬──────┘
                         │ NanoLangDef[]
                         ▼
                  ┌─────────────┐
                  │   language   │  generate a unified syntax tree structure.
                  └──────┬──────┘
                         │
                         ▼
                  ┌─────────────┐
                  │     pass     │  generate nanopasses, transform/fold methods
                  └─────────────┘
```

- **`meta_parser`** — Parses `#nanopass.language` / `#nanopass.nonterminal` annotations from source files. Resolves language definitions, `extends` chains, and `.mbti` interfaces.
- **`language`** — Generates the AST scaffolding: unfied syntax trees and language-specific aliases
- **`pass`** — Generates typed NanoPass infrastructure: transform structs with identity defaults, bottom-up traversal, fold/catamorphism support, and minimal pass stubs from `Diff`s. Also provides runtime composition utilities.

## Quick Start

### 1. Define languages

```mbt nocheck
///|
#nanopass.language(name="Lambda")
pub(all) enum Expr {
  Int(Int)
  Var(String)
  Lam(String, Expr)
  App(Expr, Expr)
}

///|
#nanopass.language(name="SimplyTypedLambda", extends="Lambda")
enum TypedExpr {
  True
  False
  Int(Int)
  Var(String)
  If(cond~ : TypedExpr, TypedExpr, TypedExpr)
  Lam(String, Type, TypedExpr)
  App(TypedExpr, TypedExpr)
}
```

### 2. Generate AST scaffolding

```mbt nocheck
let lang = @language.Language::from_file(
  name="Lambda", path="poc/lang_def.mbt", mod="YumeXi/nanopass",
)
let impls = lang.gen()
@fmt.impls_to_string(impls) // format and write to file
```

This produces a unified `Tree[Self_, LamE, TreeExt]` enum, per-language structs (`Expr`, `TypedExpr`), extension enums (`TypedExprExt`), and external terminal aliases.

### 3. Write passes

**TODO**

## Package Reference

### `@meta_parser` — Parse annotations

| API | Description |
|-----|-------------|
| `find_languages(src)` | Parse `#nanopass.language` annotations from a `SourceLocRepr` |
| `find_languages_by_file(path)` | Parse language annotations from a file path |
| `resolve(loc)` | Convert a `SourceLoc` to a structured `SourceLocRepr` |
| `resolve_mbti(repr)` | Parse the `.mbti` interface for a package |
| `NanoLangDef::diff(base, deriv)` | Compute the structural diff between two language definitions |

### `@language` — Generate AST scaffolding

| API | Description |
|-----|-------------|
| `Language::def(name?, loc~)` | Resolve languages from the callsite file |
| `Language::from_file(name?, path~, mod~)` | Resolve languages from an explicit file |
| `Language::gen()` | Generate AST definitions|

## Design Rationale

### Why code generation instead of a generic runtime?

The generated `Tree` has per-language-group type parameter lists. A generic runtime library cannot express typed operations over arbitrary tree shapes without higher-kinded types. Code generation produces exactly-typed nanopasses and traversals per language group — the same pattern `language::gen` uses for Tree enums.

### How extra type variables work

When a derived language adds arguments to an inherited constructor (e.g., `Lam` gains a `Type` parameter in SimplyTypedLambda), the codegen introduces a fresh type variable (`LamE`). For base languages, it's filled with `Unit`. This keeps the Tree enum generic while preserving type safety per concrete language.

## Goals

### TODOs

- **Generating Passes** - provide interfaces to easily play with the AST and write passes.

### Continued improvements

- **Better codegen ergonomics** — simplify the generated output: reduce `raise` noise, improve formatting, and add docstrings to generated methods.
- **Error handling in passes** — allow passes to raise typed errors, with ergonomic error propagation across the pipeline.

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
