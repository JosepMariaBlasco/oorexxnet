# ooRexx/.NET — binaries (prototype)

Version @VERSION@, built @DATE@ from
<https://github.com/JosepMariaBlasco/oorexxnet>, commit @COMMIT@. License:
Apache 2.0 (System.Speech.dll: MIT, Microsoft).

One package for Windows (x64), Linux (x64) and macOS (Apple silicon):
`native/` holds each system's part, and the installer takes the one for
yours. Nothing needs to be compiled.

## What you need

- **ooRexx 5.3.0 r13289 or later, 64-bit** (a trunk build until 5.3.0 is
  released), with `rexx -v` working in a terminal. r13288 is the first with
  command environments written in Rexx (`.CommandHandler`, RFE #882), which
  the bridge's command environments are made with. r13286 fixes a heap
  corruption when native code asks about numbers while other threads run
  Rexx (ooRexx bug #2122). r13278 is the first with
  `.LogicalWrapper` (`logicalwrapper.cls`), the class of the booleans that
  cross between Rexx and .NET. r13274 and r13275 fix
  crashes with command environments and threads (ooRexx bugs #2111, #2112:
  adding an environment from .NET, or `ADDRESS` to one not yet known, while
  other threads run Rexx); r13270, a crash in `SELECT CASE` (#2114) that the
  installer and the samples could meet; on Linux, r13267 made calls into
  ooRexx from .NET much faster (#2106).
- **.NET 8 or later** (64-bit): the runtime is enough.
  - Windows: the **.NET Desktop Runtime, x64**, which adds Windows Forms
    (dialogs, the samples' windows) to the base runtime:
    <https://dotnet.microsoft.com/download> → your newest .NET → ".NET
    Desktop Runtime", Windows, x64. (Not .NET Framework 4.x: that is the
    old one, which the bridge does not use. An x86 .NET is invisible to a
    64-bit ooRexx.)
  - Linux: your distribution's `dotnet-runtime-8.0` (or later) package, or
    Microsoft's. Installed in your home (`~/.dotnet`)? Set `DOTNET_ROOT` to
    that folder.
  - macOS: the installer from <https://dotnet.microsoft.com/download>.

`dotnet --list-runtimes` shows what is installed.

## Installing

(On Windows, the release's `oorexxnet-…-setup.exe` does all this with a
wizard, and adds Start menu shortcuts and an uninstaller in Settings > Apps.)

Unzip anywhere, open a terminal in the unzipped folder `rexxnet` and run

    rexx install

It puts the bridge into the ooRexx that runs it (Windows: beside
`rexx.exe`; Linux and macOS: in ooRexx's `lib/oorexxnet`, linked into its
`lib` and `bin`), copies the samples into ooRexx's samples folder, under
`dotnet`, checks it all from another folder with no variables set, and ends
with `ooRexx/.NET: installed and OK`. The unzipped folder is then no longer
needed.

- ooRexx in `C:\Program Files\ooRexx` (Windows' default) needs an
  administrator: open the terminal **as administrator** (right-click,
  "Run as administrator"). On Linux and macOS, an ooRexx in a system folder
  (`/usr`, `/usr/local`) needs `sudo rexx install`.
- A portable ooRexx (unzipped, its `bin` on the `PATH`) needs no
  administrator.
- `rexx oorexxnet-uninstall status`, from any folder, shows what was
  installed and where, and which `CLR.CLS` a program finds;
  `rexx oorexxnet-uninstall` removes exactly what was installed.
- **Updating**: run the new version's `rexx install`; it replaces the old
  one.
- **BSF4ooRexx**: it has a `CLR.CLS` of its own. When the installer finds
  another `CLR.CLS` through `REXX_PATH` or the `PATH`, it does not install
  ours beside `rexx`, so that the programs written for that one keep it;
  `rexx install --clr` installs it anyway. Ours is also in the samples
  folder: a program finds a `CLR.CLS` next to it before any other.

## Checking it

The installer runs `check.rex`; you can run it yourself (it is in the
samples folder too):

    rexx check.rex

prints something like

    ooRexx: REXX-ooRexx_5.3.0(MT)_64-bit 6.06 8 Oct 2026 r13269
    .NET:   .NET 10.0.12
    .NET frameworks in C:\Program Files\dotnet\shared:
        Microsoft.NETCore.App: 8.0.31 10.0.12
        Microsoft.WindowsDesktop.App: 8.0.31 10.0.12
    StringBuilder: Hello, world 12
    Windows Forms: ok

and, on Windows, opens a MessageBox (`rexx check.rex nogui` opens no
window). "Windows Forms: not available" means that the .NET Desktop Runtime
of your newest .NET is missing.

## Using it

A program uses the bridge with `::requires "net.cls"`:

    say .net~System~Math~Max(3, 7)
    sb = .net~System~Text~StringBuilder~new("Hello")
    sb~Append(", ")~Append("world")
    say sb~ToString sb~Length
    ::requires "net.cls"

`docs/guide.md` (`guide.md` in the samples folder, once installed) is the
guide: every example in it is a program with its output, checked on Linux,
macOS and Windows. Its section 1 (setting up) is about building from source: skip it.

Programs written for BSF4ooRexx's `CLR.CLS` run on this bridge's `CLR.CLS`,
a compatibility package over `net.cls`: see `docs/clr-compat.md`
(`clr-compat.md` once installed).

## Samples

In ooRexx's samples folder, under `dotnet` (here, under `samples`);
`README.md` there lists them, and the folders with a README of their own
say more:

- `rexx`: every system: small commented programs (collections, files,
  regular expressions, events, threads...).
- `windows`: Windows Forms, dialogs, the registry, the clipboard.
- `office`, `libreoffice`: the Office Rosetta stone, Excel, Word, PowerPoint
  (and LibreOffice's Writer, Calc, Impress), each program written with
  ooRexx's `.OLEObject` and through the bridge.
- `oorexx-ole`: ooRexx's own OLE samples, through the bridge.
- `oodialog-net`: ooDialog's samples rewritten for Windows Forms, with no
  ooDialog: the porting guide is its README.
- `powershell/hello.ps1`: PowerShell 7.4 or later hosting ooRexx:
  `pwsh hello.ps1` (it finds the installed bridge through the `rexx` on
  the `PATH`; or give it the folder of `Rexx.Net.dll`).

Each runs with `rexx NAME.rex`; most of them, given `auto`, run by
themselves and end.

## Without installing

To use the package where it is unzipped, copy the files of your system's
folder in `native/` (`win-x64`, `linux-x64`, `osx-arm64`) into the unzipped
folder `rexxnet`, next to `Rexx.Net.dll`; then, in each terminal:

- Windows: `set PATH=C:\rexxnet;%PATH%` and `set REXX_PATH=C:\rexxnet`
  (the folder of `net.cls`, and of the native library, `rexxnet.dll`);
- Linux: `export REXX_PATH=$PWD LD_LIBRARY_PATH=$PWD` (in `rexxnet`);
- macOS: `export REXX_PATH=$PWD DYLD_LIBRARY_PATH=$PWD`.

`REXX_PATH` is searched before the `PATH`: with BSF4ooRexx installed, it
makes this `CLR.CLS` the one found.

## Notes

- On Windows, every Rexx thread becomes a single-threaded apartment (STA)
  when it first uses .NET, as the threads of .NET's GUI applications are
  (common dialogs, the clipboard and drag and drop need it).
  `REXXNET_APARTMENT=MTA` leaves the threads alone.
- .NET programs (C#, VB, PowerShell...) that run Rexx code use the NuGet
  package `Rexx.Net` (`dotnet add package Rexx.Net --prerelease`), not this
  package.
- A prototype. Problems and comments are very welcome:
  <https://github.com/JosepMariaBlasco/oorexxnet/issues>
