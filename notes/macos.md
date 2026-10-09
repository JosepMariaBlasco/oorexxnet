# macOS

*The bridge was written and tested on Linux. This note records what was
changed so that it builds and runs on macOS, and what could only be checked
from Linux: nothing here has run on a Mac yet. The last section lists what
to look at first if something fails there.*

## What differs, and where it is handled

**The scripts** (`scripts/platform.sh`, sourced by every build and test
script) choose the following by `uname -s`:

| | Linux | macOS |
|---|---|---|
| native library | `librexxnet.so` (`g++ -shared`, soname) | `librexxnet.dylib` (`c++ -dynamiclib -std=c++17`, install name) |
| ooRexx's external libraries found through | `LD_LIBRARY_PATH` | `DYLD_LIBRARY_PATH` |
| ooRexx (headers, `librexx`) | from `rexx` on the `PATH`: `/usr/local` for the `.deb` | from `rexx` on the `PATH`: `~/Applications/ooRexx5` by default |
| .NET | `DOTNET_ROOT`, else `dotnet` on the `PATH` | the same (Microsoft's installer: `/usr/local/share/dotnet`) |
| `timeout` | coreutils | Homebrew's `gtimeout`, else none |
| `script` (a terminal for `Console.ReadKey`) | `script -qc "cmd" /dev/null` | `script -q /dev/null cmd` |

The scripts also stay within bash 3.2 (macOS's `/bin/bash`) and POSIX `sed`
(`gen-slots.sh` no longer writes `\t` inside brackets: its output on Linux is
unchanged).

**The native half** (`rexxnet.cpp`, and the smoke tests' `netprobe.cpp` and
`cbprobe.cpp`) needed no change: it uses `dlopen` / `dladdr` / `realpath`,
which macOS has, and no function of `librexx` (only the API's contexts), so
nothing is left undefined at link time. They compile without a warning with
`clang++ -std=c++17 -Wall -Wextra -pedantic -Wgnu -Wvla`. `libnethost.a`
for `osx-arm64` and `osx-x64` (NuGet's `Microsoft.NETCore.App.Host.*`, the
same `nethost.h`) needs only libSystem and libc++, which `c++ -dynamiclib`
links anyway; it was built for macOS 12 or later.

**The install name** is the bare file name (`librexxnet.dylib`), the
equivalent of the Linux soname: when a .NET application hosts ooRexx and
uses `.net` (both ways in one process), it loads `librexxnet` first by its
full path, and ooRexx then `dlopen`s it by name; dyld is expected to match
the name against the already loaded image's install name, as the dynamic
loader matches the soname on Linux.

**The managed half** (`Host/Api.cs`, finding `librexx` when .NET hosts
ooRexx): `REXX_HOME`, then the system's search, then — new, for every
platform — the installation the `rexx` on the `PATH` belongs to
(`<home>/bin`, `<home>/lib`, `<home>/lib64`), then fixed places, which on
macOS are `~/Applications/ooRexx5/lib`, `/Applications/ooRexx5/lib`,
`/opt/homebrew/lib` and `/usr/local/lib`. Two macOS specifics:

- `librexx` refers to `librexxapi` through `@rpath`, and ooRexx's rpath is
  `@executable_path/../lib`, which is right for `rexx` but not for a .NET
  application (the executable is `dotnet`). `librexxapi` is loaded first
  from the same directory, so that dyld finds it already loaded. (On Linux
  ooRexx's rpath is `$ORIGIN/../lib`, relative to the library itself.)
- `pthread_self` (to identify a thread for `RexxSetHalt`) is imported from
  "libc"; on macOS that name is resolved to `/usr/lib/libSystem.B.dylib`.

## Not checked (no Mac here)

1. That everything compiles and links with Apple's clang and the macOS SDK.
2. The install-name match above: phase C with a .NET host (`HostTests`'
   both-ways tests). If `.net` cannot load `rexxnet` there, running with
   `DYLD_LIBRARY_PATH` set to the build directory tells whether this is the
   cause.
3. The `librexxapi` preload: a .NET host failing with "ooRexx 5 is needed
   and was not found" although `librexx.dylib` is there.
4. An ooRexx signed with the hardened runtime (a notarized package) would
   ignore `DYLD_LIBRARY_PATH` and, with library validation, refuse any
   external library not signed by the same team, `librexxnet.dylib`
   included. An ooRexx built from source is not affected.
5. Timings: `HostTests`' phase C cost test compares costs (relative, best of
   three) that were only ever measured on Linux.
