#!/usr/bin/env bash
# Builds the ooRexx/.NET bridge (prototype) into OUT (default
# /home/claude/build/rexxnet): Rexx.Net.dll + its runtimeconfig (managed),
# librexxnet.so (native; its soname lets a .NET host load it first, from its
# directory, for ooRexx to find), net.cls. Needs scripts/setup-env.sh first.
# The managed project is built from a copy (no bin/ obj/ in the project, and
# never an output directory above the sources).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-/home/claude/build/rexxnet}
export DOTNET_ROOT=${DOTNET_ROOT:-/home/claude/dotnet} DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
DOTNET="$DOTNET_ROOT/dotnet"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"
rm -f "$OUT/Rexx.Net.dll"                 # a failed build must not leave the old one passing
cp -r "$HERE/managed" "$WORK/managed"
"$DOTNET" build "$WORK/managed" -c Release -o "$OUT" -nologo -v q 2>&1 | grep -E "error|warning CS" || true
test -f "$OUT/Rexx.Net.dll"
HOSTPK=$(dirname "$(find "$DOTNET_ROOT/packs" -name nethost.h | sort | tail -1)")
g++ -shared -fPIC -O2 -Wall -I/usr/local/include -I"$HOSTPK" "$HERE/native/rexxnet.cpp" \
    "$HOSTPK/libnethost.a" -ldl -Wl,-soname,librexxnet.so -o "$OUT/librexxnet.so"
cp "$HERE/rexx/net.cls" "$OUT/"
echo "built: $OUT"
