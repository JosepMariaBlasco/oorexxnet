#!/usr/bin/env bash
# The working environment of ooRexx/.NET, on demand:
#   1. ooRexx: the .deb of rexx.epbcn.com (5.3.0 trunk, into /usr/local, API
#      headers included), unless `rexx` is already there; on macOS (or any
#      system without dpkg) ooRexx 5 must be installed beforehand, `rexx` on
#      the PATH;
#   2. .NET SDKs into $DOTNET_DIR (default /home/claude/dotnet where that is
#      writable, else ~/.dotnet) with Microsoft's dotnet-install.sh (default
#      channels 8.0 and 10.0, the two LTS; DOTNET_CHANNELS to change them).
# Then:  export DOTNET_ROOT=$DOTNET_DIR PATH=$DOTNET_DIR:$PATH
# Usage: setup-env.sh [--no-dotnet]
set -euo pipefail
if [ -z "${DOTNET_DIR:-}" ]; then
  if [ -d /home/claude ] && [ -w /home/claude ]; then DOTNET_DIR=/home/claude/dotnet; else DOTNET_DIR=$HOME/.dotnet; fi
fi
CHANNELS=${DOTNET_CHANNELS:-"8.0 10.0"}
TMP=$(mktemp -d)

if ! command -v rexx >/dev/null 2>&1; then
  if ! command -v dpkg >/dev/null 2>&1; then
    echo "ooRexx 5 is needed: install it and put its bin/ on the PATH" >&2; exit 1
  fi
  echo "== ooRexx (.deb)"
  curl -fsS -o "$TMP/oorexx.deb" https://rexx.epbcn.com/oorexx-latest.deb
  dpkg -i "$TMP/oorexx.deb" >/dev/null && ldconfig
fi
rexx -v 2>&1 | head -1

[[ "${1:-}" == "--no-dotnet" ]] && exit 0
echo "== .NET SDKs: $CHANNELS -> $DOTNET_DIR"
curl -fsSL -o "$TMP/dotnet-install.sh" https://dot.net/v1/dotnet-install.sh
for ch in $CHANNELS; do
  bash "$TMP/dotnet-install.sh" --channel "$ch" --install-dir "$DOTNET_DIR" >/dev/null
done
DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 "$DOTNET_DIR/dotnet" --list-sdks
echo "== done: export DOTNET_ROOT=$DOTNET_DIR PATH=$DOTNET_DIR:\$PATH"
