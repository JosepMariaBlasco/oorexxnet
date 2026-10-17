#!/usr/bin/env bash
# debug only: lifetime.rex as run.sh runs it, then one difference at a time
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/platform.sh"
OUT=$REXXNET_BUILD/rexxnet
type timeout; echo "LIBVAR=$LIBVAR"
WORK=$(mktemp -d)
cp -r "$HERE/TestLib" "$WORK/"
"$DOTNET" build "$WORK/TestLib" -c Release -o "$WORK/out" -p:RexxNetDir="$OUT" -nologo -v q >/dev/null
"$DOTNET" build "$HERE/TestLib" -c Release -o "$RUNNER_TEMP/tl" -p:RexxNetDir="$OUT" -nologo -v q >/dev/null
echo "WORK=$WORK"
cd "$OUT"
r() { echo "$1: $(eval "$2" 2>&1 | grep -E 'lifetime:|rc -' | tr '\n' ' ')"; }
for i in 1 2 3; do
  r "as run.sh $i"          'timeout 300 env "$LIBVAR=." rexx "$HERE/lifetime.rex" "$WORK/out/TestLib.dll"'
  r "no timeout $i"         'env "$LIBVAR=." rexx "$HERE/lifetime.rex" "$WORK/out/TestLib.dll"'
  r "other TestLib $i"      'timeout 300 env "$LIBVAR=." rexx "$HERE/lifetime.rex" "$RUNNER_TEMP/tl/TestLib.dll"'
  r "absolute lib path $i"  'timeout 300 env "$LIBVAR=$OUT" rexx "$HERE/lifetime.rex" "$WORK/out/TestLib.dll"'
done
