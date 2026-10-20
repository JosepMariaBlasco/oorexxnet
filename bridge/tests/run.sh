#!/usr/bin/env bash
# Builds the bridge and the test assembly, runs tests/phase1.rex, phase2.rex,
# phase3.rex (ooRexx -> .NET), bothways.rex (phase C: ooRexx as the host, .NET
# calling it back), clr.rex (the CLR.CLS compatibility package), then
# tests/HostTests (.NET -> ooRexx).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/platform.sh"
OUT=${1:-$REXXNET_BUILD/rexxnet}
"$HERE/../build.sh" "$OUT" >/dev/null
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cp -r "$HERE/TestLib" "$WORK/"
"$DOTNET" build "$WORK/TestLib" -c Release -o "$WORK/out" -p:RexxNetDir="$OUT" -nologo -v q >/dev/null
cd "$OUT"
# the library path relative, as documented (the bridge makes its own path absolute)
rc=0
for t in probe phase1 phase2 phase3 bothways clr eventthread extend lifetime; do
  timeout -k 10 300 env "$LIBVAR=." rexx "$HERE/$t.rex" "$WORK/out/TestLib.dll" || rc=1
done
# .NET -> ooRexx: a .NET application hosting ooRexx (librexx found by Rexx.Net itself)
cp -r "$HERE/HostTests" "$WORK/"
"$DOTNET" build "$WORK/HostTests" -c Release -o "$WORK/host" -p:RexxNetDir="$OUT" -nologo -v q 2>&1 | grep -E " error " || true
# (phase C: net.cls and rexxnet found through REXXNET_DIR)
REXXNET_DIR="$OUT" timeout -k 10 300 "$DOTNET" "$WORK/host/HostTests.dll" || rc=1
# ooRexx's own .cls files with its bin folder off the PATH (librexx through REXX_HOME)
NOBIN=$(printf %s "$PATH" | tr ':' '\n' | grep -v -x -F -e "$REXX_HOME/bin" -e "$(resolve_path "$REXX_HOME/bin")" | paste -sd: -)
REXXNET_DIR="$OUT" PATH="$NOBIN" timeout -k 10 120 "$DOTNET" "$WORK/host/HostTests.dll" classpath-child || rc=1
exit $rc
