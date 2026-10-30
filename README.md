# lua-binaries

Standalone PUC-Rio Lua interpreters (`lua`) and compilers (`luac`), built from unmodified
lua.org tarballs whose sha256 is pinned in the `Makefile`. Built for the
Lunar IntelliJ plugin's Lua provisioner and parse
oracle; usable by anyone.

| Version | Linux x86_64 / arm64 | Windows x86_64 | macOS x86_64 / arm64 |
|---------|----------------------|----------------|----------------------|
| 5.1.5, 5.2.4, 5.3.6, 5.4.8, 5.5.0 | musl, fully static | MinGW-w64, static | libSystem only |

Release assets are named `lua<VV>-<os>-<arch>` and `luac<VV>-<os>-<arch>` (`.exe` on
Windows), where `VV` is the major and minor version (`54` for 5.4.8). Each platform has a
`SHA256SUMS-<os>-<arch>.txt`. `LICENSE` in a release carries the Lua and musl notices;
this repository's own scripts are MIT (see `LICENSE`).

## How they are built

`make TARGET=<os>-<arch>` builds every version. Every `.c` file in `src/` except `lua.c`
and `luac.c` is compiled once and linked into both programs. Compile flags are
`-std=gnu99 -O2 -Wall`, plus the compatibility define lua.org's own `src/Makefile` sets
for that release (`LUA_COMPAT_ALL` for 5.2, `LUA_COMPAT_5_2` for 5.3, `LUA_COMPAT_5_3`
for 5.4, none for 5.1 and 5.5), plus:

| Target | Compiler | Defines | Link | C modules (`require` of a `.so`/`.dll`) |
|--------|----------|---------|------|------------------------------------------|
| linux-* | `musl-gcc` | `LUA_USE_POSIX` | `-static -s` | No: built without dynamic loading; `package.loadlib` reports `absent` |
| windows-x86_64 | `x86_64-w64-mingw32-gcc` | none (`LUA_USE_WINDOWS` from `_WIN32`) | `-static -s` | `LoadLibrary` is enabled, but the exe exports no Lua API for a module DLL to bind to; untested |
| macos-* | `clang -arch <arch>` | `LUA_USE_POSIX LUA_USE_DLOPEN` | `strip -x` | Yes: modules built with `-bundle -undefined dynamic_lookup` load (tested in CI) |

5.2 also gets `LUA_USE_STRTODHEX LUA_USE_AFORMAT LUA_USE_LONGLONG` on Linux and macOS,
which lua.org's `linux`/`macosx` targets imply. Readline is never linked.

macOS binaries are built with `MACOSX_DEPLOYMENT_TARGET=11.0` (the `minos` CI checks).
Binaries are not code-signed beyond the linker's ad-hoc signature on Apple silicon, and
not UPX-compressed.

## CI

`.github/workflows/build.yml` builds each target on its own runner, asserts linkage
(`scripts/inspect.sh`), and smoke-tests every binary on its platform
(`scripts/smoke.sh`): `lua -v`, `luac -v`, `luac -p` on `samples/lua<VV>.lua` (which
uses syntax new in that version), running the sample from source and from bytecode, and
checking the previous version's `luac` rejects it. A `v*` tag publishes a release.
