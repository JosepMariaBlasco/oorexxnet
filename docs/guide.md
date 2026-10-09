# ooRexx/.NET — a guide

This guide shows how to use the bridge, from both sides: ooRexx programs that
use .NET, and .NET programs that run Rexx. Every example is a complete program
followed by its output; `docs/check-guide.rex` runs them all and compares (so
what you read here is what the bridge does).

The bridge is a prototype: it runs on Linux, with .NET 8 or later and ooRexx
5.3.0 (trunk), and on Windows; its scripts support macOS too, not yet
tried there. The design behind each choice is in `notes/`.

- [1. Setting up](#1-setting-up)
- [2. ooRexx → .NET](#2-oorexx--net)
- [3. Values: what goes, what comes back](#3-values-what-goes-what-comes-back)
- [4. Arrays, collections, dictionaries](#4-arrays-collections-dictionaries)
- [5. Enums, generics, structs, `ref` / `out`, tasks](#5-enums-generics-structs-ref--out-tasks)
- [6. Events and callbacks](#6-events-and-callbacks)
- [7. Errors](#7-errors)
- [8. Rexx subclasses of .NET objects](#8-rexx-subclasses-of-net-objects)
- [9. .NET → ooRexx](#9-net--oorexx)
- [10. Programs written for CLR.CLS](#10-programs-written-for-clrcls)
- [11. If you know BSF4ooRexx](#11-if-you-know-bsf4oorexx)

## 1. Setting up

```bash
sudo scripts/setup-env.sh --no-dotnet       # ooRexx 5.3.0 trunk (.deb), if there is no rexx yet
DOTNET_DIR=~/dotnet scripts/setup-env.sh    # the .NET SDKs 8 and 10 into ~/dotnet
export DOTNET_ROOT=~/dotnet PATH=~/dotnet:$PATH
bridge/build.sh ~/rexxnet                   # the bridge: Rexx.Net.dll, librexxnet.so, net.cls, CLR.CLS
bridge/tests/run.sh ~/rexxnet               # (optional) builds and runs every test suite
```

A Rexx program uses the bridge with `::requires "net.cls"`, run where it can
find `net.cls` and `librexxnet.so`:

```bash
cd ~/rexxnet && LD_LIBRARY_PATH=. rexx ~/prog.rex
```

(Or put the build directory on `REXX_PATH` and `LD_LIBRARY_PATH` and run from
anywhere.) The .NET runtime is found through `DOTNET_ROOT`. On macOS the
library is `librexxnet.dylib` and the variable `DYLD_LIBRARY_PATH`; ooRexx
must be installed first (`setup-env.sh` installs only .NET there), with its
`bin/` on the `PATH`.

## 2. ooRexx → .NET

`.net` is the root of .NET's namespaces. Going down by name reaches a
namespace, then a type; a type's messages go to its static members, and
`new` makes an instance. Framework assemblies are loaded when first needed.

```rexx
say .net~System~Math~Max(3, 7)
say .net~System~Environment~NewLine == .endOfLine
sb = .net~System~Text~StringBuilder~new("Hello")
sb~Append(", ")~Append("world")
say sb~ToString sb~Length
::requires "net.cls"
```

```text
7
1
Hello, world 12
```

Members are found **caselessly** (ooRexx uppercases message names); if two
public members differ only in case, the one starting with an uppercase letter
wins. A message is a method call, a property or field read (`o~Length`), or,
with `=`, a property or field write:

```rexx
sb = .net~System~Text~StringBuilder~new
sb~Capacity = 100
say sb~Capacity
::requires "net.cls"
```

```text
100
```

`.net~type(name)` gives a type by its full name, with C# aliases and generics
in C# syntax; `.net~load(name or path)` loads an assembly (yours, or a
framework one by name):

```rexx
list = .net~type("System.Collections.Generic.List<int>")~new
list~Add(3); list~Add(1); list~Add(2); list~Sort
say list[0] list[1] list[2] list~Count
d = .net~type("System.Collections.Generic.Dictionary<string, int>")~new
say .net~typeOf(d)
::requires "net.cls"
```

```text
1 2 3 3
System.Collections.Generic.Dictionary<System.String, System.Int32>
```

Exact access, when a name is not enough: `.net~invoke(o, "Name", args...)`,
`.net~get(o, "Name")`, `.net~set(o, "Name", value)` (exact case, no guessing).
Introspection: `.net~typeOf(o)`, `.net~typeObject(o)` (the `System.Type`),
`.net~isInstance(o, type)`, `.net~members(o)`.

Rexx's own `Object` methods whose names .NET also uses — `start`, `send`,
`copy`, `run`, `request`, `string` — go to the .NET member when the object has
one (`process~Start`, `stopwatch~Start`), and to Rexx's otherwise.

```rexx
w = .net~System~Diagnostics~Stopwatch~new
w~Start
say w~IsRunning
::requires "net.cls"
```

```text
1
```

## 3. Values: what goes, what comes back

**To .NET**, a Rexx string becomes whatever the parameter wants: `"007"` is
`"007"` for a `string` and `7` for an `int`; `1` / `0` for a `bool`; a name
for an enum. When overloads compete, the one that fits best wins (as C#
chooses); when the choice must be yours, force a type: `.net~int16(x)` ...
`.net~decimal(x)`, `.net~bool(x)`, `.net~char(x)`, `.net~string(x)`,
`.net~null`, or any type with `.net~as(x, type)`.

```rexx
p = .net~System~Text~StringBuilder~new
p~Append("007"); p~Append(" ")
p~Append(.net~int32("007"))
say p~ToString
say .net~System~Convert~ToString(.net~as(255, "byte"), 2)
::requires "net.cls"
```

```text
007 7
11111111
```

`.net~box(type, x)` goes further: it makes a .NET object holding `x` as that
type, which you can keep and pass around; `.net~unbox(o)` gives its Rexx value
back. (CLR.CLS's type names work too: `"INT16"`, `"BOolean"`, `"STring"`.)

```rexx
b = .net~box("short", 5)
say .net~typeOf(b) .net~unbox(b)
::requires "net.cls"
```

```text
System.Int16 5
```

**From .NET**, strings, numbers, `bool`s (`1` / `0`) and `char`s come back as
Rexx strings, `null` as `.nil`; enums as `.NetEnum`s and arrays as
`.NetArray`s (sections 4 and 5); everything else as a `.NetObject`, **by
reference**: nothing is copied, the same .NET object gives a proxy that is
`==` to the earlier one, and it goes back to .NET as itself. `say` shows what
a proxy is:

```rexx
sb = .net~System~Text~StringBuilder~new
say sb~makeString~word(1) sb~makeString~word(2) sb~makeString~word(3)
say sb~Append("x") == sb
::requires "net.cls"
```

```text
a NetObject (System.Text.StringBuilder
1
```

Any other Rexx object (a Directory, an instance of your own class) goes to
.NET by reference too, as a `Rexx.Net.RexxObject` that .NET code can keep and
send messages to; it comes back to Rexx as itself.

## 4. Arrays, collections, dictionaries

**A .NET array is a Rexx Array**, from 1 in every dimension (as BSF4ooRexx
does for Java arrays): `a[i]`, `a[i, j] = v`, `at`, `put`, `putStrict`,
`items`, `size`, `dimension`, `makeArray`, `supplier`. It is still the .NET
array, by reference, so its .NET members work too.

```rexx
bytes = .net~System~Text~Encoding~UTF8~GetBytes("abc")
say bytes[1] bytes~items bytes~dimension bytes~Length
bytes[1] = 65
say .net~System~Text~Encoding~UTF8~GetString(bytes)
grid = .net~System~Array~CreateInstance(.net~type("int"), 2, 3)
grid[2, 3] = 7
do with index i item v over grid
  if v \= 0 then say i~makeString("L", ",") "=" v
end
::requires "net.cls"
```

```text
97 3 1 3
Abc
2,3 = 7
```

A wrong index raises the error a Rexx Array raises (93.907 for `a[0]`); one
past the end is .NET's `IndexOutOfRangeException` (a .NET array cannot grow).

**Lists and other collections stay as .NET documents them**: `o[i]` is the
indexer, 0-based for a list, a key for a dictionary. `DO OVER` works on
anything enumerable; `DO WITH INDEX ... ITEM` gives a dictionary's keys and
values, a list's positions from 0, an array's from 1.

```rexx
d = .net~type("System.Collections.Generic.Dictionary<string, int>")~new
d["one"] = 1; d["two"] = 2
do with index k item v over d; say k v; end
l = .net~type("System.Collections.Generic.List<string>")~new
l~Add("a"); l~Add("b")
do x over l; say x; end
say l[0]
::requires "net.cls"
```

```text
one 1
two 2
a
b
a
```

**A Rexx Array** goes to .NET as a new array or `List<T>` (a copy, items
converted); **a StringTable or a Directory** as a new `Dictionary<string, T>`
where a dictionary with string keys is asked for (a copy too; anywhere else
they go by reference).

```rexx
say .net~System~String~Join("-", .array~of("a", "b", "c"))
st = .stringTable~new; st["x"] = 1; st["y"] = 2
d = .net~type("System.Collections.Generic.Dictionary<string, int>")~new(st)
say d~Count d["y"]
::requires "net.cls"
```

```text
a-b-c
2 2
```

## 5. Enums, generics, structs, `ref` / `out`, tasks

**An enum value is a `.NetEnum`**: its string is its name, `=` compares it
with a name (caseless; flags in any order) or a number, `~name` and
`~ordinal` (its number) give the parts. An enum type is enumerable: `DO OVER`
gives its values, `DO WITH` numbers and names. A name still goes to .NET as
the enum.

```rexx
day = .net~System~DateTime~new(2026, 10, 9)~DayOfWeek
say day day~ordinal (day = "friday")
do d over .net~System~DayOfWeek; if d~ordinal < 2 then say d; end
say .net~System~DateTime~new(2026, 10, 9)~AddDays(1)~DayOfWeek
::requires "net.cls"
```

```text
Friday 5 1
Sunday
Monday
Saturday
```

**Generic methods** infer their type arguments from the arguments, as C#
does, or take them in the name: `.net~invoke(o, "Name<int>", ...)`.

**`ref` / `out` parameters** take a `.NetRef`: `.net~ref([value])`, and
`r~value` after the call.

```rexx
d = .net~type("System.Collections.Generic.Dictionary<string, int>")~new
d["k"] = 42
r = .net~ref
say d~TryGetValue("k", r) r~value
say .net~System~Int32~TryParse("x", .net~ref)
::requires "net.cls"
```

```text
1 42
0
```

**Structs** come as a boxed copy: setting a field changes the copy you hold,
not the value .NET has (as a struct copy in C#, but without C#'s warning). **Tasks**: `t~await` waits for a
`Task` or `ValueTask` (blocking the Rexx thread) and gives its result.

```rexx
t = .net~System~Threading~Tasks~Task~Delay(10)
t~await
say t~IsCompleted
::requires "net.cls"
```

```text
1
```

## 6. Events and callbacks

`.net~handler(object, message [, options])` is a Rexx method that .NET can
call: wherever .NET wants a delegate (an `Action`, a `Func`, a `Comparison`,
an `EventHandler`, any delegate type), it becomes one of that exact type.
What the method returns goes back as the delegate's return value.

```rexx
l = .net~type("System.Collections.Generic.List<string>")~new
l~Add("pear"); l~Add("fig"); l~Add("banana")
l~Sort(.net~handler(.ByLength~new, "COMPARE"))
do x over l; say x; end
::requires "net.cls"
::class ByLength
::method compare
  use arg a, b
  return a~length - b~length
```

```text
fig
pear
banana
```

Events: `o~Click += h`, `o~Click -= h` (the same handler object removes it);
or `.net~addHandler(o, "Click", h)`, `.net~removeHandler(...)`, or .NET's own
`o~add_Click(h)`. The method gets the event's arguments (`sender`, `e`).

```rexx
timer = .net~System~Timers~Timer~new(50)
timer~AutoReset = 0
t = .Ticks~new
timer~Elapsed += .net~handler(t, "TICK")
timer~Start
call SysSleep 0.5
say t~count
::requires "net.cls"
::class Ticks
::attribute count
::method init
  expose count
  count = 0
::method tick unguarded
  expose count
  use arg sender, e
  count += 1
```

```text
1
```

By default a call runs at once, on the thread .NET calls it on (a timer's
thread above). A handler whose object may be busy in a guarded method should
be `UNGUARDED`. With the option `"queued"`, calls wait in a queue instead and
the delegate returns at once; a Rexx thread takes them with
`.net~nextEvent([seconds])` (then `call~dispatch`), or `.net~eventLoop` until
`.net~stopEventLoop`. `"latest"` keeps only the newest waiting call of a
handler.

## 7. Errors

An exception thrown by .NET code is **SYNTAX 98.900** ".NET error: Type:
message", with the exception (a `.NetObject`) in `condition("O")~additional[2]`.
A name that is no member of the object is **97.1**, as for any Rexx object,
with a `MissingMemberException` in `additional[3]`. A wrong array index is a
Rexx Array's error (93.9xx).

```rexx
signal on syntax
say .net~System~Int32~Parse("abc")
syntax:
  c = condition("O")
  say c~code .net~typeOf(c~additional[2])
  signal on syntax name second
  x = .net~System~Text~StringBuilder~new~NoSuchThing
second:
  c = condition("O")
  say c~code c~additional[2] .net~typeOf(c~additional[3])
::requires "net.cls"
```

```text
98.900 System.FormatException
97.1 NOSUCHTHING System.MissingMemberException
```

A Rexx error inside a handler that .NET called (a comparator, an event) is a
`RexxException` in .NET; if it comes back out of .NET, it is raised again in
Rexx as it was. On a thread where no Rexx code waits (a timer), the error is
reported on `.error` and the program goes on.

## 8. Rexx subclasses of .NET objects

`.MyClass~new(o)`, with `MyClass` a subclass of `.NetObject` and `o` a
`.NetObject`, is an object of your class standing for the same .NET object.
Its methods win over .NET members of the same name, and its `UNKNOWN` gets
every other message first; `FORWARD CLASS (SUPER)` reaches .NET.

```rexx
sb = .Loud~new(.net~System~Text~StringBuilder~new("abc"))
say sb~Shout sb~Length
say sb == sb~Append("d")
::requires "net.cls"
::class Loud subclass NetObject
::method unknown
  use arg name, args
  if name = "SHOUT" then return self~ToString~upper
  forward class (super)
```

```text
ABC 3
1
```

## 9. .NET → ooRexx

A .NET program runs Rexx through `Rexx.Net.dll`: reference the NuGet
package `Rexx.Net` (made by `bridge/pack.sh`) or the assembly from a build.
It finds `librexx` itself; ooRexx 5 must be installed. The Rexx code it runs
can use .NET too: `net.cls` and `CLR.CLS` are built into the assembly, so
`::requires "net.cls"` needs no file, and the native library `rexxnet` comes
with the package (or is found next to `Rexx.Net.dll`). `RexxInterpreter.Create()` starts an
interpreter instance; `Run` runs Rexx code as a routine (`use arg`, `return`),
`Run<T>` converts the result; `Compile` keeps a routine to call many times;
`LoadPackage` / `FindClass` reach Rexx classes, whose objects are
`RexxObject`s (`Send`, `Send<T>`, or C#'s `dynamic`). Command environments
(`ADDRESS`), Rexx's I/O (`SAY`, `PULL`, errors) and cancellation are the
host's to decide.

```csharp
using System;
using System.IO;
using System.Threading;
using Rexx.Net;

using var rexx = RexxInterpreter.Create();
Console.WriteLine(rexx.Run<int>("use arg a, b; return a * b", 6, 7));

var twice = rexx.Compile("twice", "use arg x; return 2 * x");
Console.WriteLine(twice.Call<int>(21));

var pkg = rexx.LoadPackage("account.cls",
    "::class Account public\n" +
    "::attribute balance get\n" +
    "::method init; expose balance; use arg balance\n" +
    "::method deposit; expose balance; use arg n; balance += n; return balance\n");
var account = pkg.FindClass("Account")!.New(10)!;
account.Send("DEPOSIT", 5);
dynamic acct = account;
Console.WriteLine((int)acct.balance);

rexx.AddCommandEnvironment("APP", cmd => cmd.Command.ToUpperInvariant());
Console.WriteLine(rexx.Run<string>("address app 'hello'; return rc"));

var output = new StringWriter();
rexx.Output = output;
rexx.Run("say 'captured'");
rexx.Output = null;
Console.WriteLine(output.ToString().Trim());

using var cts = new CancellationTokenSource(200);
try { rexx.Run("do forever; nop; end", cts.Token); }
catch (OperationCanceledException) { Console.WriteLine("cancelled"); }

try { rexx.Run("return 1 + 'a'"); }
catch (RexxException e) { Console.WriteLine($"{e.Code} {e.ErrorText}"); }
```

```text
42
42
15
HELLO
captured
cancelled
41.1 Bad arithmetic conversion.
```

**Both ways in one process.** .NET objects passed to Rexx are `.NetObject`s
(`net.cls` is loaded on first need), and Rexx code can use `.net` as in a Rexx
program; they come back to .NET as themselves. .NET code called from Rexx
reaches the interpreter that called it through `RexxInterpreter.Current`.
The details: `notes/rexx-from-net-design.md`.

## 10. Programs written for CLR.CLS

Programs written for BSF4ooRexx's `CLR.CLS` (ooRexx.NET, through Java and
jni4net) run unchanged: `::REQUIRES CLR.CLS` finds the compatibility package
next to `net.cls`.

```rexx
console = clr.import("System.Console")
console~WriteLine("Hello from CLR.CLS")
sb = .clr~new("System.Text.StringBuilder", "ab")
say sb~Append("c")~ToString pp(sb~Length)
say .clr~new("System.DateTime")~Now~Year > 2000
::requires CLR.CLS
```

```text
Hello from CLR.CLS
abc [3]
1
```

What it keeps from CLR.CLS (whole numbers as `Int32`, instance and static
members found together...) and the samples that run: `notes/clr-compat.md`.

## 11. If you know BSF4ooRexx

| BSF4ooRexx (Java) | ooRexx/.NET |
|---|---|
| `bsf.import("java.lang.Math")` | `.net~System~Math`, `.net~type("System.Math")` |
| `.bsf~new("java.lang.StringBuilder")` | `.net~System~Text~StringBuilder~new`, `.net~new(type, ...)` |
| `bsf.dispatch` | `.net~invoke(o, "Name", ...)` (and START, SEND... go to .NET when it has the member) |
| Java arrays as Rexx arrays, from 1 (`BSF_ARRAY_REFERENCE`) | the same: `.NetArray` |
| `java.util.List`: `get(0)` | the same: `list[0]` |
| Java enums as objects | `.NetEnum` |
| `box` / `unbox` | `.net~box(type, x)`, `.net~unbox(o)` |
| `BsfCreateRexxProxy(obj, , "java.awt.event.ActionListener")` | `.net~handler(obj, "MESSAGE")`, any delegate type |
| unknown member: an error naming it | 97.1, as any Rexx object |

And from `.JSObject` (ooRexx in WebAssembly): the same shape (`.net` as
`.js`, `.NetObject` as `.JSObject`, `.net~handler` as `.js~handler`, the
queued event model), with the differences the design notes mark **Δ**: names
caseless with the uppercase member winning, arrays from 1, an unknown member
an error rather than `.nil`.
