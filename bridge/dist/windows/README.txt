ooRexx/.NET bridge -- Windows x64 binaries (prototype)
======================================================

Built @DATE@ from https://github.com/JosepMariaBlasco/oorexxnet,
commit @COMMIT@. License: Apache 2.0 (System.Speech.dll: MIT, Microsoft).


What you need
-------------

- ooRexx 5, 64-bit (tested with 5.3.0 trunk).
- .NET 8 or later, x64: the ".NET Desktop Runtime", for Windows Forms and
  CLR.CLS's Windows samples (see "Which .NET?" below). Without its desktop
  part everything else works.

Nothing needs to be compiled, and no Java.


Which .NET? (Windows)
---------------------

Three different things are called ".NET" on Windows:

- .NET Framework (4.x) is the old, Windows-only .NET that comes with
  Windows. The bridge does not use it. (BSF4ooRexx's CLR.CLS reached it
  through Java and jni4net.)
- .NET (8, 10...; once ".NET Core") is the current one, and what the bridge
  needs: version 8 or later. Microsoft offers several installers of it:
    - ".NET Runtime": the base (Microsoft.NETCore.App). Enough for most
      of .NET, but not for Windows Forms.
    - ".NET Desktop Runtime" (Windows only): the base plus the desktop
      framework (Microsoft.WindowsDesktop.App): Windows Forms, WPF,
      System.Drawing, SystemSounds, SystemEvents... Install this one.
    - "ASP.NET Core Runtime": for web servers; not needed.
    - The ".NET SDK", for building .NET programs, includes all of them.
- 32 or 64 bits: each comes for x64 and for x86. A 64-bit ooRexx needs
  the x64 one (in C:\Program Files\dotnet); an x86 .NET (in
  C:\Program Files (x86)\dotnet) is invisible to it.

The bridge starts the newest .NET it finds (x64), and adds the desktop
framework when that version has it; when it does not, everything works
except the desktop types ("no .NET type System.Windows.Forms.Form"). So
install the Desktop Runtime of your newest .NET, or simply the newest:
https://dotnet.microsoft.com/download/dotnet/10.0, ".NET Desktop Runtime",
Windows, x64.

To see what is installed: "dotnet --list-runtimes" (Microsoft.WindowsDesktop.App
must be listed, with the same major version as the newest
Microsoft.NETCore.App), or check.rex below.


Installing
----------

Unzip anywhere; here, C:\rexxnet. In a cmd window:

    set PATH=C:\rexxnet;%PATH%
    set REXX_PATH=C:\rexxnet;%REXX_PATH%

rexx finds rexxnet.dll through the PATH, and net.cls and CLR.CLS through
REXX_PATH. REXX_PATH matters if BSF4ooRexx is installed: it has a CLR.CLS of
its own, and the one here must be found first (REXX_PATH is searched before
the PATH). To make it permanent, add both in Windows' environment variables.


Checking it
-----------

    rexx C:\rexxnet\check.rex

should print something like

    ooRexx: REXX-ooRexx_5.3.0(MT)_64-bit 6.06 8 Oct 2026
    .NET:   .NET 10.0.12
    .NET frameworks in C:\Program Files\dotnet\shared:
        Microsoft.NETCore.App: 8.0.31 10.0.12
        Microsoft.WindowsDesktop.App: 8.0.31 10.0.12
    StringBuilder: Hello, world 12
    Windows Forms: ok

then open a MessageBox, and print "MessageBox: ok" when you close it.
If it says "Windows Forms: not available", Microsoft.WindowsDesktop.App is
missing from that list: install the .NET Desktop Runtime (x64).
("rexx C:\rexxnet\check.rex nogui" opens no window.)


Using it
--------

A program uses the bridge with ::requires "net.cls":

    say .net~System~Math~Max(3, 7)
    sb = .net~System~Text~StringBuilder~new("Hello")
    sb~Append(", ")~Append("world")
    say sb~ToString sb~Length
    ::requires "net.cls"

guide.md is the guide (docs/guide.md in the repository): every example in
it is a program with its output, checked on Linux and on Windows. Its
section 1 (setting up) is about building from source; skip it.

Programs written for BSF4ooRexx's CLR.CLS (::requires CLR.CLS) run on this
bridge's CLR.CLS, a compatibility package over net.cls: see clr-compat.md.
BSF4ooRexx's samples\clr (raffel\ and baginski\), Windows ones included,
run unchanged. Baginski's 15 (speech) uses System.Speech, which was part of
.NET Framework and is a NuGet package in .NET: System.Speech.dll is here,
and the bridge finds it next to itself.


Samples
-------

samples\rexx (every platform) and samples\windows (Windows Forms, dialogs,
the registry, the clipboard...): small commented programs, listed in
samples\README.md. With the two variables set:

    rexx C:\rexxnet\samples\windows\forms-hello.rex


From PowerShell
---------------

PowerShell 7.4 or later (not Windows PowerShell 5.1, which runs on .NET
Framework) can host ooRexx through Rexx.Net.dll:

    pwsh C:\rexxnet\hello.ps1

runs Rexx code, takes its output, passes a .NET List to Rexx and uses a Rexx
Directory: see the script.


Notes
-----

- On Windows, every Rexx thread becomes a single-threaded apartment (STA)
  when it first uses .NET, as the threads of .NET's GUI applications are
  (common dialogs, the clipboard and drag and drop need it).
  REXXNET_APARTMENT=MTA leaves the threads alone.
- Files: rexxnet.dll (the native library ooRexx loads), Rexx.Net.dll (the
  .NET side) with its .runtimeconfig.json files, .deps.json and .pdb,
  net.cls, CLR.CLS, System.Speech.dll, check.rex, hello.ps1, guide.md,
  clr-compat.md, samples\, this file.
- A prototype. Problems and comments are very welcome:
  https://github.com/JosepMariaBlasco/oorexxnet/issues
