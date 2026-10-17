#!/usr/bin/env bash
# debug only: lifetime-end.rex with the TestLib that makes it crash on macOS, a core and a backtrace
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../scripts/platform.sh"
OUT=$REXXNET_BUILD/rexxnet
WORK=$(mktemp -d)
cp -r "$HERE/TestLib" "$WORK/"
"$DOTNET" build "$WORK/TestLib" -c Release -o "$WORK/out" -p:RexxNetDir="$OUT" -nologo -v q >/dev/null
T="$WORK/out/TestLib.dll"; E="$HERE/lifetime-end.rex"
cd "$OUT"
sudo sysctl kern.coredump=1 >/dev/null 2>&1 || true
sudo chmod 1777 /cores 2>/dev/null || true
ulimit -c unlimited
for i in 1 2 3; do env "$LIBVAR=." rexx "$E" "$T" > le.out 2>&1; echo "direct $i: rc $? uninits $(grep -c '^uninit' le.out)"; done
for i in 1 2; do env "$LIBVAR=." rexx "$HERE/lifetime.rex" "$T" 2>&1 | grep -E "lifetime:|rc -"; done
ls -la /cores 2>/dev/null | tail -3
core=$(ls -t /cores/core.* 2>/dev/null | head -1)
if [ -n "$core" ]; then
  lldb --batch -c "$core" "$(command -v rexx)" -o "thread list" -o "thread backtrace all" 2>&1 | grep -v "^\s*$" | head -300
fi
echo "--- under lldb, direct"
lldb --batch -o "settings set target.env-vars DYLD_LIBRARY_PATH=$OUT DOTNET_ROOT=$DOTNET_ROOT" \
  -o "process handle SIGUSR1 SIGUSR2 SIGPIPE -n false -p true -s false" -o run \
  -k "thread backtrace all" -k quit -- "$(command -v rexx)" "$E" "$T" 2>&1 | grep -v "^\s*$" | head -200
