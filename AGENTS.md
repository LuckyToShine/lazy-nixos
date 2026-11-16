# Repository Rules

## CLI Tool Replacements
- Always use `ripgrep` (`rg`) instead of `grep` when searching codebases, directories, or pattern matching across files.
- Always use `fd` instead of `find` when locating files or directories.
- Always use `eza` instead of `ls` when listing directory contents.
- Always use `sd` instead of `sed` for find-and-replace text transformations.
- Always use `jaq` instead of `jq` when parsing or querying JSON.
- Always use `xh` instead of `curl` when making HTTP requests.
- Use `ast-grep` (never `sg`, which is the shadow-utils group command) for structural code search and refactors, e.g. renaming a Rust function across files.

## Rust & WebAssembly
- Run `cargo clippy` and `cargo fmt` after editing Rust code.
- Prefer `cargo nextest run` over `cargo test` for running tests (doctests still need `cargo test --doc`).
- Use `wasm-opt -Oz` (from binaryen) to shrink `.wasm` builds before publishing.
- Run `shellcheck` on shell scripts after editing them.
