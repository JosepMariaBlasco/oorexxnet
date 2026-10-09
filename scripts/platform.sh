# shellcheck shell=bash
# What differs between Linux and macOS, for the build and test scripts
# (sourced, not run: `. "$ROOT/scripts/platform.sh"`). Sets:
#
#   OS              Linux | Darwin
#   DOTNET_ROOT     the .NET installation (exported); DOTNET its `dotnet`
#   REXXNET_BUILD   where builds go (default /home/claude/build if that is
#                   writable, else ~/build); the bridge goes to $REXXNET_BUILD/rexxnet
#   REXX_HOME       ooRexx's installation: from `rexx` on the PATH (exported)
#   REXX_INCLUDE    its API headers (oorexxapi.h); REXX_LIB its libraries
#   SOEXT           so | dylib
#   LIBVAR          LD_LIBRARY_PATH | DYLD_LIBRARY_PATH (where ooRexx's
#                   external libraries and librexx are found by name)
#   HOSTPK          nethost.h and libnethost.a, from the SDK's host pack
#
# and the functions native_lib OUT SRC... (an ooRexx external library hosting
# .NET: nethost linked in, its own name as soname / install name), timeout
# (gtimeout, or none, where coreutils' is missing) and run_tty SECS CMD ARGS...
# (CMD with a terminal, through script(1), stopped after SECS seconds). Every variable can be set
# beforehand to override it.

OS=$(uname -s)

# A path with its symbolic links followed (no `readlink -f` before macOS 12.3).
resolve_path() {
  local p=$1 t
  while [ -L "$p" ]; do
    t=$(readlink "$p")
    case $t in /*) p=$t ;; *) p=$(dirname "$p")/$t ;; esac
  done
  echo "$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"
}

# .NET: DOTNET_ROOT, else scripts/setup-env.sh's places, else `dotnet` on the
# PATH, else where Microsoft's installers put it.
if [ -z "${DOTNET_ROOT:-}" ]; then
  if [ -x /home/claude/dotnet/dotnet ]; then DOTNET_ROOT=/home/claude/dotnet
  elif [ -x "$HOME/.dotnet/dotnet" ]; then DOTNET_ROOT=$HOME/.dotnet
  elif command -v dotnet >/dev/null 2>&1; then DOTNET_ROOT=$(dirname "$(resolve_path "$(command -v dotnet)")")
  elif [ -x /usr/local/share/dotnet/dotnet ]; then DOTNET_ROOT=/usr/local/share/dotnet
  else DOTNET_ROOT=/usr/share/dotnet
  fi
fi
export DOTNET_ROOT DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
DOTNET="$DOTNET_ROOT/dotnet"

if [ -z "${REXXNET_BUILD:-}" ]; then
  if [ -d /home/claude ] && [ -w /home/claude ]; then REXXNET_BUILD=/home/claude/build
  else REXXNET_BUILD="$HOME/build"
  fi
fi

# ooRexx: REXX_HOME, else the installation `rexx` on the PATH belongs to
# (/usr/local on Linux; ~/Applications/ooRexx5 by default on macOS).
if [ -z "${REXX_HOME:-}" ]; then
  if command -v rexx >/dev/null 2>&1; then REXX_HOME=$(dirname "$(dirname "$(resolve_path "$(command -v rexx)")")")
  else REXX_HOME=/usr/local
  fi
fi
export REXX_HOME
REXX_INCLUDE=${REXX_INCLUDE:-$REXX_HOME/include}
if [ -z "${REXX_LIB:-}" ]; then
  REXX_LIB=$REXX_HOME/lib
  if ! ls "$REXX_LIB"/librexx.* >/dev/null 2>&1 && [ -d "$REXX_HOME/lib64" ]; then REXX_LIB=$REXX_HOME/lib64; fi
fi

HOSTPK=${HOSTPK:-$(dirname "$(find "$DOTNET_ROOT/packs" -name nethost.h 2>/dev/null | sort | tail -1)")}

if [ "$OS" = Darwin ]; then
  SOEXT=dylib
  LIBVAR=DYLD_LIBRARY_PATH
  CXX=${CXX:-c++}
  # -dynamiclib: an ooRexx external library is a dylib (ooRexx dlopen()s
  # "lib<name>.dylib"); its install name is its bare file name, as a Linux
  # soname, so that a .NET host that loaded it first by its path (phase C) is
  # the one ooRexx's dlopen() by name finds.
  native_lib() {
    local out=$1; shift
    "$CXX" -dynamiclib -fPIC -O2 -Wall -std=c++17 -I"$REXX_INCLUDE" -I"$HOSTPK" "$@" \
      "$HOSTPK/libnethost.a" -Wl,-install_name,"$(basename "$out")" -o "$out"
  }
else
  SOEXT=so
  LIBVAR=LD_LIBRARY_PATH
  CXX=${CXX:-g++}
  native_lib() {
    local out=$1; shift
    "$CXX" -shared -fPIC -O2 -Wall -I"$REXX_INCLUDE" -I"$HOSTPK" "$@" \
      "$HOSTPK/libnethost.a" -ldl -Wl,-soname,"$(basename "$out")" -o "$out"
  }
fi

# coreutils' timeout: macOS has none (Homebrew's coreutils: gtimeout).
if ! command -v timeout >/dev/null 2>&1; then
  if command -v gtimeout >/dev/null 2>&1; then timeout() { gtimeout "$@"; }
  else timeout() { shift; "$@"; }
  fi
fi

# A command with a terminal (Console.ReadKey needs one): util-linux's script
# takes the command as a string, BSD's as arguments.
run_tty() {
  local secs=$1; shift
  if [ "$OS" = Darwin ]; then timeout "$secs" script -q /dev/null "$@"
  else timeout "$secs" script -qc "$*" /dev/null
  fi
}
