#!/bin/sh
# Build a minimal C module against each version's headers and `require` it from our `lua`.
#   scripts/cmodule.sh TARGET [DIST_DIR]
# macOS only: the Linux builds are static without dlopen (package.loadlib reports "absent",
# see smoke.sh), and the Windows exe exports no Lua API for a module DLL to bind to.
set -eu

target=$1
root=$(cd "$(dirname "$0")/.." && pwd)
dist=${2:-$root/dist/$target}
work=$root/build/cmodule/$target
arch=${target#*-}
mkdir -p "$work"

cat > "$work/hello.c" <<'EOF'
#include "lua.h"
#include "lauxlib.h"
static int greet(lua_State *L) { lua_pushliteral(L, "hello from C"); return 1; }
int luaopen_hello(lua_State *L) {
  lua_newtable(L);
  lua_pushcfunction(L, greet);
  lua_setfield(L, -2, "greet");
  return 1;
}
EOF

for v in 5.1.5 5.2.4 5.3.6 5.4.8 5.5.0; do
  vv=$(echo "$v" | cut -d. -f1-2 | tr -d .)
  dir=$work/$vv
  mkdir -p "$dir"
  cc -arch "$arch" -mmacosx-version-min="${MACOSX_DEPLOYMENT_TARGET:-11.0}" -O2 \
    -I"$root/build/src/lua-$v/src" -bundle -undefined dynamic_lookup \
    -o "$dir/hello.so" "$work/hello.c"
  got=$("$dist/lua$vv-$target" -e "package.cpath='$dir/?.so'; print(require('hello').greet())")
  echo "lua$vv require('hello').greet() -> $got"
  [ "$got" = "hello from C" ] || { echo "FAIL: C module did not load in lua$vv" >&2; exit 1; }
done
echo "cmodule OK: $target"
