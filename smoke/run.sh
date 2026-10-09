#!/usr/bin/env bash
# Both directions of the bridge, smallest possible (08/10/2026):
#   ooRexx -> .NET: native/netprobe.cpp, an ooRexx external library that hosts
#     the CLR (nethost + hostfxr) and calls managed/Entry.cs, which invokes
#     static .NET methods by reflection: say NetStatic("System.Math", "Max", 3, 7)
#   .NET -> ooRexx: hostrexx/Program.cs runs a Rexx program held in a C# string
#     through RexxStart (librexx), with an argument and a result.
#   .NET -> ooRexx, callbacks: callbacks/ — .NET calls Rexx back
#     synchronously through AttachThread: from another thread while the Rexx
#     thread sits inside a long .NET call, re-entrantly on the same thread (a
#     comparator), from a thread while Rexx code runs, and a Rexx error.
# Needs scripts/setup-env.sh first.  Exit status 1 on any failure.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
export DOTNET_ROOT=${DOTNET_ROOT:-/home/claude/dotnet} DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
DOTNET="$DOTNET_ROOT/dotnet"
WORK=$(mktemp -d)
SRC="$WORK/src"                   # build a copy: no bin/ obj/ in the project
OUT="$WORK/out"                   # (and never an output dir above the sources:
mkdir -p "$SRC" "$OUT"            #  MSBuild leaves out what is inside it)
cp -r "$HERE/managed" "$HERE/native" "$HERE/hostrexx" "$HERE/callbacks" "$SRC/"
fail=0
check() { if grep -qF -- "$2" <<<"$3"; then echo "ok   $1"; else echo "FAIL $1"; echo "$3" | sed 's/^/     /'; fail=1; fi; }

"$DOTNET" build "$SRC/managed" -c Release -o "$OUT" >/dev/null
HOSTPK=$(dirname "$(find "$DOTNET_ROOT/packs" -name nethost.h | sort | tail -1)")
g++ -shared -fPIC -O2 -I/usr/local/include -I"$HOSTPK" "$SRC/native/netprobe.cpp" \
    "$HOSTPK/libnethost.a" -ldl -o "$OUT/libnetprobe.so"
cp "$SRC/native/max.rex" "$OUT/"
r=$(cd "$OUT" && NETPROBE_DIR="$OUT" LD_LIBRARY_PATH="$OUT" rexx max.rex 2>&1 || true)
check "ooRexx -> .NET: System.Math.Max"       "System.Math.Max(3, 7) = 7" "$r"
check "ooRexx -> .NET: a property getter"     "Environment.ProcessorCount =" "$r"
check "ooRexx -> .NET: an exception is SYNTAX" "error: .NET: MissingMethodException" "$r"

r=$("$DOTNET" run --project "$SRC/hostrexx" -c Release 2>&1 || true)
check ".NET -> ooRexx: a program from a C# string" "Rexx says: hello from fromdotnet.rex with 12" "$r"
check ".NET -> ooRexx: argument and result"         "C# got back: 21 144 3" "$r"
check ".NET -> ooRexx: a Rexx error is a C# exception" "C# caught: RexxStart returned -35" "$r"
CB="$WORK/cb"; mkdir -p "$CB"
"$DOTNET" build "$SRC/callbacks/managed" -c Release -o "$CB" >/dev/null
g++ -shared -fPIC -O2 -I/usr/local/include -I"$HOSTPK" "$SRC/callbacks/native/cbprobe.cpp" \
    "$HOSTPK/libnethost.a" -ldl -o "$CB/libcbprobe.so"
cp "$SRC/callbacks/native/callbacks.rex" "$CB/"
r=$(cd "$CB" && CBPROBE_DIR="$CB" LD_LIBRARY_PATH="$CB" timeout 60 rexx callbacks.rex 2>&1 || true)
check "callbacks: from another thread, Rexx inside .NET" "block: during=3 total=3 finished=True otherThread=True" "$r"
check "callbacks: re-entrant, same thread (comparator)"  "sort: apple banana fig pear" "$r"
check "callbacks: from a thread while Rexx code runs"   "async: done 5 of 5, handled 5" "$r"
check "callbacks: a Rexx error reaches .NET and Rexx"   "fail: error: InvalidOperationException: Rexx: 98: a Rexx error in a callback" "$r"
exit $fail
