#!/usr/bin/env bash
# Packs verified binaries into one archive per Lua version and target:
#   lua-<version>-<target>.tar.gz (.zip for windows-*) holding lua-<version>-<target>/{bin/lua,bin/luac,LICENSE}
# then writes SHA256SUMS over the archives.
#
#   scripts/package.sh <assets-dir> <license> <out-dir>
set -euo pipefail

assets=$1
license=$2
out=$3
root=$(cd "$(dirname "$0")/.." && pwd)
versions=$(sed -n 's/^VERSIONS *:= *//p' "$root/Makefile")
targets="linux-x86_64 linux-arm64 windows-x86_64 macos-x86_64 macos-arm64"
epoch=${SOURCE_DATE_EPOCH:-$(git -C "$root" log -1 --format=%ct)}

mkdir -p "$out"
out=$(cd "$out" && pwd)
stage=$(mktemp -d "${RUNNER_TEMP:-$out}/stage.XXXXXX")
trap 'rm -rf "$stage"' EXIT

for version in $versions; do
  vv=$(echo "$version" | cut -d. -f1,2 | tr -d .)
  for target in $targets; do
    exe=; case $target in windows-*) exe=.exe ;; esac
    name=lua-$version-$target
    dir=$stage/$name
    mkdir -p "$dir/bin"
    install -m 0755 "$assets/lua$vv-$target$exe" "$dir/bin/lua$exe"
    install -m 0755 "$assets/luac$vv-$target$exe" "$dir/bin/luac$exe"
    install -m 0644 "$license" "$dir/LICENSE"
    find "$dir" -type d -exec chmod 0755 {} +
    find "$dir" -exec touch -h -d "@$epoch" {} +
    case $target in
      windows-*)
        (cd "$stage" && find "$name" | LC_ALL=C sort | TZ=UTC zip -qX -@ "$out/$name.zip") ;;
      *)
        tar -C "$stage" --sort=name --owner=0 --group=0 --numeric-owner --mtime="@$epoch" \
          -cf - "$name" | gzip -n -9 > "$out/$name.tar.gz" ;;
    esac
  done
done

(cd "$out" && sha256sum lua-*.tar.gz lua-*.zip > SHA256SUMS)
cat "$out/SHA256SUMS"
