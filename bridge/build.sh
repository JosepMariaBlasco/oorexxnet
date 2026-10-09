#!/usr/bin/env bash
# Builds the ooRexx/.NET bridge (prototype) into OUT (default
# $REXXNET_BUILD/rexxnet, see scripts/platform.sh): Rexx.Net.dll + its
# runtimeconfig (managed), librexxnet.so on Linux / librexxnet.dylib on macOS
# (native; its soname / install name lets a .NET host load it first, from its
# directory, for ooRexx to find), net.cls, CLR.CLS. Needs scripts/setup-env.sh
# first, or an ooRexx 5 with its API headers (found from `rexx` on the PATH;
# REXX_HOME or REXX_INCLUDE to choose) and a .NET 8 SDK or later.
# The managed project is built from a copy (no bin/ obj/ in the project, and
# never an output directory above the sources).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../scripts/platform.sh"
OUT=${1:-$REXXNET_BUILD/rexxnet}
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"
test -f "$REXX_INCLUDE/oorexxapi.h" || { echo "no oorexxapi.h in $REXX_INCLUDE (set REXX_HOME or REXX_INCLUDE)" >&2; exit 1; }
test -f "$HOSTPK/nethost.h" || { echo "no .NET host pack (nethost.h) under $DOTNET_ROOT/packs (set DOTNET_ROOT)" >&2; exit 1; }
rm -f "$OUT/Rexx.Net.dll"                 # a failed build must not leave the old one passing
cp -r "$HERE/managed" "$WORK/managed"
"$DOTNET" build "$WORK/managed" -c Release -o "$OUT" -nologo -v q 2>&1 | grep -E "error|warning CS" || true
test -f "$OUT/Rexx.Net.dll"
native_lib "$OUT/librexxnet.$SOEXT" "$HERE/native/rexxnet.cpp"
cp "$HERE/rexx/net.cls" "$HERE/rexx/CLR.CLS" "$OUT/"
echo "built: $OUT"
