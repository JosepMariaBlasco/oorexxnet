#!/usr/bin/env bash
# Packages the bridge as one zip of binaries for every system, for people
# who want to use it without building it: the managed part (Rexx.Net.dll,
# net.cls, CLR.CLS: the same everywhere), each system's native library and
# runtime configuration in native/<rid>/, the installer (dist/install.rex),
# check.rex, the zip's README (dist/README.md), the guide, notes/clr-compat.md
# and the samples that use the bridge from Rexx, in one folder rexxnet/.
#
#   bridge/package.sh [--version V] --managed DIR --native RID=PATH... DEST
#
# --managed: a build folder (build.sh's output: Rexx.Net.dll, its .deps.json
#   and .pdb, its runtime configuration, net.cls, CLR.CLS).
# --native RID=PATH: a system's native library (librexxnet.so, ...dylib),
#   which gets the managed build's runtime configuration; or a folder with
#   the library and its own configuration (build.ps1's rexxnet.dll with
#   Rexx.Net.runtimeconfig.json and Rexx.Net.core.runtimeconfig.json: the
#   Windows Desktop framework). win-x64 also gets System.Speech.dll (from
#   nuget.org: CLR.CLS's speech sample).
# Writes rexxnet-V.zip (default V: YYYYMMDD-COMMIT) into DEST.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(dirname "$here")"
version="" managed="" natives=()
while [ $# -gt 1 ]; do
  case "$1" in
    --version) version="$2"; shift 2 ;;
    --managed) managed="$2"; shift 2 ;;
    --native) natives+=("$2"); shift 2 ;;
    *) echo "package.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done
dest="${1:?package.sh: DEST is needed}"
[ -n "$managed" ] && [ -f "$managed/Rexx.Net.dll" ] || { echo "package.sh: --managed DIR with Rexx.Net.dll" >&2; exit 2; }
[ ${#natives[@]} -gt 0 ] || { echo "package.sh: at least one --native RID=PATH" >&2; exit 2; }
commit="$(git -C "$repo" rev-parse --short HEAD)"
[ -n "$version" ] || version="$(date +%Y%m%d)-$commit"

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
dir="$stage/rexxnet"
mkdir -p "$dir/native" "$dir/docs" "$dir/samples"

# the managed part
for f in Rexx.Net.dll Rexx.Net.deps.json Rexx.Net.pdb net.cls CLR.CLS; do
  cp "$managed/$f" "$dir/"
done
# each system's native library and runtime configuration
for n in "${natives[@]}"; do
  rid="${n%%=*}" path="${n#*=}"
  mkdir -p "$dir/native/$rid"
  if [ -d "$path" ]; then
    cp "$path"/* "$dir/native/$rid/"
  else
    cp "$path" "$dir/native/$rid/"
    cp "$managed/Rexx.Net.runtimeconfig.json" "$dir/native/$rid/"
  fi
  if [ "$rid" = win-x64 ]; then
    # System.Speech: in .NET Framework's GAC once, a NuGet package now
    curl -sSfL --retry 3 -o "$stage/speech.nupkg" \
      https://api.nuget.org/v3-flatcontainer/system.speech/8.0.0/system.speech.8.0.0.nupkg
    unzip -q -j -o "$stage/speech.nupkg" runtimes/win/lib/net8.0/System.Speech.dll -d "$dir/native/$rid"
  fi
done
# the installer, the check, the README, the guide
cp "$here/dist/install.rex" "$here/dist/check.rex" "$dir/"
sed -e "s/@DATE@/$(date +%Y-%m-%d)/" -e "s/@COMMIT@/$commit/" -e "s/@VERSION@/$version/" \
  "$here/dist/README.md" > "$dir/README.md"
cp "$repo/docs/guide.md" "$repo/notes/clr-compat.md" "$dir/docs/"
# the samples that use the bridge from Rexx
cp "$repo/samples/README.md" "$dir/samples/"
for s in rexx windows office libreoffice oorexx-ole oodialog-net; do
  cp -R "$repo/samples/$s" "$dir/samples/"
done
mkdir -p "$dir/samples/powershell"
cp "$repo/samples/powershell/hello.ps1" "$dir/samples/powershell/"

mkdir -p "$dest"
zip="$(cd "$dest" && pwd)/rexxnet-$version.zip"
rm -f "$zip"
(cd "$stage" && zip -qr "$zip" rexxnet)
echo "packaged: $zip"
unzip -l "$zip" | grep -E ' rexxnet/([^/]+|native/[^/]+/[^/]+)$'
