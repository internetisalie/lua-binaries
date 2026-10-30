#!/bin/sh
# Smoke-test every lua/luac pair for one target on the host that runs them.
#   scripts/smoke.sh TARGET [DIST_DIR]
# For each version: `lua -v`, `luac -v`, `luac -p` on a sample using that version's newest
# syntax, run the sample from source and from bytecode, and check the previous version's luac
# rejects it (so each sample really exercises its own version).
set -eu

target=$1
root=$(cd "$(dirname "$0")/.." && pwd)
dist=${2:-$root/dist/$target}
work=$root/build/smoke/$target
mkdir -p "$work"
case $target in windows-*) exe=.exe ;; *) exe= ;; esac

fail() { echo "FAIL: $*" >&2; exit 1; }
run() { "$@" 2>&1 | tr -d '\r'; }

prev=
for vv in 51 52 53 54 55; do
  lua=$dist/lua$vv-$target$exe
  luac=$dist/luac$vv-$target$exe
  sample=$root/samples/lua$vv.lua
  expect=$(sed -n 's/^-- expect: //p' "$sample")
  echo "== lua$vv-$target"
  run "$lua" -v
  run "$luac" -v
  "$luac" -p "$sample" || fail "luac$vv -p rejected its own sample"
  got=$(run "$lua" "$sample")
  echo "source:   $got"
  [ "$got" = "$expect" ] || fail "lua$vv printed '$got', expected '$expect'"
  "$luac" -o "$work/lua$vv.luac" "$sample"
  got=$(run "$lua" "$work/lua$vv.luac")
  echo "bytecode: $got"
  [ "$got" = "$expect" ] || fail "lua$vv bytecode printed '$got', expected '$expect'"
  loadlib=$(run "$lua" -e 'local _, _, where = package.loadlib("lua-binaries-absent", "f"); print(where)')
  echo "package.loadlib: $loadlib (absent = built without dynamic loading)"
  if [ -n "$prev" ]; then
    if "$dist/luac$prev-$target$exe" -p "$sample" >/dev/null 2>&1; then
      fail "luac$prev accepted lua$vv's sample, so it does not test $vv syntax"
    fi
  fi
  prev=$vv
done
echo "smoke OK: $target"
