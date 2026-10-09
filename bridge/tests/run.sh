#!/usr/bin/env bash
# Builds the bridge and the test assembly, runs tests/phase1.rex, phase2.rex,
# phase3.rex (ooRexx -> .NET), bothways.rex (phase C: ooRexx as the host, .NET
# calling it back), clr.rex (the CLR.CLS compatibility package), then
# tests/HostTests (.NET -> ooRexx).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${1:-/home/claude/build/rexxnet}
export DOTNET_ROOT=${DOTNET_ROOT:-/home/claude/dotnet} DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
"$HERE/../build.sh" "$OUT" >/dev/null
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cp -r "$HERE/TestLib" "$WORK/"
"$DOTNET_ROOT/dotnet" build "$WORK/TestLib" -c Release -o "$WORK/out" -p:RexxNetDir="$OUT" -nologo -v q >/dev/null
cd "$OUT"
# LD_LIBRARY_PATH relative, as documented (the bridge makes its own path absolute)
rc=0
for t in phase1 phase2 phase3 bothways clr; do
  LD_LIBRARY_PATH=. timeout 300 rexx "$HERE/$t.rex" "$WORK/out/TestLib.dll" || rc=1
done
# .NET -> ooRexx: a .NET application hosting ooRexx (librexx found by Rexx.Net itself)
cp -r "$HERE/HostTests" "$WORK/"
"$DOTNET_ROOT/dotnet" build "$WORK/HostTests" -c Release -o "$WORK/host" -p:RexxNetDir="$OUT" -nologo -v q 2>&1 | grep -E " error " || true
# (phase C: net.cls and rexxnet found through REXXNET_DIR)
REXXNET_DIR="$OUT" timeout 300 "$DOTNET_ROOT/dotnet" "$WORK/host/HostTests.dll" || rc=1
exit $rc
