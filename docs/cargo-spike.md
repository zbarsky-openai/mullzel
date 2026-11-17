# Mullzel (WIP)

Run [Mull](https://github.com/mull-project/mull) against a Rust test harness. Mullzel uses `cargo rustc` to load Mull's LLVM pass and build the harness once per invocation, then Mull toggles the compiled-in mutants without rebuilding for each one.

## Reproduce the smoke test

Tested on Ubuntu 24.04 x86-64 with Rust 1.85.1 (LLVM 19.1.7), Python 3, and [Mull 0.34.2 for LLVM 19.1.1](https://github.com/mull-project/mull/releases/tag/0.34.2). Use the release asset `Mull-19-0.34.2-LLVM-19.1.1-ubuntu-amd64-24.04.deb` with its `libclang-cpp19` and `libllvm19` dependencies. Set the plugin and runner paths below to your installation; if unpacking instead of installing, make the shared dependencies visible to the dynamic loader.

```sh
rustup toolchain install 1.85.1
export MULL_PLUGIN=/usr/lib/mull-ir-frontend-19
export MULL_RUNNER=mull-runner-19

./mullzel --toolchain 1.85.1 --bootstrap --plugin "$MULL_PLUGIN" \
  --runner "$MULL_RUNNER" --manifest-path example/Cargo.toml \
  --config example/mull.yml --offline --locked \
  --runner-arg=--ide-reporter-show-killed -- --exact tests::strong

./mullzel --toolchain 1.85.1 --bootstrap --plugin "$MULL_PLUGIN" \
  --runner "$MULL_RUNNER" --manifest-path example/Cargo.toml \
  --config example/mull.yml --offline --locked -- --exact tests::weak
```

Both selected tests pass on the original code. The strong test kills the single `+` → `-` mutant (100%, exit 0); the weak test lets it survive (0%, exit 1). Run the wrapper tests with `python3 -m unittest discover -s tests -v`.

## Limits

- The tested stable toolchain needs the explicit `--bootstrap` opt-in to enable rustc's unstable `-Zllvm-plugins` flag. The same LLVM major alone does not guarantee plugin compatibility. Other toolchains, including current Rust and matching nightly builds, are unverified.
- The wrapper instruments one selected crate. Use `--lib` (default) for the library and its inline unit tests. `--test NAME` instruments the integration-test crate, not the separately compiled library it tests.
- This prototype uses a fresh target directory per invocation, disables overflow checks for the selected target, and uses an example Mull config that disables C/C++-specific source filtering. The score covers the configured LLVM mutations, not every possible Rust bug. No speed comparison has been run.
