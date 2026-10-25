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
- [12. COM objects (Windows)](#12-com-objects-windows)

## 1. Setting up

Without building it: the binary zip of a release (`rexxnet-….zip`, at
<https://github.com/JosepMariaBlasco/oorexxnet/releases>: Windows, Linux
and macOS in one) has an installer, `rexx install`, which puts the bridge
into your ooRexx: then any program finds `net.cls`, with no variables to set
(its `README.md` says more). From the sources:

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

### Which .NET on Windows

Three different things are called ".NET" on Windows. **.NET Framework**
(4.x), the old Windows-only one that comes with Windows, is not used by the
bridge. **.NET** (8, 10...; once ".NET Core") is, version 8 or later, and
Microsoft installs it in parts: the **.NET Runtime** (the base,
`Microsoft.NETCore.App`), the **.NET Desktop Runtime** (the base plus the
desktop framework, `Microsoft.WindowsDesktop.App`: Windows Forms, WPF,
`System.Drawing`, `SystemSounds`, `SystemEvents`...), the ASP.NET Core
Runtime (web servers; not needed) and the SDK (everything, for building).
Each comes for x64 and x86: a 64-bit ooRexx needs the x64 one (`C:\Program
Files\dotnet`); an x86 .NET (`C:\Program Files (x86)\dotnet`) is invisible
to it.

The bridge starts the newest .NET it finds and adds the desktop framework
when that version has it; when it does not, everything works except the
desktop types (`no .NET type "System.Windows.Forms.Form"`). So: install the
**.NET Desktop Runtime, x64**, of your newest .NET, or simply the newest
(<https://dotnet.microsoft.com/download/dotnet/10.0>). `dotnet
--list-runtimes` shows what is installed: `Microsoft.WindowsDesktop.App`
must be there, with the same major version as the newest
`Microsoft.NETCore.App`.

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
`.net~isInstance(o, type)` (0 for a Rexx value or `.nil`: no .NET object),
`.net~members(o)`.

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
`"007"` for a `string` and `7` for an `int`; a number out of range for a
`double`, `float` or `decimal` (too large, or not zero but read as zero:
`1E-999`) fits none, and the error says so; `1` / `0` for a `bool`; a name
for an enum. A `.LogicalWrapper` (`.LogicalWrapper~true`, `~false`: ooRexx's
`logicalwrapper.cls`, which `net.cls` requires) goes as a `bool`, also where
.NET takes an `object`, and so do its subclasses, the booleans of `json.cls`
and `yaml.cls`; `.true` and `.false` are strings. When overloads compete, the one that fits best wins (as C#
chooses); when the choice must be yours, force a type: `.net~int16(x)` ...
`.net~decimal(x)`, `.net~char(x)`, `.net~string(x)`, `.net~null`, or any
type with `.net~as(x, type)`; `.net~bool(x)` gives `.LogicalWrapper~true` or
`~false` (`x`: `1`, `0`, `true`, `false`).

```rexx
p = .net~System~Text~StringBuilder~new
p~Append("007"); p~Append(" ")
p~Append(.net~int32("007"))
say p~ToString
say .net~System~Convert~ToString(.net~as(255, "byte"), 2)
j = .json~new~fromJSON('{"ok": true}')
say .net~System~Convert~ToString(j["ok"]) .net~System~Convert~ToString(.true)
::requires "net.cls"
::requires "json.cls"
```

```text
007 7
11111111
True 1
```

`.net~box(type, x)` goes further: it makes a .NET object holding `x` as that
type, which you can keep and pass around; `.net~unbox(o)` gives its Rexx value
back. The type can also be one of BSF4ooRexx's indicators, as every ooRexx
bridge takes them (`.js~box` too): `BOolean`, `BYte`, `Char`, `Double`,
`Float`, `Int`, `Long`, `Object`, `SHort`, `STring`, caseless and shortened
down to their capitals (`"I"`, `"d"`); `BYte` is .NET's `Byte` (unsigned:
Java's byte is `SByte`). CLR.CLS's names work too: `"INT16"`, `"DE"`
(`Decimal`), `"SI"` (`Single`).

```rexx
b = .net~box("short", 5)
say .net~typeOf(b) .net~unbox(b)
::requires "net.cls"
```

```text
System.Int16 5
```

**From .NET**, strings, numbers (`BigInteger`, `Int128` and `UInt128` with
all their digits; a `double` with its shortest digits, as Rexx writes `x + 0`
under `numeric digits 17`: `0.0000001`, `1E+17`, `1` for `1.0`, `-0` kept;
NaN and the infinities as ooRexx writes them: `nan`, `+infinity`, `-infinity`) and `char`s come back as Rexx strings, `bool`s as
`.LogicalWrapper~true` and `~false` (they are `1` and `0` to Rexx, and go back
to .NET as `bool`s), `null` as `.nil`; enums as `.NetEnum`s and arrays as
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

**The culture.** What the bridge converts is the same on every machine (a
point in numbers). .NET's own methods that read or write numbers and dates as
text use the machine's culture unless given one: on a Spanish Windows
`.net~System~Convert~ToDouble("0.5")` is 5. Pass
`CultureInfo~InvariantCulture` (or force the type, `.net~double(x)`) when the
text is a Rexx number; the Reference (*Values*, *Numbers, Dates and the
Culture*) has where it goes in each kind of call.

```rexx
inv = .net~System~Globalization~CultureInfo~InvariantCulture
say .net~System~Convert~ToDouble("0.5", inv) .net~System~String~Format(inv, "{0:N2}", .net~double(1234.5))
::requires "net.cls"
```

```text
0.5 1,234.50
```

## 4. Arrays, collections, dictionaries

**A .NET array is a Rexx Array**, from 1 in every dimension (as BSF4ooRexx
does for Java arrays): `a[i]`, `a[i, j] = v`, `at`, `put`, `putStrict`,
`items`, `size`, `dimension`, `dimensions`, `hasIndex`, `makeArray`,
`supplier`, and `makeString` /
`toString` as an Array's (so `say` shows its elements). It is still the .NET
array, by reference, so its .NET members work too.

```rexx
bytes = .net~System~Text~Encoding~UTF8~GetBytes("abc")
say bytes[1] bytes~items bytes~dimension bytes~Length
bytes[1] = 65
say .net~System~Text~Encoding~UTF8~GetString(bytes) bytes~makeString("L", ",")
grid = .net~System~Array~CreateInstance(.net~type("int"), 2, 3)
grid[2, 3] = 7
do with index i item v over grid
  if v \= 0 then say i~makeString("L", ",") "=" v
end
::requires "net.cls"
```

```text
97 3 1 3
Abc 65,98,99
2,3 = 7
```

A wrong index raises the error a Rexx Array raises (93.907 for `a[0]`); one
past the end is an error that says the length (a .NET array cannot grow).
An array whose lower bounds are not 0 (COM's start at 1, as Excel's
`Range.Value`) is from 1 here too.

**A Rexx Array to .NET**: a one-dimensional one goes to an array, a `List`
or an `IEnumerable` parameter; a multidimensional one to a .NET array of the
same rank (`int[,]` for such a parameter, else `object[,]`), `a[i, j]` at
`[i - 1, j - 1]`. An omitted item is `null` where .NET takes one (`object[]`,
`string[]`: the size is kept; not an `int[]`). The copy keeps the structure:
an Array that contains itself is an `object[]` that contains itself, and one
Array in it twice is one .NET array (Arrays nested more than 1000 deep are
an error).

```rexx
grid = .array~new(2, 3)
do i = 1 to 2; do j = 1 to 3; grid[i, j] = i * 10 + j; end; end
list = .net~System~Collections~ArrayList~new
list~Add(grid)
g = list~Item(0)                                    -- the .NET array, as a Rexx Array again
say .net~typeOf(g) g~Rank g~GetLength(1) g[2, 3]
::requires "net.cls"
```

```text
System.Object[,] 2 3 23
```

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

**A collection with both an `int` indexer and a `string` one**
(`NameValueCollection`, WinForms' `ListView.Items`, `Controls`...) takes a
Rexx whole number as a position, as a COM collection does; a key that looks
like a number is given with `.net~string`. Everywhere else a Rexx string
prefers a `string` parameter (§3).

```rexx
nv = .net~System~Collections~Specialized~NameValueCollection~new
nv~Add("1", "first"); nv~Add("0", "second")
say nv[0] "/" nv[.net~string(0)] "/" nv["1"] "/" nv~Get("1")
::requires "net.cls"
```

```text
first / second / second / first
```

**A Rexx Array** goes to .NET as a new array or `List<T>` (a copy, items
converted); **a StringTable or a Directory** as a new `Dictionary<string, T>`
where a dictionary with string keys is asked for (a copy too; anywhere else
they go by reference). Subclasses count; the keys are as stored (`d~name`
stores `NAME`, `d["name"]` keeps the case).

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

A handler can also serve an `ADDRESS` environment. Command environments are
ooRexx's own (`.CommandHandler`, ooRexx r13288): `.CommandHandler~register(name,
handler)` registers one, `.CommandHandler~deregister(name)` removes it. A
handler written in Rexx needs no .NET; a .NET one goes in a
`.NetCommandHandler`: `.CommandHandler~register("CALC",
.NetCommandHandler~new(.net~handler(obj, "COMMAND")))` sends each `address calc
'...'` to the method as a `Rexx.Net.RexxCommand` (`cmd~Command`,
`cmd~WriteLine(...)` for `WITH OUTPUT`), and what it returns is `RC`. A .NET
delegate taking a `RexxCommand` works too, and an application hosting Rexx
does the same with `rexx.AddCommandEnvironment` (section 9). As for any
handler, a second one for a name covers the one in use, which `register`
answers (`.nil` if none; its `command` method forwards to it);
`deregister` removes the handler in use, uncovers the one below, and answers
the one removed (with none left, a command raises FAILURE, `RC` 30, as for an
environment that does not exist). `.CommandHandler~handlers("CALC")` lists
them.

```rexx
.CommandHandler~register("CALC", .NetCommandHandler~new(.net~handler(.Calc~new, "COMMAND")))
address calc "square 12"
say rc
::requires "net.cls"
::class Calc
::method command
  use arg cmd
  parse value cmd~Command with verb n
  if verb = "square" then return n * n
  return -1
```

```text
144
```

```rexx
.CommandHandler~register("CALC", .NetCommandHandler~new(.net~handler(.Calc~new("plain"), "COMMAND")))
covered = .CommandHandler~register("CALC", .NetCommandHandler~new(.net~handler(.Calc~new("loud"), "COMMAND")))
address calc "square 3"; say rc
say .CommandHandler~handlers("CALC")~items "handlers; covered:" covered~class~id
.CommandHandler~deregister("CALC")          -- the loud one: the plain one again
address calc "square 3"; say rc
::requires "net.cls"
::class Calc
::method init
  expose style
  use arg style
::method command
  expose style
  use arg cmd
  parse value cmd~Command with verb n
  if style = "loud" then return "NINE!"
  return n * n
```

```text
NINE!
2 handlers; covered: NETCOMMANDHANDLER
9
```

### The event thread: `.NetEventThread`

A window belongs to the thread that made it, which runs its events; other
threads must not touch it directly. `.NetEventThread` (BSF4ooRexx's
`FxGUIThread` / `AwtGUIThread`, for .NET) sends messages to that thread:
`runLater(target, message [, "I", arg...] | [, "A", array])` queues it and
returns a `.GUIMessage` at once; the event thread runs the queue later, in
order. `runLaterPush` puts the message first; `runLaterLatest` replaces the
queued ones with the same target and message; `runLaterLatestPush` does
both. The `.GUIMessage` tells `completed`, `hasResult`, `hasError` (with
`errorCondition`: an error stays there), and `result` waits for it.
`isEventThread` tells whether this is the event thread.

An event thread is a user interface's thread (Windows Forms, WPF: one
where Rexx code has run with the window's synchronization context), or,
without a user interface, the Rexx thread in `.net~nextEvent` /
`.net~eventLoop`, which runs the queue as one more queued call. A program
may have several UI threads, each window's being the thread that made it:
each is a `.NetEventThread` object with its own queue. The class methods
send a message to the event thread of its target (a Windows Forms control
once its window exists, a WPF object: its window's thread; anything else:
the default, the first UI thread or else the loop's).
`.NetEventThread~eventThreadFor(control)` gives that object, whose own
`runLater...` send there any message; `~current` is the current thread's
(`.nil` if it is none), `~threads` all the UI threads'. While a message
runs, other threads go on queueing (and `runLaterLatest` replacing).
`samples/rexx/08-event-thread.rex` (no windows),
`samples/windows/forms-progress.rex` and `forms-two-threads.rex` show them.

```rexx
m = .NetEventThread~runLater(.Adder~new, "ADD", "I", 2, 3)
say m~completed .NetEventThread~kind
.net~nextEvent(5)~dispatch              -- this thread is the event thread here
say m~completed m~result .NetEventThread~current
::requires "net.cls"
::class Adder
::method add
  use arg a, b
  return a + b
```

```text
0 loop
1 5 a NetEventThread (the loop)
```

## 7. Errors

An exception thrown by .NET code is **SYNTAX 98.900** ".NET error: Type:
message", with the exception (a `.NetObject`) in `condition("O")~additional[2]`
and its .NET stack trace (text) in `additional[3]`.
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

### Rexx classes extending .NET classes

That subclass is a view chosen by Rexx code: .NET does not know about it. To
have .NET call your methods, as it calls a C# subclass's overrides, extend
the .NET class: `.net~extend(.MyClass, base [, interfaces...])`, once, makes
a .NET type deriving from `base` (a class, or an interface: then
`System.Object`) and implementing the interfaces. Every virtual or abstract
member, public or protected, that your class has a method for is overridden:
.NET calls the method, on the thread it calls from, as it calls a handler
(section 6). A property's getter is the method `Name`, its setter `"NAME="`.
`.MyClass~new(args...)` makes the .NET object with the base constructor that
takes `args` (your `INIT`, if any, calls `self~init:super(args...)`; set what
your overrides need before it: the base constructor may call them already).

As in C#, the object's own methods, and only they, reach the base's
protected members (`self~Items`, `self~Label = "x"`). As in any Rexx class,
`self~Name:super(args)` is the base's: the implementation of a member you
override (C#'s `base.Name(args)`), or a protected member your class hides
with a method of the same name. (`self~base.Name(args)` does the same for
an overridden member.)

```rexx
c = .Shouting~new
c~Add("hello"); c~Insert(0, "world")
say c[0] c[1] c~Count c~stored
say .net~typeOf(c)
::requires "net.cls"
::class Shouting subclass NetObject
::method activate class          -- when the class is created
  .net~extend(self, "System.Collections.ObjectModel.Collection<System.String>")
::method InsertItem              -- protected virtual void InsertItem(int index, string item)
  use arg index, item
  self~InsertItem:super(index, item~upper)
::method stored                  -- Items: a protected property
  return self~Items~Count "items"
```

```text
WORLD HELLO 2 2 items
SHOUTING extending System.Collections.ObjectModel.Collection<System.String>
```

An interface alone is enough for .NET code that wants one, and the object
comes back from .NET as itself:

```rexx
.net~extend(.ByLength, "System.Collections.Generic.IComparer<System.String>")
list = .net~type("System.Collections.Generic.List<System.String>")~new
do w over "ccc a bb dddd"~makeArray(" "); list~Add(w); end
cmp = .ByLength~new
list~Sort(cmp)
say list~ToArray~makeString("L", " ")
held = .net~type("System.Collections.Generic.List<System.Object>")~new
held~Add(cmp)
say (held[0] == cmp) held[0]~class~id
::requires "net.cls"
::class ByLength subclass NetObject
::method Compare
  use arg a, b
  return sign(a~length - b~length)
```

```text
a bb ccc dddd
1 BYLENGTH
```

An abstract member with no method throws `NotImplementedException` when .NET
calls it; an override's Rexx error is a `RexxException` in .NET, and raised
again as it was if it comes back to Rexx. Each instance is a pair, your
object and its .NET object, that lives while Rexx holds the one or .NET the
other: the bridge lets both garbage collectors release it, with nothing to
do by hand, and your class's `UNINIT`, if it has one, runs once, when the
pair is over: when .NET has collected its object, or at the end of the
program. An interface's
event (`INotifyPropertyChanged.PropertyChanged`, what WPF's binding listens
to) is an event of the new type: .NET code and Rexx (`o~PropertyChanged +=
handler`) subscribe to it, and the object's own methods raise it with
`self~raise.PropertyChanged(self, args)`. A parameter by reference (`ref`,
`out`) arrives as a `Rexx.Net.ComRef`, as in COM events: `ref~Value` is its
value, and `ref~Value = x` gives the caller a new one. A generic method's
Rexx method gets its type arguments after its arguments, as NetTypes (what
`.net~type` gives), and `self~base.Name(args..., types...)` passes them on:

```rexx
.net~extend(.Lambdas, "System.Linq.Expressions.ExpressionVisitor")
E = .net~System~Linq~Expressions~Expression
lambda = E~Lambda(E~Constant(.net~int32(42)))
v = .Lambdas~new
say v~Visit(lambda)~Compile~DynamicInvoke
::requires "net.cls"
::class Lambdas subclass NetObject
::method VisitLambda             -- protected virtual Expression VisitLambda<T>(Expression<T> node)
  use strict arg node, t
  say "a lambda:" .net~typeOf(t)
  return self~base.VisitLambda(node, t)
```

```text
a lambda: System.Func<System.Int32>
42
```

The methods are looked at when `.net~extend` runs: one added to the class
later (`define`) is not an override. On Windows, a `Form` whose
`OnPaint`, `OnLoad`... are Rexx methods is `samples/windows/forms-extend.rex`.

## 9. .NET → ooRexx

A .NET program runs Rexx through `Rexx.Net.dll`: reference the NuGet
package `Rexx.Net` (made by `bridge/pack.sh`) or the assembly from a build.
It finds `librexx` itself; ooRexx 5 must be installed. The Rexx code it runs
can use .NET too: `net.cls` and `CLR.CLS` are built into the assembly, so
`::requires "net.cls"` needs no file, and the native library `rexxnet` comes
with the package (or is found next to `Rexx.Net.dll`). `RexxInterpreter.Create()` starts an
interpreter instance; `Run` runs Rexx code as a routine (`use arg`, `return`),
`Run<T>` converts the result; `Compile` keeps a routine to call many times
(`Run`, `Call` and `Send` take a `CancellationToken` to halt the Rexx code);
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

Messages can also be sent with the names of BSF4ooRexx's `RexxProxy` (and
the Python bridge's): `o.SendMessage(name, args...)` (or an array of them),
`o.SendMessage0(name)` … `o.SendMessage5(name, a1, …, a5)`, and
`o.SendMessageScope(name, cls, args...)`, where the method search starts at
the Rexx class `cls` (`o~name:cls`; `cls.SuperClass` gives a class's
superclass). The name is any string: one held in a variable, or one that is
no C# name (`"[]="`, `"||"`). In VB.NET, a Rexx object as `Object` with
`Option Strict Off` is late-bound as `dynamic` is in C# (a class's `New` is
`[New]` there). `samples/csharp/tour` and `samples/vbnet/tour` show it all,
topic by topic.

**Prefixes on the console.** What the Rexx code writes to the process's own
streams carries BSF4ooRexx's prefixes, so that it stands out in the
application's console or log: `REXXout>` (`.output`), `REXXerr>` (`.error`),
`REXXtrc>` (`.traceOutput`, error messages included), and the prompts
`REXXin?>` and `REXXdbgIn?>` before a line is read from `.input` /
`.debugInput`. What goes to `Output` / `Error` or comes from `Input` has
none. `RexxOptions.StreamPrefixes = false`, or `rexx.StreamPrefixes` at any
time, turns them off; Rexx code changes one with
`.output~current~prefix = 'mine>'` (or `.nil`). A Rexx program run by
`rexx` itself has none: its output is its own.

```csharp
using Rexx.Net;

using var rexx = RexxInterpreter.Create();
rexx.Run("say 'one'; say 'two' || '0a'x || 'lines'");
rexx.StreamPrefixes = false;
rexx.Run("say 'plain'");
using var quiet = RexxInterpreter.Create(new RexxOptions { StreamPrefixes = false });
quiet.Run("say 'quiet'");
```

```text
REXXout>one
REXXout>two
REXXout>lines
plain
quiet
```

**Functions and values of the application.** `rexx.AddFunction(name,
handler)` gives the Rexx code a function (`name(args)`, `CALL name args`),
called on the Rexx thread as a command handler is. The handler gets a
`RexxFunctionCall` (`Name`, `Arguments`, `Arg<T>(i)`, `IsSubroutine`, the
caller's variables as `RexxCommand` has them), or is any delegate or method,
whose parameters get the arguments converted by Rexx's rules (a default
value may be left out, a `params` array takes the rest). A .NET exception is
Rexx's error 40.900, with its message; wrong argument counts are 40.3 / 40.4.
The program's own routines and Rexx's built-in functions win; external ones
of the same name are hidden. `rexx.AddValueSelector(selector, get, set)`
answers `VALUE(name, , selector)` (and sets with `VALUE(name, new,
selector)`). Both need an instance made by `RexxInterpreter.Create`.

```csharp
using System;
using System.Collections.Generic;
using Rexx.Net;

using var rexx = RexxInterpreter.Create();
rexx.AddFunction("hypot", (double a, double b) => Math.Sqrt(a * a + b * b));
rexx.AddFunction("greet", (string who, string greeting = "Hello") => $"{greeting}, {who}!");
rexx.AddFunction("vars", call => $"{call.Name} sees x = {call["X"]}");
var settings = new Dictionary<string, object?> { ["COLOR"] = "blue" };
rexx.AddValueSelector("APP", name => settings.GetValueOrDefault(name.ToUpperInvariant()),
                             (name, value) => settings[name.ToUpperInvariant()] = value);

Console.WriteLine(rexx.Run("return hypot(3, 4)"));
Console.WriteLine(rexx.Run("return greet('Rony') greet('JM', 'Hola')"));
Console.WriteLine(rexx.Run("x = 42; return vars()"));
Console.WriteLine(rexx.Run("old = value('color', 'red', 'APP'); return old value('color', , 'APP')"));
Console.WriteLine(rexx.Run("signal on syntax; return hypot(1)\n" +
                           "syntax: return condition('O')~code"));
```

```text
5
Hello, Rony! Hola, JM!
VARS sees x = 42
blue red
40.3
```

**Both ways in one process.** .NET objects passed to Rexx are `.NetObject`s
(`net.cls` is loaded on first need), and Rexx code can use `.net` as in a Rexx
program; they come back to .NET as themselves. Rexx objects go to .NET as
`RexxObject`s; a Rexx Array or StringTable is copied for a parameter that is
a .NET array, list or dictionary, and goes as itself to a `RexxObject`
parameter. .NET code called from Rexx
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
queued event model, arrays from 1, `box` / `unbox` with BSF4ooRexx's
indicators), with the differences the design notes mark **Δ**: names
caseless with the uppercase member winning, an unknown member an error
rather than `.js~undefined`.

## 12. COM objects (Windows)

`.net~createObject(progID)` creates a COM object (Excel, Word, the
`Scripting` objects...). With no .NET interop type, it is reached through
`IDispatch`, late-bound, as `.OLEObject` reaches it, and with the same Rexx
syntax as any `.NetObject`: messages by name, caseless; `o~Name = v`;
`o[i]` for the default member; DO OVER a COM collection. Arguments go as
`.OLEObject` sends them: `.true` and `.false` as booleans; a Rexx number as
a number, an `int` if whole and within 32 bits, else a `double`
(`.net~box("string", "007")` keeps a string); a multidimensional Array as a
`SAFEARRAY` of its rank (Excel: `range~Value = grid`); an omitted argument
as "not given". Each call is made in English (US), as VBA's: Excel
reads `=SUM(...)` on any Windows. `.net~createObject(progID, "user")` makes
the calls in the user's language instead, as `.OLEObject` does (a Spanish
Windows: `=SUMA(...)`), and a culture name (`"es-ES"`) in that one; the
objects it returns keep that language. `.net~releaseObject(o)` releases it at
once (Excel's process can end).

An object that already exists: `.net~getObject(moniker)` is the object a
moniker names, as `.OLEObject~GetObject` and VBA's `GetObject(path)` give
it: a document file (opened by its application), or WMI through
`"winmgmts:"`; `.net~getActiveObject(progID)` is the running instance of a
class (VBA's `GetObject(, "Excel.Application")`; an Excel opened by hand),
an error if none runs. Both take the language as `createObject` does.
`.net~named(name, value)` is a named argument, VBA's `name:=value`,
anywhere among the others: `excel~Workbooks~Open(file,
.net~named("ReadOnly", .true))`.

```rexx
wmi = .net~getObject("winmgmts:\\.\root\cimv2")
do os over wmi~ExecQuery("select Caption, Version from Win32_OperatingSystem")
  say os~Caption os~Version
end
```

**From `.OLEObject`**, at a glance (`samples/oorexx-ole` has ooRexx's own
OLE samples converted this way):

| `.OLEObject` | the .NET bridge |
|---|---|
| `.OLEObject~new(progID)` | `.net~createObject(progID)`, and `::requires "net.cls"` at the end |
| `.OLEObject~GetObject(moniker)` (a file, `"winmgmts:"`) | `.net~getObject(moniker)` |
| `.OLEObject~new(progID, , .true)` (undocumented: the running one) | `.net~getActiveObject(progID)` (an error if none runs) |
| `o~method(args)`, `o~property`, `o~property = v`, `o[i]`, `DO x OVER o` | the same |
| `o~getConstant(name)` | `.net~getConstant(o, name)`; all of them: `.net~getConstant(o)` (a StringTable) |
| `o~getKnownMethods`, `o~getKnownEvents` | `.net~getKnownMethods(o)`, `.net~getKnownEvents(o)` (the same stems) |
| `o~progid`, `o~clsid` | `.net~getKnownMethods(o)`'s `!PROGID`, `!CLSID` |
| `.OLEVariant~new(v)` for an argument by reference, `~!varValue_` | `.net~ref(v)`, `~value` |
| a string that must stay a string (`"007"`) | `.net~box("string", "007")` |
| `"WITHEVENTS"`, `o~addEventMethod(name, m)`, `o~connectEvents` | `o~Name += .net~handler(object, message)` (`-=` to disconnect) |
| an event's parameter by reference (Excel's `Cancel`) | it arrives as a `Rexx.Net.ComRef`: `ref~Value = .true` |
| `call SysSleep 1` while events come | `.net~nextEvent(1)` (or `.net~eventLoop`) |
| `o~dispatch(name)` (a name Rexx also has: `start`) | `.net~invoke(o, name)` |
| — (no named arguments) | `.net~named(name, value)`, VBA's `name:=value` |
| the user's language for every call | English (US), as VBA; the user's: `.net~createObject(progID, "user")` |
| `drop o` (released at the next collection) | `.net~releaseObject(o)` (Excel's process can end now) |

`.net~getConstant(o, name)` is a constant of the type library `o` comes
from, as `.OLEObject`'s `o~getConstant(name)`: `.net~getConstant(excel,
"xlHAlignRight")`, caseless, `.nil` if there is none; `.net~getConstant(o)`
gives them all, a `StringTable`. (Each library has its own: DAO's `dbText`
comes with a DAO object, not with `Access.Application`.) A `.NetRef` goes by
reference, as an `.OLEVariant` does: `n = .net~ref(0);
conn~Execute(sql, n); say n~value` (ADO's records affected).

Its events are .NET events: `o~Name += h`, `o~Name -= h`,
`.net~addHandler(o, "Name", h)`, `o~add_Name(h)`; `.net~events(o)` lists
them. The method gets the event's parameters; one passed by reference
arrives as a `Rexx.Net.ComRef`, and `ref~Value = x` gives the event's source
a new value when the method returns (Excel's `Cancel`):

```rexx
excel = .net~createObject("Excel.Application")
w = .Watcher~new
excel~SheetChange += .net~handler(w, "CHANGED")
excel~WorkbookBeforeClose += .net~handler(w, "CLOSING")
book = excel~Workbooks~Add
book~Worksheets~Item(1)~Range("A1")~Value = 42    -- SheetChange, during the call
book~Close(.false)                                  -- refused
say excel~Workbooks~Count                           -- 1
excel~DisplayAlerts = .false; excel~Quit; .net~releaseObject(excel)
::requires "net.cls"
::class Watcher
::method changed
  use arg sheet, range
  say "changed:" range~Address
::method closing
  use arg book, cancel
  cancel~Value = .true
```

COM delivers the events of another process (Excel) to a Rexx thread while
that thread waits in .NET: during a call to the COM object (as above), in
`.net~nextEvent(seconds)` or `.net~eventLoop`. `samples/office/` has
Excel, Word and PowerPoint programs written twice, with `.OLEObject` and
through the bridge, events included; `samples/oorexx-ole/`, the OLE samples
that come with ooRexx for Windows, through the bridge.
