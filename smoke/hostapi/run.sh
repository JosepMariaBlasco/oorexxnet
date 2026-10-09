#!/usr/bin/env bash
# Builds and runs the hostapi probe (.NET -> ooRexx through the object API,
# no native shim). Needs the bridge built (bridge/build.sh) for "bothways".
# Built from a copy (no bin/ obj/ in the project).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/platform.sh"
OUT=${1:-$REXXNET_BUILD/hostapi}
RX=${REXXNET_DIR:-$REXXNET_BUILD/rexxnet}
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cp "$HERE"/*.cs "$HERE"/*.csproj "$WORK/"
# the tables' layout (instance, thread, exit context, I/O redirector): one pointer-sized slot each
"$CXX" -I"$REXX_INCLUDE" -o "$WORK/layout" "$HERE/layout.cpp"
"$WORK/layout" | awk '{split($1,a,".")} a[2]!="" {i[a[1]]++; if ($2 != 8*(i[a[1]]-1)) bad++}
                      END {if (bad) {print "FAIL layout: " bad " members off their slot"; exit 1}
                           print "ok   layout: every member of the four tables in its slot"}'
"$DOTNET" build "$WORK" -c Release -o "$OUT" -p:RexxNetDir="$RX" -nologo -v q 2>&1 | grep -E "error|warning CS" || true
env "$LIBVAR=$RX:$REXX_LIB" REXXNET_DIR="$RX" "$DOTNET" "$OUT/HostApi.dll"
