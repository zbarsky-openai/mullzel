# Mullzel (WIP)

Mutation-test a Rust library under Bazel with [Mull](https://github.com/mull-project/mull). Bazel builds one instrumented `rust_test` binary using [rules_rs](https://github.com/hermeticbuild/rules_rs). Then separate Bazel test actions run selected tests with compiled-in mutants toggled at runtime. No Cargo build or per-mutant compilation.

## Try the smoke test

Tested with Bazel 9.3.2, rules_rs 0.2.4, Rust 1.85.1 (LLVM 19.1.7), and Mull 0.34.2 (LLVM 19.1.1) on Ubuntu 24.04 x86-64. Bazel fetches the Rust toolchain; no rustup or Cargo installation is needed. You'll need a standard Linux build environment (including a C/C++ linker), plus a local copy of the three packages below.

From the repository root, in Bash:

```sh
set -e
sdk=$(mktemp -d)
mkdir -p "$sdk/downloads" "$sdk/lib"
(
  cd "$sdk/downloads"
  asset=Mull-19-0.34.2-LLVM-19.1.1-ubuntu-amd64-24.04.deb
  curl -fLO "https://github.com/mull-project/mull/releases/download/0.34.2/$asset"
  echo "755955a2253290ec2d5d23376c0bffaa42152b806533df1ac581081ae27a0b2b  $asset" | sha256sum -c -
  apt-get download libclang-cpp19 libllvm19
  for package in ./*.deb; do dpkg-deb -x "$package" extracted; done
)
ln -s "$sdk/downloads/extracted/usr/lib/mull-ir-frontend-19" "$sdk/mull-ir-frontend-19"
ln -s "$sdk/downloads/extracted/usr/bin/mull-runner-19" "$sdk/mull-runner-19"
for so in libLLVM.so.19.1 libclang-cpp.so.19.1; do
  ln -s "$sdk/downloads/extracted/usr/lib/x86_64-linux-gnu/$so" "$sdk/lib/$so"
done

bazel test --repo_env=MULLZEL_MULL_SDK="$sdk" \
  //example:strong //example:weak --test_output=all
```

Both tests pass against the original. The strong test kills the single `+` → `-` mutant in `sum`; the weak test lets it survive. Both Bazel targets should pass: the weak target is a negative control, not a quality gate. They assert the exact implementation mutation, so finding zero mutants doesn't count as a pass.

## Design and limits

- `mull_rust_harness` wraps the normal `rust_test` rule. The plugin, its two LLVM libraries, and the config are declared compile inputs. A small bundle keeps their relative paths stable in the sandbox. The Bazel test rule uses the resulting executable, Mull runner, LLVM libraries, and config as runfiles.
- The Mull package above has a pinned checksum. The two Ubuntu libraries are resolved from local Ubuntu package metadata and exposed through a local Bazel repository. The prototype still relies on the host linker, OS libraries and Linux runfiles symlinks. It is not a remote-execution or cross-compilation setup.
- The stable Rust toolchain needs `RUSTC_BOOTSTRAP=1` for `-Zllvm-plugins`; matching the LLVM major alone doesn't guarantee plugin compatibility. The example disables overflow checks and Mull's C/C++ AST filter. Newer Rust, other mutators, remote execution, cross compilation, and performance relative to other tools are unverified.
- Only the selected Rust test crate is instrumented, not its separately compiled dependencies.

The [earlier Cargo spike](docs/cargo-spike.md) is retained as a reference, not part of the Bazel workflow.
