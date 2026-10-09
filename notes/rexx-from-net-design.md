# .NET → ooRexx: Rexx in .NET applications — design proposal

*08/10/2026. Written as a proposal; the sections "Phase X: built" record
what was built and what changed. Frame:
`decisions-20261008.md` (7: both `dynamic` and `SendMessage`; 8: packaging);
the other direction is `netobject-design.md`, and this document shares its
assembly, its conventions and its vocabulary. The architecture was verified
before writing (`smoke/hostapi/`, see "Verified"). Every departure from an
earlier plan is marked **Δ** with its reason.*

## Goal

Any .NET application (C#, F#, VB, PowerShell) runs Rexx code and uses Rexx
objects as .NET objects.

```csharp
using Rexx.Net;

using var rexx = RexxInterpreter.Create();
Console.WriteLine(rexx.Run("use arg a, b; return a + b", 2, 40));   // 42

var pkg = rexx.LoadPackage("account.cls");
dynamic acct = pkg.FindClass("Account").New(100);
acct.Deposit(50);
int balance = acct.Balance;                       // 150
try { acct.Withdraw(1000); }
catch (RexxException e) { Console.WriteLine($"{e.Code} line {e.Line}: {e.Message}"); }

rexx.AddCommandEnvironment("APP", cmd => app.Execute(cmd));   // ADDRESS APP 'open'
rexx.Local["FORM"] = myForm;                       // .form (.local~form), a .NetObject in Rexx
rexx.RunFile("macro.rex");                         // the user's macro drives the app
```

What it is for:

- **Rexx as the macro language of a .NET application**, Rexx's classic role:
  the application gives Rexx its own `ADDRESS` environment and its objects,
  the user writes the macros.
- **Rexx libraries and classes used from .NET** (a `.cls` as a component).
- **PowerShell**: `Add-Type -Path Rexx.Net.dll`, then the same API.
- **Both ways in one process**: .NET hosts Rexx, Rexx uses .NET (`.net`),
  .NET receives Rexx objects back, and so on, with one runtime, one bridge,
  one handle table.

## Architecture

### No native shim: the object API straight from C#

**Δ** The initial plan was "a small native shim exporting
plain C functions", because the object API is a C++ function table. It is
not needed. The API is two tables of function pointers
(`RexxInstanceInterface`, `RexxThreadInterface` in `oorexxapi.h`), plain C
structs (the C++ classes only wrap them), and C# calls function pointers
directly (`delegate* unmanaged<…>`). Only `RexxCreateInterpreter` is an
exported function (`[DllImport("rexx")]`).

- Every member of both tables is one pointer-sized slot (function pointers,
  `wholenumber_t`, the `RexxNil` / `RexxTrue`... values): checked against the
  header (`smoke/hostapi/layout.cpp`, 8 + 147 members, all in their slots).
  The slots are generated from the header (`gen-slots.sh` → `Slots.cs`).
- The tables are the ABI every native ooRexx extension already depends on:
  append-only, versioned (`interfaceVersion`: instance 101, thread 103 for
  5.0). At start the library checks the versions and refuses older ones with
  a clear message.
- No variadic functions anywhere in the tables, so nothing needs C.

Gains: the NuGet package is **managed only** (AnyCPU, no native binaries per
platform, nothing to compile on Windows); one fewer moving part. Cost: the
slot numbers must follow the header (generated, checked at build).

### One assembly, two ways in

The managed half of the other direction (`Rexx.Net.dll`) and this API are
**one assembly**. It enters the process in one of two ways:

- **Host mode**: the .NET application loads `Rexx.Net` and calls
  `RexxInterpreter.Create()` (→ `RexxCreateInterpreter`).
- **Guest mode**: ooRexx is the host. `net.cls` loads `rexxnet`, which
  starts the CLR and the same assembly. The .NET code that Rexx calls can then
  use the calling interpreter (`RexxInterpreter.Current`) and the Rexx objects
  it receives (`RexxObject`, the type that `netobject-design.md` already
  names for "any other Rexx object").

### One process, both ways

Verified with the current bridge:

- In a .NET application that hosts ooRexx, Rexx code that does `::requires
  "net.cls"` works. `rexxnet`'s `hostfxr_initialize_for_runtime_config`
  attaches to the runtime already running, not a second one: same process,
  and the host's own types and statics are visible from Rexx.
- But `rexxnet` loaded `Rexx.Net.dll` through
  `hdt_load_assembly_and_get_function_pointer`, which puts it in an
  **isolated** `AssemblyLoadContext`. A host that also uses `Rexx.Net` would
  then have two copies, with two handle tables and two different `RexxObject`
  types. **Changed this session** (`bridge/native/rexxnet.cpp`): `rexxnet`
  now asks the runtime for `Rexx.Net.Bridge, Rexx.Net` first
  (`hdt_get_function_pointer`: the application's own copy, if it has one),
  and only otherwise loads the one next to itself into the **default**
  context (`hdt_load_assembly`, .NET 8). Result: one copy, one handle table
  (the host sees the handles that Rexx creates). The 93 phase-1 tests pass
  unchanged. It also helps ooRexx-hosted programs: `.net~load`ed assemblies
  and the bridge now share the default context.
- What was left was the guest-mode plumbing (phase C, built: see "Phase C: built"), not a second-runtime problem. Limit: attaching to a running runtime needs an
  application started through `hostfxr` (the `dotnet` muxer or an apphost:
  ordinary applications and `pwsh`). For a NativeAOT or custom-hosted
  application, the managed side would hand its entry points to `rexxnet`
  (an exported registration function) instead. That is designed but not
  needed yet.

### Finding librexx

Name `rexx` (`librexx.so`, `rexx.dll`, `librexx.dylib`) resolved by a
`NativeLibrary` resolver: `REXX_HOME` if set, then the system's search
(`PATH` on Windows, where the ooRexx installer puts it). In guest mode the
library is already loaded: same handle. ooRexx itself is not shipped in the
NuGet package (an installed ooRexx 5.0 or later is a prerequisite, as Java is
for BSF4ooRexx).

## C# surface

### `RexxInterpreter` (an instance; `IDisposable`)

| C# | ooRexx API |
|---|---|
| `RexxInterpreter.Create(options?)` | `RexxCreateInterpreter` |
| `RexxInterpreter.Current` | guest mode: the instance whose Rexx code called .NET |
| `Run(source, args...)` → `RexxObject?` | `NewRoutine` + `CallRoutine` (the source as a routine: `use arg`, `return`) |
| `Run<T>(source, args...)` | the same, converted (see Values) |
| `RunFile(path, args...)` | `CallProgram` |
| `Compile(name, source)` → `RexxRoutine` | `NewRoutine`, to call many times |
| `LoadPackage(path)`, `LoadPackage(name, source)` → `RexxPackage` | `LoadPackage`, `LoadPackageFromData` |
| `FindClass(name)` → `RexxClass` | `FindClass` (`.environment`, the package's) |
| `Environment`, `Local` | `.environment`, `.local` (`GetGlobalEnvironment`, `GetLocalEnvironment`) as `RexxObject`s, indexable |
| `AddCommandEnvironment(name, handler)` | `AddCommandEnvironment` (see Commands) |
| `Halt()` | `Halt` (every Rexx thread of the instance) |
| `Trace = true` | `SetTrace` |
| `Dispose()` | `Terminate` |

`RexxOptions`: `InitialAddress`, `ExternalCallPath`, `ExternalCallExtensions`,
`LoadLibraries`, `Output` / `Error` / `Input` (`TextWriter` / `TextReader`,
through the I/O exits), `ApplicationData`. These are the API's own options
(`INITIAL_ADDRESS_ENVIRONMENT`, `EXTERNAL_CALL_PATH`, `DIRECT_EXITS`…).

### `RexxObject` (any Rexx object; a `DynamicObject`)

Decision 7: both `dynamic` and explicit.

| C# | Rexx |
|---|---|
| `o.Send("name", args...)` → `RexxObject?` | `o~name(args...)` |
| `o.Send<T>("name", args...)` | the same, converted |
| `dynamic d = o; d.Deposit(50)` | `o~DEPOSIT(50)` |
| `d.Balance` | `o~BALANCE` (a method with no arguments: Rexx makes no difference between an attribute and a method) |
| `d.Balance = 5` | `o~BALANCE=(5)` |
| `d[i]`, `d[i, j] = v` | `o[i]`, `o[i, j] = v` (Rexx's own indexing, 1-based for Arrays) |
| `d + 1`, `d * 2`, `d < 3`… | `o + 1`… (the Rexx operator as a message) |
| `int n = d`, `(double)d`, `(bool)d` | the string value, converted (see Values) |
| `foreach (var x in o)` | `o~supplier` items (live, in Rexx's order) |
| `o.Supplier()` → `(index, item)` pairs | `o~supplier` |
| `o.ToString()` | `o~string` |
| `o.Is(rexxClass)`, `o.HasMethod("name")` | `IsInstanceOf`, `HasMethod` |
| `o.Dispose()` | releases the reference now (optional; see Lifetime) |

Typed views over the same objects: `RexxClass` (`New(args)`), `RexxRoutine`
(`Call(args)`, and `dynamic r; r(1, 2)`), `RexxPackage` (`FindClass`,
`Classes`, `Routines`, `PublicClasses`…: the package functions of the API).

**Names.** A dynamic member name is uppercased, as Rexx does for every
message (`acct.Deposit` sends `DEPOSIT`). `Send` uppercases too: ooRexx has
no other kind of method name in practice (to confirm: `setMethod` with a
lowercase name). No guessing and no case clashes, unlike the other direction.

**Named arguments.** ooRexx 5 has them, but the native `SendMessage` does not
take them. C# named arguments (`d.Open(path, mode: "r")`) are an error in v1.
Later, possibly through Rexx's own `sendWith` if it carries named arguments
(to check).

## Values

**.NET → Rexx** (arguments, `Local[...] =`, results of command handlers)

| .NET | Rexx |
|---|---|
| `string`, `char` | a String |
| `int`, `long`, `double`, `decimal`, every numeric type | a String with the number, culture-invariant (`double`: round-trip, `NaN`/`Infinity` as such) |
| `bool` | `1` / `0` (`.true` / `.false`) |
| `null` | `.nil` |
| a `RexxObject` | the Rexx object itself |
| `RexxValue.Omitted` | an omitted argument (`arg(2, 'O')` is true) |
| any other object (arrays and collections included) | a `.NetObject`, by reference (`net.cls` loaded on first need) |

Copies are explicit: `rexx.NewArray(items)` makes a Rexx Array,
`rexx.NewDirectory(pairs)` / `NewStringTable(pairs)` make a Directory or a
StringTable, items converted as above. That is the same principle as the
other direction (objects by reference, copies on request), and the reverse
of its "Rexx Array → .NET array" conversion, which happens there only because
a .NET parameter type asks for it.

**Rexx → .NET** (results)

| Rexx | .NET |
|---|---|
| `.nil` | `null` |
| a String | a `RexxString` (a `RexxObject` that holds the value: copied, no handle) |
| a `.NetObject` | **the .NET object itself** (round trip; where the result is typed `RexxObject`, a proxy whose `NetValue` is the object: see "Phase C: built") |
| any other object | a `RexxObject`, by reference (the same proxy each time: identity) |

**Δ A `RexxString`, not a `string`.** Rexx has one kind of value, and whether
it is a number depends on its use. With plain `string`s, `int b =
acct.Balance` fails at run time (C# has no implicit `string` → `int`). A
`RexxString` converts implicitly to `string`, every numeric type (by Rexx's
rules: `" 1E3 "` is 1000), `bool` (`1` / `0`; anything else is an error, as in
Rexx), `char`; prints as its value; and its operators are Rexx's (`d + 1`
sends `+`, so `"150" + 1` is `151`, as in Rexx). The explicit API offers
`Send<string>` / `Run<int>`… for code that does not want `dynamic`.

**Equality.** `RexxString`s compare by value (Rexx's strict `==`: `Equals`,
`GetHashCode`, C# `==`), so they work as dictionary keys. Other `RexxObject`s
compare by identity (one proxy per Rexx object). C# `==` on two `dynamic`
Rexx objects sends Rexx `==` (open point 6).

## Threads

- **Any .NET thread may call Rexx.** If the thread is not running Rexx, the
  call attaches it (`AttachThread`), runs, and detaches. If it is already
  inside Rexx (guest mode: .NET code called from Rexx; a callback; a command
  handler), the call uses that thread's context. That nesting was verified in
  `smoke/callbacks/`, and the current context is kept on a thread-static
  stack.
- **The cost of attaching** (measured): a message on an attached thread
  ~1 µs, attach + message + detach ~22 µs. So `using (rexx.Enter()) { ... }`
  keeps the thread attached for a batch of calls. Threads are not left
  attached behind the program's back (thread-pool threads live forever, and
  `Terminate` should not find strangers).
- **One Rexx thread runs at a time** (the interpreter's lock): .NET threads
  calling Rexx take turns. Verified: 4 .NET threads × 1000 `deposit`s on one
  object, all counted. Rexx's own concurrency (`reply`, `~start`)
  interleaves as usual.
- **Halting.** `rexx.Halt()` stops every Rexx thread of the instance: a HALT
  condition, reported as a `RexxException` (4.1 "Program interrupted").
  Verified from another thread. `Run(..., CancellationToken)` halts only
  the thread doing that run. **Δ** Not `HaltThread` (it must run on the halted
  thread itself) but the classic `RexxSetHalt`: see "Phase B: built".
- **No async API in v1.** Rexx code is synchronous. `Task.Run(() =>
  rexx.Run(...))` works because any thread can attach. A Rexx message object
  (`~start`) could later be exposed as a `Task` (`SendAsync`).

## Lifetime

- A `RexxObject` holds a **global reference** (`RequestGlobalReference`), and
  the local reference the call returned is released at once. So a long loop
  in one context does not pile up local references.
- Released by `Dispose()` or, failing that, by the finalizer. The finalizer
  runs on its own thread, where no context exists, so it only queues the
  release. Queued releases go with the next call into the instance and at
  `Terminate` (the same idea as `.JSObject`'s batched releases).
- Identity: a table from the Rexx object (its pointer) to a weak reference
  to its proxy, so one Rexx object has one proxy while the proxy lives
  (assumes the ooRexx collector does not move objects: to confirm in its
  source).
- `RexxString`s hold no reference at all.

## Errors

- A Rexx condition that ends a call (SYNTAX, HALT; also compile errors in
  `Run`, `Compile`, `LoadPackage`) becomes a **`RexxException`**: `Code`
  (`"88.900"`), `Rc` (88), `Message` (the secondary message, else the error
  text), `ErrorText`, `Program`, `Line`, `Traceback`, `Condition` (the
  condition object, a `RexxObject`). Verified: a `raise syntax 88.900` in a
  method comes back with its code, its message and line 6; a compile error
  comes back as 35.1.
- **Round trip.** If the condition is the other direction's 98.900 with a
  .NET exception in `additional[2]` (a .NET method called from Rexx threw),
  that original exception becomes the `RexxException`'s `InnerException`.
- **The reverse**: a .NET exception thrown in code that Rexx called
  (guest-mode calls, callbacks) becomes SYNTAX 98.900 in Rexx, as in the
  other direction. **Δ** Not in command handlers: there it raises FAILURE,
  Rexx's own way for a command that could not run (see "Phase B: built").

## Commands and I/O

*(Built in phase B: see "Phase B: built" for what changed, marked Δ.)*

- **`ADDRESS` environments**: `rexx.AddCommandEnvironment("APP", handler)`,
  where `handler` is a `Func<RexxCommand, object?>` (or an
  `Action<RexxCommand>`). The `RexxCommand` carries the address, the command
  (it converts to `string`, so `cmd => app.Execute(cmd)` works), the calling
  Rexx code's variables, and `ADDRESS ... WITH` redirection. Its result is
  `RC`. A thrown `RexxCommandException(rc)` raises ERROR (or FAILURE); any
  other .NET exception raises FAILURE (`RC` -1). Verified first in the probe:
  `address dotnet 'open the door'` reaches a C# function, which sets `RC`.
  The handler is one fixed native entry (`[UnmanagedCallersOnly]`) that
  dispatches by instance and name; no delegate is ever handed to native code.
- **I/O**: `say`, `lineout` / `charout`, `.output`, `.error`, trace output,
  `pull` / `linein` / `charin` go to the `Output` / `Error` / `Input`
  `TextWriter` / `TextReader` (options, or properties at any time). That
  matters for GUIs and PowerShell. **Δ** Through the `.local` monitors, not
  the RXSIO exits (see "Phase B: built").
- **Not a sandbox.** Rexx code can do what the process can (`ADDRESS
  SYSTEM`, files, `.net`). An application that wants less sets
  `InitialAddress` to its own environment and does not load `net.cls`. It
  is not a security boundary, and the documentation says so.

## Packaging (decision 8)

- **NuGet `Rexx.Net`**: one managed assembly (the hosting API + the managed
  half of `.net`). Target `net8.0`, runs on later runtimes. Prerequisite: an
  installed ooRexx 5.
- **The ooRexx extension package** (`net.cls`, `rexxnet`, `Rexx.Net.dll` +
  runtimeconfig) ships the same assembly. A .NET application that hosts Rexx
  and uses `.net` needs only its NuGet reference plus `rexxnet` and `net.cls`
  where ooRexx finds them.

## Relation to the sister bridges

- **`.JSObject`**: no reverse direction. JavaScript cannot enter the
  interpreter (everything is queued). Nothing to share, except the
  conventions of values and errors, kept here.
- **BSF4ooRexx**: Java does have this direction (a Java object holding a
  Rexx object and sending it messages; the scripting-engine interface). The
  nearest analogue to `RexxObject`.
- **ooRexx/Python**: the reverse direction will meet the same questions
  (strings, names, threads), so it belongs in the shared conventions
 .

## Phases

- **A. Core** *(built: see "Phase A: built")*: the tables, `RexxInterpreter` (create, `Run`, `Compile`,
  `RunFile`, `LoadPackage`, `FindClass`, `Environment` / `Local`,
  `Terminate`), `RexxObject` (`Send`, `dynamic`, indexers, operators,
  conversions, enumeration), `RexxString`, values, `RexxException`, threads
  (attach per call, the context stack, `Enter`), lifetime (global
  references, queued releases, identity). Tests here, in Linux.
- **B. Environment** *(built: see "Phase B: built")*: command
  environments, I/O, `Halt` / cancellation, trace.
- **C. Both ways in one process** *(built: see "Phase C: built")*: .NET objects to Rexx
  as `.NetObject` (loading `net.cls` on first need), `.NetObject`s back as
  their objects, Rexx objects passed from Rexx to .NET methods as
  `RexxObject` (`rexxnet` gives the managed side its thread context with each
  request, and the instance when the CLR starts), the 98.900 round trip.
- **D. Packaging and Windows**: NuGet, `librexx` lookup on Windows, a
  PowerShell sample.

## Verified (08/10/2026, `smoke/hostapi/`, ooRexx 5.3.0 r13254, .NET 8)

`run.sh`: the layout check, then 11 probes from C# through the tables, with
no native code of ours: create an instance (version 5.3.0); a routine from
source with arguments; objects kept by global reference and sent messages; a
package from source, its class, `~new`, methods; a SYNTAX error decoded
(code, message, line) and a compile error; 4 .NET threads attaching at once;
`ADDRESS DOTNET` handled by a C# function; `Halt()` from .NET stopping a
looping Rexx thread; and the three "both ways" checks above (`.net` in a
.NET host; the host's types and statics; one `Rexx.Net`, one handle table).

Found on the way, for the other direction's phase 2: a member of an object
whose runtime type is not public (a compiler-generated iterator, as
`AssemblyLoadContext.All` returns) is not found (`GetEnumerator`). C# would
use the static type, a public interface. The bridge should look through
public base types and interfaces when the runtime type is not public.

## Open points (as they were raised)

1. **No native shim**: the API's function tables called from C#, slots
   generated from the header and checked at build.
2. **Rexx strings as `RexxString`** (converting implicitly, Rexx operators),
   not as `string`.
3. **.NET objects to Rexx by reference** (`.NetObject`), arrays and
   collections included; copies only through `NewArray` / `NewDirectory`.
4. **Attach per call by default**, `rexx.Enter()` for batches; never left
   attached implicitly.
5. **Names uppercased** (dynamic and `Send`); named arguments not in v1.
6. **Equality**: `RexxString` by value, other objects by identity; C# `==` on
   `dynamic` sends Rexx `==`.
7. **One assembly** for both directions (`Rexx.Net`), and the change to
   `rexxnet` (default load context), already made.

## Phase A: built (08/10/2026)

Built before the design was discussed with others, knowing that parts of the API may change with it. In `bridge/managed/Host/`
(same assembly, `Rexx.Net`): `Slots.cs` (generated by
`smoke/hostapi/gen-slots.sh`, now writing both copies), `Api.cs` (the
library, the instance and thread tables as structs), `RexxInterpreter.cs`,
`RexxObject.cs` (`RexxObject`, `RexxString`, `RexxClass`, `RexxRoutine`,
`RexxPackage`, `RexxConvert`), `RexxException.cs` (moved out of
`Callbacks.cs`; one class for both directions). Tests: `tests/HostTests/`
(a C# application hosting ooRexx, 75 tests), run by `tests/run.sh` after
the three Rexx phases. All pass on .NET 10 and .NET 8, three runs each; the
smoke tests too.

Built as designed: `RexxInterpreter.Create(options)` (`InitialAddress`,
`ExternalCallPath`, `ExternalCallExtensions`, `LoadLibraries`), `Version`,
`LanguageLevel`, `Run` / `Run<T>`, `RunFile`, `Compile`, `LoadPackage`
(file, or name + source), `FindClass`, `Environment`, `Local`, `NewArray`,
`NewDirectory`, `NewStringTable`, `Halt`, `Trace`, `Enter`, `Dispose`;
`RexxObject` with `Send` / `Send<T>`, an indexer, `Is`, `HasMethod`,
`Supplier`, `foreach`, `ToString`, `Dispose`, and `dynamic` (members,
methods, attributes, `[]`, Rexx's operators, conversions, `if (d)`);
`RexxString`; `RexxClass.New`, `RexxRoutine.Call` (and `r(args)` through
`dynamic`), `RexxPackage` (`FindClass`, `Classes`, `PublicClasses`,
`Routines`, `PublicRoutines`, `Name`); `RexxValue.Omitted`; `RexxException`
(`Code`, `Rc`, `Message`, `ErrorText`, `Program`, `Line`, `Traceback`,
`Condition`); the version check (instance API 101, thread API 103: ooRexx
5.0); `librexx` found by `REXX_HOME`, then the system's search, then the
usual installation directories (the tests run with no `LD_LIBRARY_PATH`).
Threads: attach per call on any thread, the creating thread's own context,
`Enter()` for a batch, a thread-static stack of frames (ready for guest
mode's contexts). Lifetime: one global reference per proxy, `Dispose`, the
finalizer's queued releases (flushed at the next call), identity (one proxy
per Rexx object while it lives).

**Changed or settled while building it (to confirm):**

1. **Δ `RexxString`'s conversions are explicit, not implicit.** With
   `dynamic`, C#'s own binding comes first and the object's only after it
   fails: an implicit conversion to `string` made `d + 1` a concatenation
   (`"150" + 1` = `"1501"`) instead of Rexx's `+`. Explicit conversions
   (`(int)s`, `(string)s`, `Convert.ToInt32(s)`: `IConvertible`) keep C#
   out, and through `dynamic` everything still converts implicitly
   (`int n = acct.Balance`, `string t = acct.Balance`: `TryConvert`).
   Statically typed, `s.Value` or a cast. (Also avoids ambiguous overloads,
   `Console.WriteLine(s)`.)
2. **Every instance of `.String` is a `RexxString`**, not only the class
   String itself: numbers made by arithmetic are an internal subclass
   (`RexxInteger`, `RexxNumberString`) that the API's `IsString` rejects,
   and `StringData` on them reads garbage (both found by the tests):
   `IsInstanceOf(.String)`, and the value through `ObjectToString`.
3. **Local references, released one by one.** The creating thread's
   context lives as long as the instance, and every local reference left
   there is a leak that also makes every later release slower (a list
   searched linearly): measured, a call that returned its String argument
   went from 2 µs to 800 µs over 100 000 calls, and the process grew by
   0.8 KB per call. Every argument string, argument Array,
   `ObjectToString` result (**a new local reference even when it is the
   object itself**), supplier, traceback item and `DecodeConditionInfo`
   string is released as soon as it is used. Now flat: ~1.2 µs a message
   with no arguments and no result, ~2.5–3 µs with an argument and a
   string or number back. A regression test (`HostTests`, on a fresh
   instance on its own thread) fails if the cost per call grows by 4× over
   20 000 calls; checked by putting the bug back (27 → 183 µs, caught). (On
   the tests' main instance the bug did not show, after all the earlier
   work: not understood; the fresh instance is what the test uses.)
4. **The indexer is typed `object?`**, so that any value can be set
   (`rexx.Local["FORM"] = form`, `arr[3] = 5`); what it gets is a
   `RexxObject` or null.
5. **`Environment` and `Local` keep Rexx's case**: `.form` looks up `FORM`,
   so `rexx.Local["FORM"] = ...` (as `.local["FORM"]` in Rexx). The Goal's
   example is corrected.
6. **Enumeration is a snapshot** (the supplier read in one go), not live
   as the table above said: a lazy enumerator would hold a Rexx context
   across the caller's code.
7. **Error codes as Rexx writes them**: `"98.900"`, `"35.1"`, `"41.1"` (the
   callbacks' `RexxException` and `rexxnet`'s report wrote `"41.001"`:
   fixed there too). An untrapped HALT ends a call as **Error 4.1**
   (`ConditionName` `SYNTAX`), as the design said; a class's `Name` is its
   Rexx id (`ACCOUNT` for `::class Account`).
8. **Not in phase A**: a .NET object other than strings, numbers, bools,
   enums and Rexx objects cannot go to Rexx yet (`NotSupportedException`
   naming phase C, where they become `.NetObject`s); `Dispose` of the
   instance only on its creating thread (`Terminate`'s rule); a
   `RexxString` made with `new RexxString("x")` belongs to no instance
   (Rexx operators on it need one).

**Measured** (.NET 10, this container): a message from the creating thread
~1.2 µs (no arguments, no result) to ~3 µs (an argument, a number back);
`dynamic` ~0.5–2 µs more; attach + message + detach from another thread
~10 µs; inside `Enter()` as on the creating thread; `Run` ~20 µs (it
compiles each time: `Compile` once and `Call`).

## Phase B: built (08/10/2026)

Built after phase A. In `bridge/managed/Host/`:
`RexxCommand.cs` (new: `RexxCommand`, `RexxCommandException`, the native
entry), `RexxInterpreter.Environment.cs` (new, a part of `RexxInterpreter`:
command environments, I/O, cancellation), and additions to `Api.cs` (the
exit context, the I/O redirector, `RaiseCondition` / `RaiseException`,
`AddCommandEnvironment`, `RexxSetHalt`), `RexxInterpreter.cs` (the options,
the instance registry, frames pushed by native callbacks) and
`RexxObject.cs` (`RexxRoutine.Call` with a token). `smoke/hostapi/gen-slots.sh`
now generates four tables (also `ExitContextInterface`,
`IORedirectorInterface`), all checked by `layout.cpp`. Tests:
`tests/HostTests/PhaseB.cs` (60 tests; 136 host tests in all, with a
command and a SAY added to the local-reference regression checks). All
pass on .NET 10 and .NET 8, three runs each; the smoke tests too.

The surface:

```csharp
var err = new StringWriter();
using var rexx = RexxInterpreter.Create(new RexxOptions { Output = myWriter, Error = err });
rexx.AddCommandEnvironment("APP", cmd => app.Execute(cmd));      // RC = its result
rexx.AddCommandEnvironment("EDITOR", (RexxCommand cmd) =>
{
    string file = cmd["FILE"]?.ToString() ?? "";                // the caller's variables
    if (!File.Exists(file)) throw new RexxCommandException(28, "no such file");   // ERROR, RC 28
    cmd["LINES"] = File.ReadAllLines(file).Length;
    if (cmd.IsRedirected)                                       // ADDRESS EDITOR 'x' WITH ...
        for (string? l; (l = cmd.ReadLine()) != null;) cmd.WriteLine(l.ToUpperInvariant());
});
rexx.Input = new StringReader("yes\n");                       // PULL, LINEIN, CHARIN
using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
try { rexx.RunFile("macro.rex", cts.Token); }
catch (OperationCanceledException) { /* halted: InnerException is the RexxException 4.1 */ }
```

**Changed or settled while building it (to confirm):**

1. **Δ I/O through the monitors of `.local`, not the RXSIO exits.** Measured
   first: everything the Rexx code writes or reads goes through `.output`,
   `.error` and `.input` (all `.Monitor`s): `say`, `lineout` / `charout` to
   the default stream and to `"STDERR"`, `.output~lineout`, trace output
   (`.traceoutput` writes to `.error`; its lines are `TraceObject`s, whose
   `makeString` is the line), `pull` / `parse pull` / `linein()` /
   `charin()` / `.input~linein`, interactive trace input (`.debuginput`
   reads `.input`). The RXSIO exits see only SAY, trace and terminal reads,
   and must be set at creation. So the first time `Output`, `Error` or
   `Input` is set, a small Rexx object (`RexxNetStream`, source in
   `RexxInterpreter.Environment.cs`) becomes the destination of all three
   monitors; it sends what it gets to an internal command environment
   (`REXXNET.IO`), whose handler writes the `TextWriter` (or reads the
   `TextReader`); while a property is null, its forwarder passes everything
   to the stream it replaced (`forward to`), and messages it does not know
   go there too. Properties settable at any time (and `RexxOptions`
   `Output` / `Error` / `Input` at creation). Not caught: `.stdout` /
   `.stderr` / `.stdin` used directly, and processes started by `ADDRESS
   SYSTEM`. Rexx code may still push its own destination (verified: it gets
   the output until it pops it). An error that ends a call from .NET is not
   written (it is the `RexxException`); an error in a Rexx thread of its own
   (`reply`, `~start`) is, as Rexx writes it. At an input's end, reads give
   `""` and `lines()` 0. Cost: ~7 µs a SAY inside a loop (a Rexx method, a
   command, the writer).
2. **One handler signature, `Func<RexxCommand, object?>`** (and
   `Action<RexxCommand>`, RC 0), rather than a `Func<string, object?>` plus
   one with a context: two lambda-friendly overloads with different
   parameter types would make `c => null` ambiguous. `RexxCommand` converts
   implicitly to `string`, so a method taking the command string can be the
   handler. `RexxCommand`: `Address` (as the Rexx code wrote it: `app` for
   `ADDRESS 'app'`), `Command`, `Interpreter`; the caller's variables
   (`cmd["X"]`, `cmd["STEM.1"]`, set — null sets `.nil` —, `HasVariable`,
   `Drop`, `Variables`: a copy), names uppercased; redirection
   (`IsRedirected`, `IsInputRedirected`..., `ReadLine` — null at the end —,
   `ReadToEnd`, `WriteLine`, `Write` — split at line ends —,
   `WriteErrorLine`, `WriteError`; writes return false when that stream is
   not redirected). Valid only while its handler runs (afterwards:
   `InvalidOperationException`). Every environment is registered as a
   redirecting one (`ADDRESS ... WITH` works on all). Names are not
   case-sensitive (ooRexx uppercases them); adding a name again replaces its
   handler; there is no removal (the API has none). Each instance has its
   own environments (verified: two instances, one name). An unknown
   environment is Rexx's own FAILURE, `RC` 30.
3. **Conditions** (as ooRexx's `RexxActivation::command` reads them): a
   result is `RC`, null is `RC` 0, a Rexx object is `RC` as it is.
   `RexxCommandException(rc, message?, failure?)` raises ERROR (or
   FAILURE): `RC` = its rc, `condition('D')` the command, `condition('A')`
   the message. Any other .NET exception raises FAILURE, `RC` -1, its
   message as `condition('A')`; untrapped, it becomes ERROR (Rexx's rule)
   and TRACE N traces it (`+++ "RC(-1)"` on `Error`), so it is not silent.
   **Δ** The design's Errors section said SYNTAX 98.900 for command handlers
   too; FAILURE is Rexx's own meaning ("the command could not run"), and
   98.900 stays for guest-mode calls (phase C). A `RexxException` that comes
   out of Rexx code the handler called (`cmd.Interpreter.Run(...)`) is
   raised again as the same SYNTAX error (its code and substitutions: the
   message is rebuilt, the traceback starts at the command).
4. **Lesson: the exit context's `ThrowCondition` / `ThrowException` cannot
   be called from managed code.** They unwind with a C++ `throw` back to the
   interpreter (`CallContextStubs.cpp`: "don't use try/catch to allow a
   return to the caller"), which cannot cross managed frames: the process
   aborts (`terminate called after throwing an instance of
   'NativeActivation*'`), found by the first test. The thread context's
   `RaiseCondition` / `RaiseException` catch it themselves: the condition
   is recorded, and the interpreter raises it when the handler returns
   (the same path, `handleError`). **Rule for all managed code called by
   ooRexx (phase C too): never call an API function that unwinds** — the
   `Throw*` family of the exit and method contexts.
5. **A handler's own calls into Rexx use its thread context**: the exit
   context's thread context is pushed on the thread-static frame stack while
   the handler runs (the stack built in phase A for guest mode), so
   `cmd.Interpreter.Run(...)` in a handler runs nested on the same thread,
   with no attach (verified on another .NET thread; 4 threads × 100
   commands). Cost: ~1.5–2.5 µs a command inside a Rexx loop.
6. **Cancellation: `Run`, `Run<T>`, `RunFile`, `RexxRoutine.Call` /
   `Call<T>` take a `CancellationToken`.** **Δ** Not `HaltThread`: its
   `ApiContext` takes the kernel lock as the halted thread and validates the
   OS thread, so it can only run on the halted thread itself. The classic
   API's `RexxSetHalt(pid, tid)` (→ `ActivityManager::haltActivity`) takes
   only the resource lock and may be called from any thread: the token's
   callback calls it with the calling thread's OS id (`pthread_self`, or
   `GetCurrentThreadId` on Windows: `thread_id_t` is a `pthread_t` / a
   `DWORD`; the Windows branch is untested). The call then throws
   `OperationCanceledException` (its token; `InnerException` the
   `RexxException` 4.1). A gate keeps a late callback from halting Rexx
   code that comes after the call (verified). Rexx code that traps HALT
   decides: if it returns, the call returns its result. A token already
   cancelled: nothing runs. Only the calling thread is halted (verified, two
   threads). Cancelled while the Rexx code is inside a command handler: the
   halt takes effect at the clause after it. **Limit**: a halt reaches the
   thread's running Rexx frame; one sent before the call's first clause is
   lost (`Activity::halt` with no frame does nothing). `Run` therefore
   compiles before watching the token (the window is microseconds); for
   `RunFile` the window is the file's compilation (`CallProgram` compiles
   inside), written down. `Halt()` (every thread) has the same limit.
7. **`Trace` stays as it was, with its limits written down**: ooRexx's
   `SetTrace` (`traceAllActivities`) only reaches Rexx code running at that
   moment (set before a `Run`, it does nothing: measured), and in an
   experiment turning it off took effect late (the call seems to wait for
   the interpreter's lock while the traced code writes). It is a switch for
   code running on other threads; to trace one run, the Rexx code's own
   `TRACE`. Trace output goes to `Error` (item 1).

**Measured** (.NET 10, this container): a command ~1.5–2.5 µs inside a
Rexx loop (~6 µs as a `Call` from .NET); a SAY through the forwarder ~7 µs
inside a loop; no growth over 120 000 calls (commands, `Run<int>`, SAY with
`Output` set).

**Not done (later, if wanted):** the RXOFNC / RXEXF exits (functions
provided by the application, `appfunc(1, 2)`: today a command, or phase C's
`.NetObject`s); RXVALUE (`value(name, , 'APP')` reading application values);
`Send` with a token; a per-run trace.


## Phase C: built (08/10/2026)

Built after phases A and B, on ooRexx 5.3.0
r13263 (a trunk build; `oorexxapi.h` unchanged: the generated slots are
the same). Changed: `bridge/native/rexxnet.cpp` (the thread context with each
request, records X / G / K, handlers keep their instance, net.cls's classes
handed over), `managed/Bridge.cs` (`Request` takes the context and pushes it
as a frame; `Classes`; a `RexxException` raised again), `Convert.cs` and
`Wire.cs` (X, G, K), `Callbacks.cs`, and in `managed/Host/`:
`RexxInterpreter.BothWays.cs` (new), `RexxInterpreter.cs`, `RexxObject.cs`,
`RexxException.cs`, `RexxCommand.cs`; `build.sh` (rexxnet's soname). Tests:
`tests/HostTests/PhaseC.cs` (48 tests: 183 host tests in all, the phase-A
test that expected `NotSupportedException` gone) and `tests/bothways.rex` with
`tests/TestLib/BothWays.cs` (20 tests, ooRexx as the host). All pass on
.NET 10 and .NET 8, three runs each; the smoke tests too.

```csharp
using var rexx = RexxInterpreter.Create();
var sb = new StringBuilder();
rexx.Run("use arg sb; sb~Append('ab')", sb);                    // a .NetObject in Rexx, by reference
StringBuilder same = rexx.Run<StringBuilder>("use arg o; return o", sb);   // back as itself
rexx.Local["FORM"] = myForm;                                     // .form in Rexx
rexx.RequireNet();                                               // .net without ::requires

// .NET code called from Rexx (rexx.Run(".net~type('MyLib')~Count(.directory~new)"),
// or rexx prog.rex: guest mode)
public static int Count(RexxObject d) => d.Send<int>("ITEMS");   // a Rexx object, by reference
public static int Nested() => RexxInterpreter.Current!.Run<int>("return 6 * 7");   // on this thread, nested
```

**Changed or settled while building it** (item 2's Directory
case still open; item 6 changed later):

1. **The thread context goes with every request** (`Bridge.Request(tc,
   ...)`): the managed side pushes it as a frame for the request's length (the
   stack built in phase A, used by command handlers in phase B), so .NET code
   called from Rexx calls Rexx back nested on that thread, with no attach.
   `RexxInterpreter.Current`: the instance of the innermost frame, null when
   no Rexx code waits on this thread. **Guest mode**: when ooRexx is the host,
   a `RexxInterpreter` is made for its instance on the first request
   (`IsGuest`; never ended: `Dispose` does nothing on it). The design said
   "the instance when the CLR starts"; per request was simpler (and supports
   several instances).
2. **Rexx objects to .NET: a new record X** (the object's pointer, valid while
   the request runs) for any object that is not a string, `.nil`, an Array, a
   `.NetObject` or one of net.cls's own (`.NetRef`, `.NetTyped`,
   `.NetHandler`): it becomes a `RexxObject` (`RexxRoutine`, `RexxClass`,
   `RexxPackage` for those), which takes its own global reference, as in
   phase A (identity: the same proxy each time). Before, these were an error
   ("cannot pass ... to .NET"). Costs: 0 for a `RexxObject` parameter of its
   proxy's type, 1 for a type the proxy is (`object`, `IEnumerable<object?>`,
   `IDisposable`); a Rexx string to `RexxString` 25, to `RexxObject` 26 (a
   `RexxString`): after `string`, `object` and the numbers, so that an
   overload taking one of those wins (found by a test: 11 tied with
   `object`). A `RexxObject` .NET gives back is the Rexx object itself (X:
   inside a request, also held by a local reference of the request, an Array
   holding it, so that it outlives its proxy until Rexx has it); a
   `RexxString`, its string. **Not done**: an Array still goes as a copy (so
   it cannot reach a `RexxObject` parameter as itself), and the other
   direction's design had Directory / StringTable → `Dictionary<string, T>`,
   never built: a Directory is now a `RexxObject`. (Later: only the
   StringTable is the dictionary's equivalent; the Directory case is open,
   see `netobject-design.md`.)
3. **A callback's result that is a Rexx object: record G** ("pointer\t
   instance", a global reference that rexxnet takes before detaching its
   thread, adopted by the managed side; an extra one is released at the next
   call). The callback's own arguments that are `RexxObject`s go as X and the
   delegate keeps them alive during the call (`GC.KeepAlive`).
4. **.NET objects to Rexx: `.NetObject`s**, made by the host side
   (`NetObject~new(id, display)`, a `NetType` for a type's statics; a
   `System.Type` passed from C# is an ordinary object, a `.NetObject`, as
   `o~GetType` is in the other direction), one handle reference per proxy,
   released by its `uninit` (measured: 3 handles left after 40 000 round
   trips). Delegates, arrays and collections too, by reference. **net.cls is
   found** as Rexx finds it (`::requires "net.cls"`: ooRexx's search, the
   current directory included), else in `REXXNET_DIR` or next to
   `Rexx.Net.dll`; rexxnet is loaded first from that directory, so that
   ooRexx finds it there (**Δ** `librexxnet.so` now has its name as
   `soname`: glibc matches an already-loaded library by soname; on Windows,
   `LoadLibrary` matches by module name). Failing that, an
   `InvalidOperationException` with Rexx's own reason ("Unable to load
   library ..."). `HostTests` run with `REXXNET_DIR`. **New**:
   `RexxInterpreter.RequireNet()` loads net.cls so that the host's Rexx code
   can use `.net` without `::requires` (otherwise `.net` is only there after
   the first .NET object went to Rexx, or the code's own `::requires`).
5. **A `.NetObject` back to .NET: the .NET object itself** (a `.NetType`: its
   `System.Type`), wherever the result is typed `object`: `dynamic`
   (members, calls, `[]`, operators), the indexer, `foreach` and `Supplier`,
   `Send<T>` / `Run<T>` / `Call<T>`, a command's variables (`cmd["X"]`).
   **Δ** Where the signature says `RexxObject?` (`Send`, `Run`, `RunFile`,
   `New`, `Call`) it cannot be, so it is a proxy whose new property
   **`NetValue`** is the .NET object (null for any other Rexx object), and
   `RexxConvert.To` unwraps it. The alternative, returning `object?` or
   `dynamic` from those, would make every chained call untyped. The `.NetObject`
   classes reach the managed side from rexxnet (`Bridge.Classes`, on its
   first request) or from the host's own loading of net.cls, whichever comes
   first.
6. **A Rexx error that .NET code called from Rexx lets through is raised
   again as it was**: a `RexxException` from a call made in .NET (with its
   condition object) that ends the .NET call becomes the same condition in
   the calling Rexx code (code, substitutions, so the same message; for a
   condition other than SYNTAX, its name, description and additional
   object): answer K, the condition raised on the request's context with the
   thread context's `RaiseException` / `RaiseCondition` (never an unwinding
   API: phase B's rule). Shared with command handlers (`RaiseAgain`).
   **Through the whole chain of inner exceptions** (an `AggregateException`
   only when it holds one), as the callbacks' rule (`RexxCause`) does.
   Built first through reflection's wrappers only (an
   exception of the .NET code's own that wraps it being that code's error, a
   98.900); aligned with the callbacks instead, because a wrapper may be the
   framework's rather than the programmer's (`List.Sort` wraps its comparer's
   exceptions: phase 3's design, decision 2) and the bridge cannot tell them
   apart; the Rexx programmer gets their own error and line. The cost: the
   wrapper's message is lost.
7. **The 98.900 round trip**: a `RexxException` 98.900 whose `additional[2]`
   is a `.NetObject` holding an exception has that exception as its
   `InnerException` (verified: the very object thrown, from Rexx code run by
   the host and in guest mode).
8. **A `.NetHandler` remembers its instance**: rexxnet attached callbacks to
   the first instance that used .NET (a static); now each handler keeps the
   instance that made it (`c->instance`), for hosts with several instances.
9. **Found (ooRexx bug #2106, fixed in ooRexx r13267): on Linux, ooRexx's
   `CallRoutine` / `CallProgram` cost ~200 µs on
   a process's main thread** (5 µs on any other thread; `SendMessage`,
   `NewRoutine`, `LoadPackage` unaffected). Measured with this session's and
   the previous session's builds, on r13254 and r13263. Cause:
   `Activity::run` (every API call that runs a dispatcher) recomputes
   `stackLimit = currentThread.getStackBase() + ...`, and
   `SysActivity::getStackBase()` calls `pthread_getattr_np`, which for the
   **main** thread glibc implements by reading and parsing `/proc/self/maps`
   (strace: one `openat` of it and ~27 `read`s per call, plus `prlimit64`
   and `sched_getaffinity`); a .NET process has a long `maps`. Any ooRexx
   embedder on Linux pays it on its main thread (the `rexx` executable too,
   but its `maps` is short). A fix for ooRexx: compute the stack base once
   per thread (a thread's stack does not move), e.g. in
   `SysThread::useCurrentThread` / on attach, and reuse it in
   `Activity::run`. **Patch proposed**:
   `patches/oorexx/sysactivity-stack-per-thread.diff` keeps the stack's
   answer per thread (`thread_local` in `SysActivity.cpp`), which also
   covers `RexxStart` (3 reads a call: 7 ms → 0.2 ms with 3000 mappings);
   built and tested here with ooRexx's test suite. **Committed to ooRexx
   as r13267** (08/10/2026: the patch as proposed). See
   `patches/oorexx/README.md`. Why phase A's and B's numbers for `Run` / `Call` were
   lower is not known (perhaps measured off the main thread); the phase-C
   cost test runs on a thread of its own.

**Measured** (.NET 10, this container, off the main thread): a .NET object to
Rexx and back (`Call<object>(sb)`, a `.NetObject` made, its `NETID` read)
~10–15 µs (5 of them the `CallRoutine`); from Rexx, a call to a .NET method
passing a Rexx object and getting it back ~4–12 µs; no growth over 40 000
calls each way. `.net~type("Name")` costs ~18 µs (it searches the loaded
assemblies each time: worth a cache, in the other direction's code).

**Not done (later, if wanted):** Arrays to a `RexxObject` parameter as
themselves; Directory → `Dictionary`; the NativeAOT / custom-host
registration (see "One process, both ways"); a test with two instances whose
handlers call back (item 8 is a correctness fix without its own test).
