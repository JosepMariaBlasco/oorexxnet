#!/usr/bin/env bash
# Makes the NuGet package Rexx.Net (and its symbols, .snupkg) into DEST
# (default: the current directory): the managed assembly, with net.cls and
# CLR.CLS built in, and the native library rexxnet for this platform (built
# here) plus any other given with --native RID=FILE (a rexxnet.dll built on
# Windows by build.ps1, a librexxnet.dylib built on macOS...), into
# runtimes/RID/native/.
#
#   bridge/pack.sh [--version V] [--native win-x64=path/rexxnet.dll ...] [DEST]
#
# The version defaults to the project's VersionPrefix with a suffix
# preview.YYYYMMDD. Needs what build.sh needs.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../scripts/platform.sh"
VERSION=""; NATIVES=(); DEST=.
while [ $# -gt 0 ]; do
  case $1 in
    --version) VERSION=$2; shift 2 ;;
    --native) NATIVES+=("$2"); shift 2 ;;
    -*) echo "unknown option $1" >&2; exit 1 ;;
    *) DEST=$1; shift ;;
  esac
done
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# this platform's rexxnet, built as build.sh builds it
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) RID=linux-x64 ;; Linux-aarch64) RID=linux-arm64 ;;
  Darwin-arm64) RID=osx-arm64 ;; Darwin-x86_64) RID=osx-x64 ;;
  *) echo "unknown platform $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac
"$HERE/build.sh" "$WORK/build" >/dev/null
mkdir -p "$WORK/natives/$RID/native"
cp "$WORK/build/librexxnet.$SOEXT" "$WORK/natives/$RID/native/"
for n in ${NATIVES[@]+"${NATIVES[@]}"}; do
  rid=${n%%=*}; file=${n#*=}
  test -f "$file" || { echo "no such file: $file" >&2; exit 1; }
  mkdir -p "$WORK/natives/$rid/native"
  cp "$file" "$WORK/natives/$rid/native/"
done

cp -r "$HERE/managed" "$HERE/rexx" "$HERE/nuget" "$WORK/"
if [ -n "$VERSION" ]; then V=(-p:Version="$VERSION"); else V=(--version-suffix "preview.$(date +%Y%m%d)"); fi
mkdir -p "$DEST"
"$DOTNET" pack "$WORK/managed" -c Release -o "$DEST" -nologo -v q "${V[@]}" \
  -p:RexxNetNatives="$WORK/natives" 2>&1 | grep -E "error|warning|Successfully" || true
ls "$DEST"/Rexx.Net.*.nupkg >/dev/null
echo "natives: $(cd "$WORK/natives" && echo */native/*)"
ls -1 "$DEST"/Rexx.Net.*nupkg
