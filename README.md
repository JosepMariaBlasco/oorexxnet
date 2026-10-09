# ooRexx/.NET

A bidirectional bridge between [ooRexx](https://sourceforge.net/projects/oorexx/)
and .NET (the CLR: C#, F#, VB, PowerShell).

- **ooRexx → .NET**: a Rexx program creates .NET objects, calls their
  methods, reads and sets their properties and handles their events, as
  Rexx objects (`.net`, `.NetObject`).
- **.NET → ooRexx**: any .NET application runs Rexx code and uses Rexx
  objects as .NET objects (`RexxInterpreter`, `RexxObject`), provides
  `ADDRESS` environments and redirects Rexx's I/O.
- **Both ways in one process**: .NET objects go to Rexx and come back as
  themselves, and the same for Rexx objects going to .NET.

```rexx
say .net~System~Math~Max(3, 7)                                    -- 7
list = .net~type("System.Collections.Generic.List<int>")~new
list~Add(3); list~Add(1); list~Sort
say list[0] list~Count                                            -- 1 2  (a List: as .NET)
bytes = .net~System~Text~Encoding~UTF8~GetBytes("abc")           -- a .NET byte[]
say bytes[1] bytes~items                                          -- 97 3  (an array: as a Rexx Array)

::requires "net.cls"
```

```csharp
using Rexx.Net;

using var rexx = RexxInterpreter.Create();
int n = rexx.Run<int>("return 6 * 7");      // 42
```

**Status: prototype.** Both directions are built and covered by more than 500
automated tests, on Linux, with .NET 8 and .NET 10, against ooRexx 5.3.0
(trunk); on Windows too (MSVC, .NET 10: every suite and every example of
the guide pass, and every sample of BSF4ooRexx's `CLR.CLS` that .NET still
supports, Windows Forms and common dialogs included). The build and test scripts also support macOS, not yet
tried there. The design is still being
discussed and parts of the API may change.

**Start with the guide: [`docs/guide.md`](docs/guide.md)** — setting up, then
both directions feature by feature, every example run and checked
(`docs/check-guide.rex`).

## Layout

- `bridge/` — the bridge.
  - `managed/` — `Rexx.Net.dll` (C#): both directions; `managed/Host/` is the
    .NET → ooRexx API.
  - `native/rexxnet.cpp` — `librexxnet`, the ooRexx external library that
    hosts the CLR (`nethost` / `hostfxr`).
  - `rexx/net.cls` — the Rexx side (`.net`, `.NetObject` and friends).
  - `rexx/CLR.CLS` — a compatibility package: programs written for
    BSF4ooRexx's `CLR.CLS` run unchanged (see `notes/clr-compat.md`).
  - `build.sh`, `tests/run.sh` — build, and run every test suite (Windows:
    `build.ps1`, `tests/run.ps1`).
  - `pack.sh` — the NuGet package `Rexx.Net` (`nuget/README.md` is its
    page); `package-windows.ps1` — a zip of Windows binaries
    (`dist/windows/`: its README and `check.rex`).
  - `tests/` — `phase1.rex`, `phase2.rex`, `phase3.rex` (ooRexx → .NET),
    `bothways.rex` (ooRexx as the host, .NET calling back), `clr.rex` (the
    `CLR.CLS` package), `HostTests/` (.NET → ooRexx); `clr-samples.sh` runs
    `CLR.CLS`'s own portable samples.
- `samples/powershell/hello.ps1` — PowerShell 7 hosting ooRexx.
- `smoke/` — the smallest possible proofs of each mechanism (`smoke/run.sh`,
  `smoke/hostapi/run.sh`).
- `notes/` — the design: `netobject-design.md` (ooRexx → .NET),
  `rexx-from-net-design.md` (.NET → ooRexx, and both ways in one process),
  `decisions-20261008.md` (the initial decisions), `bsf4oorexx-clr.md`
  (notes on BSF4ooRexx's earlier CLR support), `clr-compat.md` (the
  `CLR.CLS` compatibility package), `macos.md` (the macOS port: what was
  done, what is still to be confirmed on a Mac). Each design note records,
  phase by phase, what was built and where it departed from the plan
  (marked **Δ**).
- `docs/` — `guide.md` (the user's guide) and `check-guide.rex` (runs its
  examples and compares their output).
- `patches/oorexx/` — patches proposed to ooRexx itself (#2106).
- `scripts/setup-env.sh` — installs the environment (see below);
  `scripts/platform.sh` — what differs between Linux and macOS, for the
  scripts.

## Building and testing (Linux, macOS, Windows)

```bash
sudo scripts/setup-env.sh --no-dotnet       # ooRexx 5.3.0 trunk (.deb), if there is no rexx yet
DOTNET_DIR=~/dotnet scripts/setup-env.sh    # the .NET SDKs 8 and 10 into ~/dotnet
export DOTNET_ROOT=~/dotnet PATH=~/dotnet:$PATH
bridge/tests/run.sh ~/rexxnet               # builds into ~/rexxnet and runs all the tests
```

The scripts find ooRexx from the `rexx` on the `PATH` (its installation's
`include/` and `lib/`; `REXX_HOME`, or `REXX_INCLUDE` / `REXX_LIB`, to
choose another) and .NET from `DOTNET_ROOT`, else `dotnet` on the `PATH`.
Builds go to `~/build/rexxnet` (`/home/claude/build/rexxnet` in the
environment the project is developed in) unless an `OUT` argument says
otherwise (`REXXNET_BUILD` changes `~/build`). To use the bridge from Rexx:
`cd OUT && LD_LIBRARY_PATH=. rexx prog.rex` (macOS: `DYLD_LIBRARY_PATH`),
with `::requires "net.cls"` in the program.

**macOS** (written for it, not tried yet): ooRexx 5 installed (by default
it goes to `~/Applications/ooRexx5`) with its `bin/` on the `PATH`; the
Xcode command line tools (`clang`); a .NET 8 SDK or later (Microsoft's
installer, or `scripts/setup-env.sh`, which puts the SDKs in `~/.dotnet`).
Then `bridge/tests/run.sh` as above; the native library is
`librexxnet.dylib`. `clr-samples.sh` fetches the samples with `svn`
(Homebrew's `subversion`), or takes a directory of them; the timeouts use
coreutils' `gtimeout` when there is one.

**Windows**: ooRexx 5, 64-bit, with
`rexx.exe` on the `PATH` (its `api\` folder has the headers); a .NET 8 SDK
or later; Visual Studio or its Build Tools with "Desktop development with
C++" (`cl.exe`, found through `vswhere` when it is not on the `PATH`).
`bridge\build.ps1` builds into `%USERPROFILE%\build\rexxnet` (`-Out` to
change it) and `bridge\tests\run.ps1` runs the same suites as `run.sh`:

```bat
powershell -ExecutionPolicy Bypass -File bridge\tests\run.ps1
```

From Rexx, `rexxnet.dll` is found through the `PATH`. The guide's examples:
`rexx docs\check-guide.rex` (on every platform: `rexx docs/check-guide.rex`).
CLR.CLS's Windows samples (Windows Forms, `MessageBox`, sounds, speech...):
`bridge\tests\clr-samples-windows.ps1`, interactive. The smoke tests and
`clr-samples.sh` are Linux and macOS only.

## Packaging

- **NuGet** (`bridge/pack.sh [--native RID=FILE ...] [DEST]`): the package
  `Rexx.Net`, for .NET applications that run Rexx code. The assembly
  carries `net.cls` and `CLR.CLS` inside it, so the Rexx code it runs can
  `::requires "net.cls"` without any file; the native library `rexxnet`
  (needed only for `.net` in that Rexx code) goes in `runtimes/<rid>/native/`
  for this platform and for any other given (a `rexxnet.dll` from
  `build.ps1`, say). An installed ooRexx 5 is a prerequisite.
- **Windows binaries** (`powershell -ExecutionPolicy Bypass -File
  bridge\package-windows.ps1`): a zip with everything a Rexx programmer
  needs to try the bridge without building it.

## Related work

- [BSF4ooRexx](https://sourceforge.net/projects/bsf4oorexx/), the ooRexx–Java
  bridge, whose conventions this bridge follows where it can, and whose
  earlier CLR support (`CLR.CLS`, through jni4net) it supersedes: programs
  written for `CLR.CLS` run on this bridge through `rexx/CLR.CLS`.
- `.JSObject`, the ooRexx–JavaScript bridge of the ooRexx WebAssembly port,
  the model for the Rexx surface.
