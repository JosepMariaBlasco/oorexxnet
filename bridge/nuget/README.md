# Rexx.Net

A bidirectional bridge between [ooRexx](https://sourceforge.net/projects/oorexx/)
and .NET. A prototype.

- **.NET → ooRexx**: any .NET application runs Rexx code and uses Rexx
  objects as .NET objects (`RexxInterpreter`, `RexxObject`), provides
  `ADDRESS` environments and redirects Rexx's I/O.
- **ooRexx → .NET**: the Rexx code it runs can create .NET objects, call
  their methods and handle their events (`.net`, `net.cls`), and .NET
  objects go to Rexx and come back as themselves.

**Needs an installed ooRexx 5**, 64-bit (found through `REXX_HOME`, the
system's library search, or the `rexx` on the `PATH`). ooRexx is not in the
package.

```csharp
using Rexx.Net;

using var rexx = RexxInterpreter.Create();
int n = rexx.Run<int>("return 6 * 7");                       // 42

var pkg = rexx.LoadPackage("account.cls");
dynamic acct = pkg.FindClass("Account")!.New(100);
acct.Deposit(50);                                             // a Rexx message
int balance = acct.Balance;

var sb = new System.Text.StringBuilder("ab");
rexx.Run("use arg sb; sb~Append('cd')", sb);                  // a .NetObject in Rexx
string s = rexx.Run<string>("""
    say .net~System~Math~Max(3, 7)
    return .net~System~Environment~OSVersion~ToString
    ::requires "net.cls"
    """);
```

`net.cls` (and `CLR.CLS`, for programs written for BSF4ooRexx's ooRexx.NET)
are built into the assembly: `::requires "net.cls"` needs no file. Rexx code
using `.net` needs the bridge's native library too, `rexxnet`, which the
package carries for the platforms it was built on (`runtimes/<rid>/native`).
Without it, everything else works.

The guide, with every feature as a small program and its output, and the
design notes: <https://github.com/JosepMariaBlasco/oorexxnet>.
