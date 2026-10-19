#!/usr/bin/env bash
# The working environment of ooRexx/.NET, on demand:
#   1. ooRexx: the .deb of ooRexx's own builds on SourceForge (5.3.0 trunk,
#      into /usr/local, API headers included), pinned to the revision the CI
#      uses (OOREXX_REV in .github/workflows/build.yml; the environment
#      variable OOREXX_REV overrides it), unless `rexx` is already there (a
#      warning if it is older); on macOS (or any system without dpkg) ooRexx 5
#      must be installed beforehand, `rexx` on the PATH;
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
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REV=${OOREXX_REV:-$(sed -n 's/^ *OOREXX_REV: *"\([0-9]*\)".*/\1/p' "$ROOT/.github/workflows/build.yml" | head -1)}
[ -n "$REV" ] || { echo "OOREXX_REV not found in build.yml" >&2; exit 1; }
SF=https://downloads.sourceforge.net/project/oorexx/oorexx/5.3.0beta

if ! command -v rexx >/dev/null 2>&1; then
  if ! command -v dpkg >/dev/null 2>&1; then
    echo "ooRexx 5 (r$REV or later) is needed: install it and put its bin/ on the PATH" >&2; exit 1
  fi
  echo "== ooRexx r$REV (.deb, SourceForge)"
  curl -fsSL --retry 3 -o "$TMP/oorexx.deb" "$SF/oorexx-5.3.0-$REV.ubuntu2404.x86_64.deb"
  dpkg -i "$TMP/oorexx.deb" >/dev/null && ldconfig
fi
rexx -v 2>&1 | head -1
have=$(rexx -v 2>&1 | sed -n 's/.* r\([0-9]*\).*/\1/p' | head -1)
if [ -n "$have" ] && [ "$have" -lt "$REV" ]; then
  echo "warning: ooRexx r$have is older than r$REV, the bridge's minimum" >&2
fi

[[ "${1:-}" == "--no-dotnet" ]] && exit 0
echo "== .NET SDKs: $CHANNELS -> $DOTNET_DIR"
curl -fsSL -o "$TMP/dotnet-install.sh" https://dot.net/v1/dotnet-install.sh
for ch in $CHANNELS; do
  bash "$TMP/dotnet-install.sh" --channel "$ch" --install-dir "$DOTNET_DIR" >/dev/null
done
DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 "$DOTNET_DIR/dotnet" --list-sdks
echo "== done: export DOTNET_ROOT=$DOTNET_DIR PATH=$DOTNET_DIR:\$PATH"
