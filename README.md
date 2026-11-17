# Mullzel (WIP)

An experiment in using [Mull](https://github.com/mull-project/mull) to mutation-test Rust tests.

A Linux x86-64 smoke test used Rust 1.85.1 (LLVM 19) and Mull 0.34.2. The Mull LLVM pass instrumented a Cargo unit-test binary. Both baseline tests passed; one test killed an addition-to-subtraction mutant, while the other let the same mutant survive.

The fixture and wrapper are in progress. This is not a performance benchmark or a compatibility claim for current Rust toolchains.
