#!/bin/sh
# Show and assert how the binaries for one target are linked.
#   scripts/inspect.sh TARGET [DIST_DIR]
# linux:   `file` must say statically linked; ldd output is printed.
# windows: (run on the Linux build host) imports must be Windows system DLLs only.
# macos:   only libSystem may be linked; arch and minimum OS must match the build settings.
set -eu

target=$1
root=$(cd "$(dirname "$0")/.." && pwd)
dist=${2:-$root/dist/$target}
arch=${target#*-}

fail() { echo "FAIL: $*" >&2; exit 1; }

for bin in "$dist"/lua*-"$target"*; do
  case $bin in *.txt) continue ;; esac
  echo "== $(basename "$bin")"
  case $target in
    linux-*)
      desc=$(file -b "$bin")
      echo "file: $desc"
      echo "ldd:  $(ldd "$bin" 2>&1 || true)"
      case $desc in *"statically linked"*) ;; *) fail "$bin is not statically linked" ;; esac
      case $arch in
        x86_64) case $desc in *x86-64*) ;; *) fail "$bin is not x86-64" ;; esac ;;
        arm64) case $desc in *aarch64*) ;; *) fail "$bin is not aarch64" ;; esac ;;
      esac
      ;;
    windows-*)
      echo "file: $(file -b "$bin")"
      dlls=$(x86_64-w64-mingw32-objdump -p "$bin" | sed -n 's/^.*DLL Name: //p' | tr -d '\r')
      echo "imports: $(echo $dlls)"
      for dll in $dlls; do
        case $(echo "$dll" | tr 'A-Z' 'a-z') in
          kernel32.dll | msvcrt.dll | ucrtbase.dll | api-ms-win-crt-*.dll | user32.dll | advapi32.dll) ;;
          *) fail "$bin imports non-system DLL $dll" ;;
        esac
      done
      ;;
    macos-*)
      echo "file: $(file -b "$bin")"
      libs=$(otool -L "$bin" | tail -n +2 | awk '{print $1}')
      echo "otool -L: $(echo $libs)"
      for lib in $libs; do
        case $lib in /usr/lib/libSystem.B.dylib) ;; *) fail "$bin links $lib" ;; esac
      done
      minos=$(otool -l "$bin" | awk '/LC_BUILD_VERSION/{f=1} f && $1=="minos"{print $2; exit}')
      echo "minos: $minos (MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-unset})"
      [ "$minos" = "${MACOSX_DEPLOYMENT_TARGET:-11.0}" ] || fail "$bin minos $minos"
      archs=$(lipo -archs "$bin")
      echo "archs: $archs"
      [ "$archs" = "$arch" ] || fail "$bin is $archs, expected $arch"
      echo "codesign: $(codesign -dv "$bin" 2>&1 | grep -E "^(Signature|CodeDirectory)" | tr "\n" " " || true)"
      ;;
  esac
done
echo "inspect OK: $target"
