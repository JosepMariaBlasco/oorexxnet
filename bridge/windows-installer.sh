#!/usr/bin/env bash
# The Windows installer of the bridge, from the binary zip (package.sh's
# rexxnet-VERSION.zip: VERSION from its name): DEST/oorexxnet-VERSION-setup.exe,
# with the zip's Windows part (its other systems' native libraries left out).
# Needs NSIS 3 (makensis: Windows, or apt install nsis); the script is
# dist/windows/oorexxnet.nsi.
#
#   bridge/windows-installer.sh ZIP [DEST]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(dirname "$here")"
zip="${1:?usage: windows-installer.sh ZIP [DEST]}"
dest="${2:-.}"
name="$(basename "$zip" .zip)"
case "$name" in
  rexxnet-*) version="${name#rexxnet-}" ;;
  *) echo "windows-installer.sh: $zip is not a rexxnet-VERSION.zip" >&2; exit 2 ;;
esac
makensis="$(command -v makensis || true)"
[ -n "$makensis" ] || [ ! -x "/c/Program Files (x86)/NSIS/makensis.exe" ] || makensis="/c/Program Files (x86)/NSIS/makensis.exe"
[ -n "$makensis" ] || { echo "windows-installer.sh: NSIS 3 (makensis) is needed" >&2; exit 2; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
if command -v unzip >/dev/null; then unzip -q "$zip" -d "$tmp"; else 7z x -y -o"$tmp" "$zip" >/dev/null; fi
pkg="$tmp/rexxnet"
[ -f "$pkg/install.rex" ] && [ -d "$pkg/native/win-x64" ] || { echo "windows-installer.sh: no rexxnet/install.rex or native/win-x64 in $zip" >&2; exit 2; }
for d in "$pkg"/native/*; do [ "$(basename "$d")" = win-x64 ] || rm -rf "$d"; done
mkdir -p "$dest"
out="$(cd "$dest" && pwd)/oorexxnet-$version-setup.exe"
native() { if command -v cygpath >/dev/null; then cygpath -w "$1"; else echo "$1"; fi; }
# "-" options, not "/": Git Bash would take /DVERSION=... for a path
"$makensis" -V2 -DVERSION="$version" -DPKGDIR="$(native "$pkg")" -DLICENSEFILE="$(native "$repo/LICENSE")" \
  -DOUTFILE="$(native "$out")" "$(native "$here/dist/windows/oorexxnet.nsi")"
echo "$out"
