#!/usr/bin/env bash
# The working environment of ooRexx/.NET, on demand:
#   1. ooRexx: the .deb of rexx.epbcn.com (5.3.0 trunk, into /usr/local, API
#      headers included), unless `rexx` is already there;
#   2. .NET SDKs into $DOTNET_DIR with Microsoft's dotnet-install.sh (default
#      channels 8.0 and 10.0, the two LTS; DOTNET_CHANNELS to change them).
# Then:  export DOTNET_ROOT=$DOTNET_DIR PATH=$DOTNET_DIR:$PATH
# Usage: setup-env.sh [--no-dotnet]
set -euo pipefail
DOTNET_DIR=${DOTNET_DIR:-/home/claude/dotnet}
CHANNELS=${DOTNET_CHANNELS:-"8.0 10.0"}
TMP=$(mktemp -d)

if ! command -v rexx >/dev/null 2>&1; then
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
