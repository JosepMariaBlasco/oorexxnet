#!/usr/bin/env bash
# Runs the portable samples of BSF4ooRexx's CLR.CLS (by Manuel Raffel and
# Adrian Baginski) on this bridge's CLR.CLS compatibility package, unchanged.
#
#   bridge/tests/clr-samples.sh [samples-dir] [build-dir]
#
# samples-dir: a copy of BSF4ooRexx's samples/clr (with raffel/ and
# baginski/); fetched with svn export when not given. build-dir: the
# bridge's build (default /home/claude/build/rexxnet; bridge/build.sh first).
# Not run: the Windows-only samples (WinForms, the event log, system events
# and sounds, speech), 08-WebClient (needs the internet), 14-menu and
# 16-GeoLocation (not in .NET Core). See notes/clr-compat.md.
set -uo pipefail
SAMPLES=${1:-}
OUT=${2:-/home/claude/build/rexxnet}
export DOTNET_ROOT=${DOTNET_ROOT:-/home/claude/dotnet} DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
export LD_LIBRARY_PATH="$OUT" REXX_PATH="$OUT"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
if [ -z "$SAMPLES" ]; then
  svn export -q https://svn.code.sf.net/p/bsf4oorexx/code/trunk/bsf4oorexx.dev/oorexx.net/samples/clr "$WORK/clr" || exit 2
  SAMPLES="$WORK/clr"
else
  cp -r "$SAMPLES" "$WORK/clr"; SAMPLES="$WORK/clr"     # (the samples write files where they run)
fi
fails=0; count=0
check() {   # name, output file, text the output must contain
  count=$((count + 1))
  if grep -qF -- "$3" "$2"; then echo "ok   $1"; else echo "FAIL $1 (no \"$3\")"; sed 's/^/     | /' "$2" | tail -5; fails=$((fails + 1)); fi
}
cd "$SAMPLES/raffel"
timeout 60 rexx 01-helloworld-clr.rxj > "$WORK/01.out" 2>&1
check "raffel/01-helloworld" "$WORK/01.out" "Hello World from ooRexx.NET"
(timeout 60 rexx 05-server-clr.rxj > "$WORK/05s.out" 2>&1 &)
sleep 4
echo "a message from the client" | timeout 60 rexx 05-client-clr.rxj > "$WORK/05c.out" 2>&1
sleep 2
check "raffel/05-client" "$WORK/05c.out" "Message was sent to server."
check "raffel/05-server" "$WORK/05s.out" "[a message from the client]"
cd "$SAMPLES/baginski"
timeout 60 rexx 02-streamwriter.rxj > "$WORK/02.out" 2>&1
check "baginski/02-streamwriter" "$WORK/02.out" "The textfile was successfully created."
timeout 60 rexx 03-streamreader.rxj > "$WORK/03.out" 2>&1
check "baginski/03-streamreader (ReadLine)" "$WORK/03.out" "[~~First Heading~~]"
check "baginski/03-streamreader (Read, ToChar)" "$WORK/03.out" "This ooRexx.NET application will create"
# 07: the MAC is computed and written; its last step opens the file with the
# default editor (Process.Start(file): Windows; on Linux .NET tries to run it)
timeout 60 rexx 07-MAC.rxj > "$WORK/07.out" 2>&1
check "baginski/07-MAC (the MAC)" "07-MAC.txt" "MAC for this message: 98-8C-DA-05-2E-6B-D0-BA-50-8F-4D-A4-BA-D0-1F-C3"
check "baginski/07-MAC (the static Process.Start through an instance)" "$WORK/07.out" "An error occurred trying to start process"
# 09: Console.ReadKey needs a terminal: script(1) gives it one; a key ends it
(sleep 3; printf 'x') | timeout 30 script -qc "rexx 09-clock.rxj" /dev/null > "$WORK/09.out" 2>&1
check "baginski/09-clock (DateTime~Now through an instance)" "$WORK/09.out" "The current time is ["
count=$((count + 1))
if [ "$(grep -c 'The current time is' "$WORK/09.out")" -ge 2 ] && ! grep -q 'Error' "$WORK/09.out"; then
  echo "ok   baginski/09-clock (CLRThread, ReadKey, Environment.Exit)"
else echo "FAIL baginski/09-clock (CLRThread)"; tail -5 "$WORK/09.out"; fails=$((fails + 1)); fi
if [ $fails -eq 0 ]; then echo "CLR.CLS samples: all $count checks passed"; else echo "CLR.CLS samples: $fails of $count checks FAILED"; fi
[ $fails -eq 0 ]
