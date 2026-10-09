ooRexx/.NET bridge -- Windows x64 binaries (prototype)
======================================================

Built @DATE@ from https://github.com/JosepMariaBlasco/oorexxnet,
commit @COMMIT@. License: Apache 2.0 (System.Speech.dll: MIT, Microsoft).


What you need
-------------

- ooRexx 5, 64-bit (tested with 5.3.0 trunk).
- .NET 8 or later, x64. For Windows Forms, and for CLR.CLS's Windows
  samples, the ".NET Desktop Runtime" (it includes the .NET Runtime; a .NET
  SDK has both): https://dotnet.microsoft.com/download/dotnet/10.0
  Without the desktop runtime everything else works.
  "dotnet --list-runtimes" shows what is installed: look for
  Microsoft.WindowsDesktop.App.

Nothing needs to be compiled, and no Java.


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
    StringBuilder: Hello, world 12
    Windows Forms: ok

then open a MessageBox, and print "MessageBox: ok" when you close it.
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


Notes
-----

- On Windows, every Rexx thread becomes a single-threaded apartment (STA)
  when it first uses .NET, as the threads of .NET's GUI applications are
  (common dialogs, the clipboard and drag and drop need it).
  REXXNET_APARTMENT=MTA leaves the threads alone.
- Files: rexxnet.dll (the native library ooRexx loads), Rexx.Net.dll (the
  .NET side) with its .runtimeconfig.json files, .deps.json and .pdb,
  net.cls, CLR.CLS, System.Speech.dll, check.rex, guide.md,
  clr-compat.md, this file.
- A prototype. Problems and comments are very welcome:
  https://github.com/JosepMariaBlasco/oorexxnet/issues
