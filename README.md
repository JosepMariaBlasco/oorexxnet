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
say list[0] list~Count                                            -- 1 2

::requires "net.cls"
```

```csharp
using Rexx.Net;

using var rexx = RexxInterpreter.Create();
int n = rexx.Run<int>("return 6 * 7");      // 42
```

**Status: prototype.** Both directions are built and covered by about 440
automated tests, on Linux, with .NET 8 and .NET 10, against ooRexx 5.3.0
(trunk). Windows has not been tried yet. The design is still being
discussed and parts of the API will change (for instance, .NET arrays will
be indexed from 1 in Rexx).

## Layout

- `bridge/` — the bridge.
  - `managed/` — `Rexx.Net.dll` (C#): both directions; `managed/Host/` is the
    .NET → ooRexx API.
  - `native/rexxnet.cpp` — `librexxnet`, the ooRexx external library that
    hosts the CLR (`nethost` / `hostfxr`).
  - `rexx/net.cls` — the Rexx side (`.net`, `.NetObject` and friends).
  - `build.sh`, `tests/run.sh` — build, and run every test suite.
  - `tests/` — `phase1.rex`, `phase2.rex`, `phase3.rex` (ooRexx → .NET),
    `bothways.rex` (ooRexx as the host, .NET calling back), `HostTests/`
    (.NET → ooRexx).
- `smoke/` — the smallest possible proofs of each mechanism (`smoke/run.sh`,
  `smoke/hostapi/run.sh`).
- `notes/` — the design: `netobject-design.md` (ooRexx → .NET),
  `rexx-from-net-design.md` (.NET → ooRexx, and both ways in one process),
  `decisions-20261008.md` (the initial decisions), `bsf4oorexx-clr.md`
  (notes on BSF4ooRexx's earlier CLR support). Each design note records,
  phase by phase, what was built and where it departed from the plan
  (marked **Δ**).
- `patches/oorexx/` — patches proposed to ooRexx itself (#2106).
- `scripts/setup-env.sh` — installs the environment (see below).

## Building and testing (Linux)

```bash
scripts/setup-env.sh          # ooRexx (a 5.3.0 trunk .deb) and the .NET SDKs 8 and 10
export DOTNET_ROOT=<the SDK directory> PATH=$DOTNET_ROOT:$PATH
bridge/tests/run.sh [OUT]     # builds into OUT and runs all the tests
```

The scripts default to the paths of the environment they were written in
(`/home/claude/dotnet`, `/home/claude/build/rexxnet`); `DOTNET_DIR` /
`DOTNET_ROOT` and the `OUT` argument override them. To use the bridge from
Rexx: `cd OUT && LD_LIBRARY_PATH=. rexx prog.rex`, with
`::requires "net.cls"` in the program.

## Related work

- [BSF4ooRexx](https://sourceforge.net/projects/bsf4oorexx/), the ooRexx–Java
  bridge, whose conventions this bridge follows where it can, and whose
  earlier CLR support (`CLR.CLS`, through jni4net) it supersedes.
- `.JSObject`, the ooRexx–JavaScript bridge of the ooRexx WebAssembly port,
  the model for the Rexx surface.
