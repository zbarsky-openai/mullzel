#!/usr/bin/env bash
set -eu
root=${RUNFILES_DIR:-${TEST_SRCDIR:?Bazel runfiles tree required}}
binary="$root/@@BINARY@@"
export MULL_CONFIG="$root/@@CONFIG@@"
library="$root/@@LIB@@"
export LD_LIBRARY_PATH="${library%/*}"

baseline=$("$binary" --exact '@@FILTER@@')
printf '%s\n' "$baseline"
grep -Eq '^test result: ok\. 1 passed;' <<<"$baseline"

set +e
output=$("$root/@@RUNNER@@" --ide-reporter-show-killed -- "$binary" --exact '@@FILTER@@' 2>&1)
status=$?
set -e
printf '%s\n' "$output"
case '@@EXPECTED@@' in
  killed) test "$status" = 0; grep -Fq 'Killed mutants (1/1)' <<<"$output"; grep -Fq '@@LOCATION@@: warning: Killed: Replaced with - [cxx_add_to_sub]' <<<"$output" ;;
  survived) test "$status" = 1; grep -Fq 'Survived mutants (1/1)' <<<"$output"; grep -Fq '@@LOCATION@@: warning: Survived: Replaced with - [cxx_add_to_sub]' <<<"$output" ;;
esac
