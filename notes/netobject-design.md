# `.NetObject`: .NET objects as Rexx objects — design proposal

*08/10/2026. Written as a proposal before anything was built; the sections
"Phase N: built" record what was built and what changed. Frame:
`decisions-20261008.md`. Model: `.JSObject` (ooRexx/WASM).
Every difference from `.JSObject` is marked **Δ** with its reason.*

## Goal

```rexx
say .net~System~Math~Max(3, 7)                   -- 7
list = .net~type("System.Collections.Generic.List<int>")~new
list~Add(3); list~Add(1); list~Sort
do x over list; say x; end                        -- 1, 3
form = .net~System~Windows~Forms~Form~new         -- Windows
form~Text = "Hola"
button~Click += .net~handler(self, "CLICKED")     -- a Rexx method as event handler
text = .net~System~IO~File~ReadAllTextAsync("a.txt")~await

::requires "net.cls"
```

## What stays as in `.JSObject`

- **One entry object, `.net`** (`.NetGlobal`), in `.environment`; objects
  **by reference**, never copied; a handle table on the host side
  (object → id and id → object), so identity works (`==`) and the Rexx
  `uninit` releases the handle.
- **Message syntax**: `o~name` gets a property or field, or calls a method
  with no arguments; `o~name(a, b)` calls a method; `o~name = v` sets a
  property or field, which must exist.
- **Case-insensitive names**, cached per type (ooRexx uppercases every
  message name). A tie that cannot be broken is an error naming the
  candidates.
- **Exceptions are SYNTAX 98.900** ".NET error: System.IO.FileNotFoundException:
  Could not find file 'a.txt'", the exception (as a `.NetObject`) in
  `additional[2]`; `TargetInvocationException` and `AggregateException`
  unwrapped. Helpers in `net.cls` RAISE PROPAGATE (errors point at the
  caller's line).
- **`~await`** waits for a `Task` (the Promise analogue): its result, or its
  exception as above. **`~makeArray`** (`DO x OVER o`) and **`~supplier`**
  (`DO WITH INDEX i ITEM v OVER o`) over `IEnumerable`.
- **Every method UNGUARDED.**
- **An honest `string`**: "a NetObject (System.Windows.Forms.Button #12)".
- **The split between the halves**: the native side (C++) knows only
  references (ids) and serialises JDOR's records `<tag><len>:<bytes>`; the
  managed side (C#) has the handle table, name resolution, overloads and
  conversions — they live where the objects live.

## Rexx surface

### `.net`, the entry

`.net` is not the proxy of a .NET object (.NET has no `globalThis`): it is
the root of the namespaces, plus the bridge's helpers.

| | |
|---|---|
| `.net~System`, `.net~System~IO` | a namespace (`.NetNamespace`); `~Name` goes down to a sub-namespace or a type |
| `.net~type(name [, typeArgs...])` | a type by full name, C# aliases (`int`, `string`…) and generics in C# syntax (`"System.Collections.Generic.Dictionary<string, int>"`), or an open generic plus its type arguments |
| `.net~load(nameOrPath)` | load an assembly (by name, or a `.dll` path) |
| `.net~new(type, args...)` | `new` (also `type~new(args...)`) |
| `.net~int16(x)`, `~int32`, `~int64`, `~byte`, `~sbyte`, `~uint16`…, `~single`, `~double`, `~decimal`, `~bool`, `~char`, `~string`, `~null` | force a type (`.NetTyped`) |
| `.net~as(x, type)` | force any type (an enum, a nullable, an interface) |
| `.net~box(type, x)`, `.net~unbox(o)` | a real .NET object holding x as type (a `.NetObject`; CLR.CLS's names too); its Rexx value back |
| `.net~ref([value])` | a `.NetRef`, for `ref` / `out` parameters |
| `.net~bytes(string)`, `.net~byteString(o)` | Rexx string ↔ `byte[]` |
| `.net~handler(obj, msg [, options])` | a Rexx method as a delegate or event handler (see Callbacks) |
| `.net~addHandler(o, "Click", h)`, `.net~removeHandler(...)` | `o~Click += h`, `o~Click -= h` as calls (also `o~add_Click(h)`, `o~remove_Click(h)`) |
| `.net~nextEvent([s])`, `~eventLoop`, `~stopEventLoop` | the queued model, as `.js` |
| `.net~invoke(o, "Name", args...)`, `.net~get(o, "Name")`, `.net~set(o, "Name", v)` | exact member, no guessing |
| `.net~typeOf(o)`, `.net~typeObject(o)`, `.net~isInstance(o, type)`, `.net~members(o)` | introspection |

**Δ Exact access and introspection live on `.net`, not on the object.** In
`.JSObject` they are `o["name"]`, `o~invoke(...)`, `o~className`… For .NET:
`[]` is the indexer (lists, dictionaries, arrays: the natural meaning), and
`Invoke` is one of the commonest .NET member names (every delegate,
`MethodInfo`, `Control.Invoke`); and the WASM lesson says introspection on
the object hides host members (`el~className`). `.net`'s own names are verbs
or type words, so they cannot hide a root namespace in practice; `.net~namespace("X")`
is the exact escape.

### A `.NetObject`

The methods it has of its own, all forced by Rexx protocols: `unknown`,
`[]`, `[]=`, `==` (and friends), `hashCode`, `string`, `makeArray`,
`supplier`, `await`, `uninit`; a type also `new`; an array (a `.NetArray`)
also `at`, `put`, `putStrict`, `items`, `size`, `dimension` (see "Arrays as
Rexx Arrays: built", below).

| Rexx | .NET |
|---|---|
| `o~Name` | property, field, or method with no arguments; an event gives a `.NetEvent` (for `+=`) |
| `o~Name(a, b)` | method (overloads below); an indexed property with arguments |
| `o~Name = v` | property or field set |
| `o[i]`, `o[i] = v`, `o[i, j]` | indexer (`Item`, **0-based** for lists, as .NET documents them); array element (**from 1**, a `.NetArray`: see "Arrays as Rexx Arrays") |
| `t~new(args)` | constructor (t a type) |
| `t~Name` | a static member of the type t |
| `o~Click += h`, `o~Click -= h` | add / remove an event handler (`.NetEvent` `+` / `-`; the `CLICK=` that follows is a no-op) — taken from `CLR.CLS` |
| `o~await` | `Task` / `ValueTask`: wait, result |
| `DO x OVER o` | `IEnumerable`: the items (a dictionary gives `KeyValuePair`s, as C#'s `foreach`) |
| `DO WITH INDEX k ITEM v OVER o` | `IDictionary`: keys and values; an array: its positions from 1; a list: from 0; other `IEnumerable`: 1..n and items |

**Types.** A type is a `.NetType` (subclass of `.NetObject`): `t~Name`
resolves the static members; `~new` constructs. The `System.Type` object
itself is `.net~typeObject(t)`. A `.NetNamespace` is not a .NET object (a
namespace is only a prefix); it goes down with `~Name`.

**Δ Rexx's `Object` methods do not hide .NET members.** In `.JSObject`
`send`, `start`, `copy`, `run`, `request` hide JavaScript's (documented,
`o~invoke("send", x)`). In .NET they are common: `Process.Start`,
`Thread.Start`, `Stopwatch.Start`, `Socket.Send`, `Application.Run`,
`Task.Run`, `File.Copy`, `Array.Copy` (and `System.String`: see Phase 1,
`STRING`). `.NetObject` overrides these names:
if the .NET object (or type) has a member of that name it wins; otherwise
the call goes to Rexx's. Predictable, and no `clr.dispatch` needed.

### Name resolution

Public members only (instance members on an object, static on a type),
caselessly, cached per type and kind. Overloads of one method share the
name, so a match is one name. If two names match (`Value` / `value`: rare
in public APIs), **the one starting in uppercase wins** (.NET's public
convention). **Δ** the opposite of `.JSObject`'s lowercase rule (DOM: `document` /
`Document`); each follows its host's convention. Otherwise an error naming
both.

Unknown name: an error. **Δ** `.JSObject` gives `.nil` (as `undefined`);
.NET has no such thing, and a typo should not pass silently. Since
09/10/2026 that error is Rexx's own 97.1, as for any Rexx object (see
"Unknown members: built").

COM objects (`__ComObject`: Office through interop)
are not visible to reflection: their members go through `IDispatch`
(`Type.InvokeMember` / `dynamic`), late-bound, caselessly. Same Rexx syntax.

## Values

**.NET → Rexx**

- `string` → string; `char` → one-character string;
- integers, `float`, `double` (round-trip), `decimal` → Rexx number strings,
  culture-invariant; `NaN` / `Infinity` as such;
- `bool` → `1` / `0`; `null` → `.nil`;
- **enums → a `.NetEnum`** (since 09/10/2026; before, their name): an
  object whose string value is its name (`"Yes"`, flags `"Bold, Italic"`);
  see "Enums as objects: built";
- a Rexx object that had gone to .NET → the same Rexx object;
- everything else (objects, structs, arrays, delegates, tasks) → `.NetObject`.

**Rexx → .NET** (decision 5): the member is chosen first, then each argument
is converted to its parameter's type.

- A Rexx string → the parameter's type: any numeric type it fits (no
  silent truncation), `bool` from `1`/`0`/`true`/`false`, `char` from one
  character, an enum from a name or number, `string` as is (`"007"` stays
  `"007"`); `DateTime`, `TimeSpan`, `Guid` by their invariant `Parse`.
  Parameter `object` (or an unresolved generic `T`): string.
- `.nil` → `null` (reference types, nullables).
- A `.NetObject` → the object; a `.NetTyped` → its forced type.
- A Rexx `Array` → when the parameter is an array, `List<T>` or
  `IEnumerable<T>`: a new one, items converted (a copy); a `StringTable` →
  `Dictionary<string, T>` likewise (built 09/10/2026: see below; a
  `Directory`: open).
- A `.NetHandler` → a delegate of the parameter's type.
- Any other Rexx object → a `RexxObject` (the .NET side's proxy for Rexx
  objects, `dynamic`: decision 7), so .NET can keep and use it. *(Built in
  phase C of `rexx-from-net-design.md`; there, the Directory /
  StringTable → `Dictionary` above is not built: they are `RexxObject`s.)*
- *(Later: **the equivalent of `Dictionary<string, T>` is a
  StringTable, not a Directory**: a Directory can have methods (`setMethod`,
  `UNKNOWN`), so it is an object rather than a map. (Its keys are
  case-sensitive with `[]` / `at` / `put`; only the `d~name` form uppercases,
  the key being the message name.)
  Proposed: a StringTable to a `Dictionary` / `IDictionary` /
  `IReadOnlyDictionary<string, T>` parameter → a copy, items converted; a
  Directory → always a `RexxObject`. **Open**: a
  Directory to a parameter that requires a dictionary — a conversion error,
  or a copy for convenience (people habitually use Directories)? **Δ** from
  `.JSObject`, which copies both to a plain object.)* **The StringTable part
  is built** (09/10/2026; `rexx-from-net-design.md`, "StringTable →
  `Dictionary`: built"); the Directory is still a `RexxObject`.

**Δ** `.JSObject` sends every Rexx string as a string and asks for
`.js~num()`; JavaScript has no parameter types to go by, .NET has them.

**Overloads.** Candidates by name and argument count (`params` and optional
parameters counted); a candidate fits if every argument converts. Ranking:
exact (`.NetObject` of the type, or a forced type) > widening / reference
conversion > conversion from a string; among strings, `string` parameters
first, then numbers by width (`int` before `long` before `double`), then
the rest. A tie is an error naming the candidates; forcing one argument's
type (`.net~int64(x)`) settles it. Constructors the same.

**Generic methods**: type arguments inferred from the arguments' types (as
C#, simplified); otherwise given explicitly through `.net~invoke`'s form with
a signature (to design in detail with the prototype).

**`ref` / `out`**: a `.NetRef` argument (`r = .net~ref`; `d~TryGetValue("k",
r)`; `say r~value`). **Δ to decision 6**, which said "the call also returns
the out values": a holder keeps the call's own result and reads as C#
(`out var r`). To confirm (Open points).

**Structs** are values: a `.NetObject` holds a boxed copy. `form~Location~X
= 5` changes the copy, not the form (C# does not even compile it); the way
is `form~Location = .net~System~Drawing~Point~new(5, y)`. Documented.

## Callbacks (decision 4)

`.net~handler(obj, msg [, options])` is a `.NetHandler`, a Rexx object; given
where .NET expects a delegate (an event, a parameter of type `Action<…>`,
`Func<…>`, `Comparison<T>`, `EventHandler<T>`, any delegate type), it becomes
a delegate **of that exact type**, built with `System.Linq.Expressions`
(one per handler and delegate type, cached, so `-=` works). **Δ** `CLR.CLS`
handled `System.EventHandler` only.

- **Default, synchronous**: called by .NET, the delegate runs in Rexx at
  once, on the calling thread: `obj~msg(args...)`, and the result is
  converted to the delegate's return type (sort comparators, `Func`s,
  `e.Cancel` set by the handler all work). A thread unknown to the
  interpreter is attached (`AttachThread`) for the call; a Rexx thread
  already inside a .NET call (re-entrancy: `list~Sort(handler)`) uses its
  own context.
- **Option `queued`**: as `.js~handler`: the call is queued, the delegate
  returns at once (`default` of its type); a Rexx thread takes it with
  `.net~nextEvent` / `.net~eventLoop`. Option `latest` as in `.js`.
- Lifetime: pinned from the first time it goes to .NET until
  `handler~release` or the end of the program (as `.js`).

**Verified (08/10/2026, `smoke/callbacks/`, ooRexx 5.3.0 r13254, .NET 8 and
10):** while a Rexx thread is inside a native call (a .NET call sleeping
1.5 s, as `Application.Run` would), another .NET thread attaches with
`AttachThread` and runs Rexx (3 callbacks done during the call), so the
kernel lock is not held across a native routine; `AttachThread` nests on a
Rexx thread already inside .NET (a `List.Sort` comparator calling Rexx on
the same thread works); a .NET thread runs Rexx while Rexx code is busy on
the main thread; a Rexx error in a callback comes back to .NET as an
exception and to Rexx as an error of the call. Nothing in the API had to be
released by hand. Stable over repeated runs.

**Δ** `.JSObject`'s callbacks are only queued: JavaScript cannot enter the
interpreter and its thread must never block. .NET can, and GUI handlers
must answer synchronously.

## Runtime and assemblies

- The CLR starts on first use of `.net` (hostfxr with our runtimeconfig;
  `RollForward=LatestMajor`, .NET 8 or later, decision 1). On Windows the
  runtimeconfig also names `Microsoft.WindowsDesktop.App`, so WinForms and
  WPF are there.
- Type lookup: the assemblies loaded, then the shared framework by name;
  `.net~load` for others. NuGet packages: later (a `.net~load` of a restored
  package's path works meanwhile).
- One process, both ways: when .NET is the host, `.net` uses the
  running CLR instead of starting one. *Verified
  (`smoke/hostapi/`, `rexx-from-net-design.md`): `hostfxr` attaches to the
  running runtime; and `rexxnet` now puts `Rexx.Net` in the default load
  context (the application's own copy if it has one), not in an isolated
  one, so there is one bridge and one handle table.*

## Packaging (decision 8)

`net.cls` (`::requires "rexxnet" LIBRARY`); the native library `rexxnet`
(not `net`: `libnet` exists on Linux, a packet library); the managed assembly
`Rexx.Net.dll` with its runtimeconfig. **Δ** `js.cls` / `js`: the names are
free there.

## Phases

1. **Core**: `.net` and namespaces, types, `~new`, members (get, set, call,
   static), names, values, overloads, exceptions, handles and `uninit`,
   identity, the `Object`-method overrides. Tests (Linux, here).
2. **Collections and the rest of the type system**: indexers, arrays,
   `DO OVER` / `DO WITH`, generics (types and methods), structs, enums,
   `ref` / `out`, `Task` / `~await`.
3. **Callbacks** (the kernel lock and nested attach: verified); `.net~handler`,
   delegates of any type, events `+=` / `-=`, synchronous and `queued`.
   *(Built: see "Phase 3: built".)*
4. **Windows**: WinForms sample, COM late binding, Office samples.

## Open points (as they were raised)

1. `ref` / `out` through a `.NetRef` holder instead of extra return values
   (changes decision 6's wording).
2. Enums come to Rexx as their names (strings), not as objects.
   *Superseded*: enum values are objects (see "Enums as objects: built").
3. The overrides of `start`, `send`, `copy`, `run`, `request` (and, since
   phase 1, `string`, with display through `makeString`): the .NET member
   wins when there is one.
4. Exact access and introspection on `.net` (`.net~invoke(o, ...)`) instead
   of on the object (`.JSObject`'s `o~invoke`, `o["name"]`): a divergence
   between sister bridges, with the reasons above. (The WASM side might
   adopt `.js~typeOf(o)` too: its own lesson says so.)
5. Arrays and indexers 0-based, as .NET (`.JSObject` does the same for JS).
   *Superseded for arrays*: a .NET array is now a Rexx Array from 1 in every
   dimension (see "Arrays as Rexx Arrays: built"); indexers stay 0-based.
6. Names: `net.cls`, library `rexxnet`, assembly `Rexx.Net`.

## Phase 1: built (08/10/2026)

In `bridge/` (`build.sh` → a build directory; `tests/run.sh`):
`managed/` (`Rexx.Net.dll`: `Wire.cs`, `Handles.cs`, `Types.cs`,
`Convert.cs`, `Members.cs`, `Bridge.cs`), `native/rexxnet.cpp`
(`librexxnet.so`), `rexx/net.cls`; `tests/phase1.rex` with a test assembly
`tests/TestLib` (ambiguity, optional and `params` parameters, hidden
members, a case-only name clash, structs, `Start`/`Send`/`Copy` members).
**93 tests pass** (Linux, ooRexx 5.3.0 r13254, .NET 8 runtime), three runs
in a row.

Built as designed: `.net` and namespaces (caseless, framework assemblies
loaded on demand: `.net~System~Text~RegularExpressions~Regex` works without
a `load`), `.net~type` (aliases, generics, arrays, open generic + type
arguments), `.net~load`, `~new`, static and instance members, properties and
fields get/set, names (uppercase wins a tie, exact access on `.net`), values
both ways, overloads by cost with ties as errors naming the candidates,
`params`, optional parameters, forced types (`.net~int16` … `.net~as`,
`.net~null`), Rexx Array → array / `List<T>` / `IEnumerable<T>`, exceptions
(SYNTAX 98.900, the exception in `additional[2]`; bridge errors without an
object), handles with identity and release by UNINIT, the `Object`-method
overrides, introspection on `.net` (`typeOf`, `typeObject`, `isInstance`,
`members`, `handleCount`).

Found while building it:

- **`STRING` joins the overrides, and display goes through `makeString`.**
  `.net~System~String` sent STRING to the namespace, which is Rexx's
  display method: the type `System.String` was unreachable. ooRexx's `say`
  and concatenation use `makeString` when a class defines it (checked), so
  `.NetObject`, `.NetType` and `.NetNamespace` display through
  `makeString`, and `string` goes to .NET when there is a member `String`
  (the namespace `System`'s type), else returns the display.
- **Handles count their Rexx proxies.** The same object sent to Rexx twice
  is the same id but two Rexx objects; each one's UNINIT releases one
  reference, the entry goes when the last one does.
- SYNTAX 98.900 adds a final period to its message: the bridge drops the
  one .NET messages end with.
- A Rexx string converts to `char[]` too (cost 30; `String`'s constructors).
- Generic *methods* are left out until phase 2 (only non-generic overloads
  are candidates); `ref` / `out` parameters do not fit yet.
- `rexxnet` loads `Rexx.Net` into the default load context
  (`hdt_get_function_pointer`, else `hdt_load_assembly`; .NET 8), no longer
  an isolated one: see `rexx-from-net-design.md`, "One process, both ways".
- *(For phase 2)* Members are looked up on the runtime type, so an
  object of a non-public type (a compiler-generated iterator, e.g.
  `AssemblyLoadContext.All`) shows none (`GetEnumerator`). C# goes by the
  static type: look through public base types and interfaces when the
  runtime type is not public. *(Done in phase 2.)*
- `rexxnet.cpp` has the Windows branches (`LoadLibraryW`, wide paths) but
  they are untested.

Measured (100 000 calls each): a property get ~2.7 µs; `Math.Max(i, 7)`,
13 overloads, ~35 µs (the overload is chosen on every call: caching the
choice per argument shape is an easy later win — *phase 2 found the real
cause instead, see there*); namespace walk + `new`
~25 µs. 300 000 objects made in the tests and the benchmark, live handles
stay in the hundreds.

## Phase 2: built (08/10/2026)

`tests/phase2.rex` (76 tests, with `tests/TestLib/Phase2.cs`) after
`phase1.rex` (93), both from `tests/run.sh`. All pass on .NET 10 (what
`LatestMajor` picks here) and on .NET 8 (`DOTNET_ROLL_FORWARD=Minor`), three
runs in a row. New: `managed/Collections.cs`; changes in `Members.cs`,
`Bridge.cs`, `Convert.cs`, `Wire.cs`, `native/rexxnet.cpp`, `rexx/net.cls`.

Built as designed, with these details settled:

- **Indexers and arrays**: `o[i]`, `o[i, j]`, `o[i] = v` (net.cls `[]` /
  `[]=`; Rexx sends `[]=`'s value first). Arrays by position (any rank,
  0-based); otherwise the type's default member (`Item`, or what
  `[IndexerName]` calls it: `StringBuilder`'s `Chars`), overloads chosen as
  for methods; the setter gets (indices..., value).
- **`DO OVER` / `DO WITH`** (`makeArray`, `supplier`): a snapshot. Indexes
  are what `o[index]` takes back: an `IDictionary`'s keys (also a generic
  `IDictionary` / `IReadOnlyDictionary` that is not an `IDictionary`), the
  0-based positions of an array or list (rank > 1: an Array of positions),
  1..n for any other enumerable. **Refines the design**, which said "1..n"
  for every `IEnumerable`: for lists that would not match `o[i]`. `DO OVER`
  a dictionary gives its `KeyValuePair`s, as C#'s `foreach`. An enum type is
  enumerable too: names (`DO OVER`), names and values (`DO WITH`).
- **Objects of non-public types** (an iterator from `yield`, an internal
  implementation): their members are those of the nearest public base class
  and the public interfaces, explicit implementations included (C#'s
  `dynamic` only looks at the base class). The public members of the
  non-public type itself are not reachable, as in C#. Two interfaces giving
  the same parameters (`IList<T>` and `IList` indexers) are one member: the
  one with the more specific result is taken instead of reporting a tie.
- **Generic methods**: candidates next to the non-generic ones. Type
  arguments inferred from the arguments (unifying with the parameter types
  through base types and interfaces, so `First<T>(IEnumerable<T>)` takes a
  `List<int>`): a .NET object gives its runtime type, a forced value its
  type, **a Rexx string `System.String`** (`.net~int32(5)` for an int: Rexx
  strings have no type to infer from), a Rexx Array its items' common type.
  Constraints that fail drop the candidate. On a tie the non-generic method
  wins, as in C#. Given explicitly in the name, C# syntax:
  `.net~invoke(o, "Make<int>")`, or `o~"Make<int>"` (aliases are caseless,
  so the uppercased name works). A method whose type arguments cannot be
  inferred says so and shows the explicit form.
- **`ref` / `out` / `in`** through **`.NetRef`** (open point 1, built as
  proposed): `r = .net~ref([value])`, `d~TryGetValue("k", r)`, `r~value`.
  `out` ignores the value; `ref` converts it (`.nil` to a value type: its
  default); `in` also takes a plain value, as C#. A ref parameter does not
  take a plain value, and a `.NetRef` fits no other parameter. Wire: a
  request record `R` (the value); a call with `R` arguments answers `R` (the
  result, then each ref's new value), and `rexxnet` sets the `.NetRef`s it
  collected while encoding. Signatures in errors show `ref` / `out` / `in`.
- **`~await`**: `Task`, `Task<T>`, `ValueTask`, `ValueTask<T>`; the result,
  or nothing; a failed task's own exception (unwrapped) as SYNTAX 98.900.
  It blocks the calling thread as C#'s `.Result` does, so it must not be
  used on a thread whose `SynchronizationContext` the task needs (a WinForms
  handler awaiting UI work): phase 3 / Windows to document with a sample.
- **Enums**: as designed (names; flags `"Bold, Italic"`; numbers accepted).
  **Structs**: as designed (a boxed copy; setting a field or calling a
  mutating method changes that box, which a C# copy would not; passing it
  passes a copy).

**Performance: the cost was not the overload choice.** `Math.Max(i, 7)` cost
35–47 µs because every overload that did not fit threw: a Rexx number tried
as `byte` / `sbyte` / `short` went through `Convert.ChangeType`, which throws
`OverflowException` (~10 µs each, 13 overloads × 2 arguments). Now range
checks without exceptions, `ParameterInfo` facts read once per method
(`Members.SigOf`), and the record lengths parsed without strings: the
managed side of `Math.Max` takes ~5 µs, a call from Rexx ~7–13 µs (this
container's timings are noisy: two vCPUs, and the .NET build servers stay
busy for a while after a build — measure when they are idle). A cache of the
chosen overload would save ~2–3 µs more, and is harder to get exactly right
(the choice depends on a Rexx string's value, not only on its kind): not
done.

Fixed on the way: `rexxnet` now makes its own path absolute
(`realpath`). With the documented `LD_LIBRARY_PATH=.`, `dladdr` gave
`./librexxnet.so` and the new `hdt_load_assembly` (both ways in
one process) refused the relative path. `tests/run.sh` used an absolute
path, so it did not see it; it now runs with `LD_LIBRARY_PATH=.`.

Left for phase 3 and later: callbacks and events (`.net~handler`), COM late
binding (Windows), extension methods as instance calls (`list~Where(...)`:
for now through the static class, `.net~System~Linq~Enumerable~ToList(l)`).
*(Callbacks and events: phase 3, below.)*

## Phase 3: built (08/10/2026)

`tests/phase3.rex` (68 tests, with `tests/TestLib/Phase3.cs`) after phase 1
(93) and phase 2 (76), all from `tests/run.sh`. All pass on .NET 10 and on
.NET 8 (`DOTNET_ROLL_FORWARD=Minor`), three runs in a row each; `smoke/run.sh`
and `smoke/hostapi/run.sh` still pass. New: `managed/Callbacks.cs`; changes
in `Bridge.cs`, `Convert.cs`, `Wire.cs`, `native/rexxnet.cpp`, `rexx/net.cls`;
`TestLib` now references `Rexx.Net` (not copied) to catch `RexxException`.

Built as designed (Callbacks, decision 4):

- **`.net~handler(obj, msg [, options])`** is a `.NetHandler`. Given where
  .NET wants a delegate, it is a delegate **of that exact type**, compiled
  with `System.Linq.Expressions` and cached per (handler, delegate type), so
  `-=` finds the one `+=` added. Verified: `Func<int, int, int>`,
  `Func<string>`, `Predicate<string>`, `Comparison<T>` (`List.Sort`),
  `Enumerable.Where`, `EventHandler`, `EventHandler<T>`,
  `EventHandler<CancelEventArgs>` (`e~Cancel = 1`), `Task.Run(Action)`,
  `Task.Run(Func<int>)`, `task~ContinueWith(handler)`, a parameter of type
  `Delegate` (`DynamicInvoke`).
- **Synchronous by default**: the delegate calls `rexxnet` on the calling
  thread, which attaches it (`AttachThread`; nested on a Rexx thread already
  inside .NET), sends the message with the delegate's arguments (.NET → Rexx
  values as usual; the sender is the same `.NetObject`, identity holds) and
  converts the result to the delegate's return type. Verified: re-entrant
  on the same thread (a comparator), **a guarded method whose handler is a
  guarded method of the same object, nested on its thread (no deadlock)**,
  an event raised on another thread while the Rexx thread waits in .NET (as
  `Application.Run`), events from a background thread while Rexx code runs,
  four threads calling one handler at once.
- **Events**: `o~Click` is a `.NetEvent` (owner and name; a record `e`);
  `o~Click += h` is `o~Click = (o~Click + h)`: `.NetEvent`'s `+` / `-` add or
  remove (anything that converts to the event's delegate type: a handler,
  or a `.NET` delegate), and the `CLICK=` that follows is a no-op when it
  gets back the same object's same event. Any other `o~Click = x` is an
  error, as a call with arguments. Static events: `type~Shared += h`.
- **Queued**: options `queued` and `latest` (implies `queued`) as `.js`;
  `.net~nextEvent([seconds])`, `.net~eventLoop`, `.net~stopEventLoop`;
  `.net~queuedCalls` (diagnostics). The queue lives on the managed side; a
  Rexx thread waiting in `nextEvent` holds no interpreter lock.
- **Lifetime**: a handler is kept (global references in `rexxnet`) from the
  first time it goes to .NET until `handler~release`.

Settled while building it:

1. **Overloads with delegate parameters.** C# chooses by the lambda's
   parameters and body; a Rexx method declares neither. Rule: **fewer
   delegate parameters first** (`Where(Func<T, bool>)` before
   `Where(Func<T, int, bool>)`, the indexed form), **then returning void
   before returning a value** (`Task.Run(Action)` before
   `Task.Run(Func<Task>)`). Another one: `.net~as(h, "System.Func<int>")`.
   A parameter of type `Delegate` (`Control.Invoke(Delegate)`) gets an
   `Action`, after any concrete delegate type. Generic methods whose type
   arguments only a lambda would give (`Task.Run<T>(Func<T>)`) are not
   inferred from a handler: give them, or force the delegate type.
2. **Errors in a handler.** A Rexx condition in a synchronous handler is a
   **`RexxException`** in .NET (`ConditionName`, `Code` "98.900", `Rc`,
   `ErrorText`, `Program`, `Line`, the message; the class the .NET → ooRexx
   design names, here with the members phase 3 needs). If the condition was
   a .NET exception that went to Rexx as 98.900, that exception is its
   `InnerException` (the round trip). **If the `RexxException` comes back
   out of .NET to Rexx** (directly or wrapped, as `List.Sort` wraps its
   comparer's exceptions), **the original Rexx condition is raised again**
   (same code and additional information; a 41.1 stays a 41.1), not a
   98.900 about it. `rexxnet` keeps the last 32 such conditions for this
   (.NET may swallow the exception; then nobody asks for it).
3. **A handler that returns nothing** where the delegate returns a value:
   `InvalidOperationException` ("the Rexx handler returned nothing; its
   delegate needs a System.Int32"), except `object` (null) and `Task` (a
   completed task). A result that does not convert: `InvalidCastException`.
   Strict, as an unknown member name is an error and not `.nil`.
4. **The queued call is a `.NetCall`** (`.js` calls it `.JSEvent`): here
   `.NetEvent` is already the event member (`o~Click`, from `CLR.CLS` and
   this design). Same methods as `.JSEvent`: `handler`, `arguments`,
   `target`, `message`, `dispatch`.
5. **A released handler**: its delegates stay valid and do nothing (return
   their type's default; queued calls are dropped, and those already queued
   go), and it can still be given to `-=`, which finds its delegate.
6. **Delegates with `ref` / `out`, pointer or span parameters** are not
   supported (an error naming them). Rare in events and callbacks.

**`~await` and a `SynchronizationContext`.** `~await` blocks the calling
thread until the task ends, as C#'s `.Result`. On a GUI thread (a WinForms
or WPF handler) that is a deadlock whenever the task needs that thread to
finish: a C# `async` method that continues on the UI thread, a
`Control.Invoke` inside the task. Rules for the documentation (and a
Windows sample): in a GUI handler, do not `~await` a task that needs
the UI thread; let the handler return and continue in another handler,
`task~ContinueWith(.net~handler(self, "DONE"))` (verified here), or with
the UI's scheduler
(`.net~System~Threading~Tasks~TaskScheduler~FromCurrentSynchronizationContext`)
when the continuation touches controls; tasks that do not need the UI
thread (`File.ReadAllTextAsync`, `HttpClient`) are fine to `~await` from a
non-UI Rexx thread. The `queued` model avoids the question: the handler
returns at once and a Rexx thread does the work.

**Measured** (.NET 10; this container is noisy): a Rexx call to .NET that
calls a Rexx handler back (`Func<int, int, int>`) ~25 µs the round trip, of
which the callback ~13–15 µs (the nested attach, the argument proxies, the
message); an event with sender and `EventArgs` ~24 µs from `PerformClick`;
`List.Sort` of 2 000 integers with a Rexx comparator 0.15 s (~22 000
comparisons, ~6.6 µs each). Live handles stay flat over 40 000 callbacks.

**Errors in a handler no Rexx code waits on (decided: report and go
on).** A Rexx condition in a synchronous handler called on a thread where no
Rexx → .NET call is running (a timer, the thread pool, a thread the .NET
code started; the managed side counts the Rexx requests running per thread)
does not go up that thread, where an unhandled exception would end the
process. `rexxnet` reports it on `.error` as Rexx reports an untrapped error
(the traceback, `Error 98 running prog.rex line 25: ...`, `Error 98.900:
...`), adds a line saying that the call returned its delegate's default and
the program goes on, and the delegate returns that default. Where Rexx code
waits on that same thread (a comparator inside `list~Sort`, a GUI handler
inside `Application.Run`) the condition is a `RexxException` as above. Note:
`Task.Run(handler)~await` runs the handler on a pool thread, so its error is
reported there and the task completes normally. Verified (`phase3.rex`): a handler failing on a background thread's
second event, with `.error` replaced by a collector: the report has the
message and the traceback, and the third event arrives. Later, in host
mode (.NET → ooRexx), a .NET thread with no Rexx request may still have
.NET code that wants the exception: to revisit with phase A.
`RexxException` also gives the `Traceback` now.

**Also:**

- Handler methods called from other threads wait for the object's guard
  while one of its guarded methods runs (as any Rexx thread would):
  documented in `net.cls` ("make such handler methods UNGUARDED"). Nested
  on the same thread there is no wait (verified).

## Arrays as Rexx Arrays: built (09/10/2026)

**Decided:** a .NET array reaches Rexx as a **`.NetArray`** (a subclass of
`.NetObject`), which behaves as a Rexx Array: **from 1 in every dimension**,
with the protocol of BSF4ooRexx's `BSF_ARRAY_REFERENCE` for Java arrays
(`BSF.CLS`): `at`, `[]`, `put`, `[]=`, `putStrict`, `items`, `size`,
`dimension`, `makeArray`, `supplier`. **Lists and the other collections stay
as .NET documents them** (`list[0]`, `dict["key"]`): a Rexx List does not
expose positions either, and BSF4ooRexx leaves `java.util.List` 0-based.

**Δ `.JSObject`** keeps JavaScript arrays 0-based. Reasons for the
difference: a Rexx programmer should not have to think in offsets (Rexx
arrays start at 1); BSF4ooRexx, the other bridge to a typed platform, does
it for Java arrays and has for years, and the two bridges should feel alike;
and a .NET array is a fixed-size, typed block, close to a Rexx Array, where
a JavaScript array is an ordinary object whose indexes are property names.

`tests/phase2.rex` (106 tests, was 76) and `tests/HostTests` (184, was 183);
phases 1 and 3, bothways, `smoke/run.sh` and `smoke/hostapi/run.sh` pass
unchanged (.NET 10, ooRexx r13267). Changes: `Collections.cs`, `Bridge.cs`,
`Convert.cs`, `Handles.cs`, `Host/RexxInterpreter.BothWays.cs`,
`native/rexxnet.cpp`, `rexx/net.cls`.

| Rexx | |
|---|---|
| `a[i]`, `a[i, j]`, `a~at(i, j)`, `a~at(.array~of(i, j))` | an element, from 1 |
| `a[i] = v`, `a~put(v, i, j)`, `a~put(v, .array~of(i, j))` | set one |
| `a~putStrict(type, v, i...)` | set one as that .NET type (a name, `"short"`, or a `.NetType`): `.net~as(v, type)` |
| `a~items`, `a~size` | the number of elements (all of them: a .NET array has a fixed size; `BSF_ARRAY_REFERENCE` answers the same) |
| `a~dimension`, `a~dimension(n)` | the rank; the length of dimension n (0 past the rank, as a Rexx Array) |
| `DO x OVER a`, `a~makeArray` | every element, row by row (the last index fastest) |
| `DO WITH INDEX i ITEM v OVER a`, `a~supplier` | positions from 1; rank > 1: an Array of positions, as a Rexx Array's supplier gives |
| `a~Length`, `a~Rank`, `a~GetValue(0)` | .NET's own members, as before (they are 0-based: .NET's) |

Settled while building:

- **Rexx's own errors.** Wrong indexes raise what a Rexx Array raises, not
  98.900: 93.907 (rank 1: "Method argument *n* must be a positive whole
  number", *n* counted as Rexx counts it: 2 for `put`'s first index), 93.924
  (rank > 1: "Invalid position argument specified"), 93.925 / 93.926 ("Not
  enough / Too many subscripts for array; *r* expected"), 93.901 (no index,
  or `put` without a value). A new response record carries them from the
  managed side (`Y`: code and substitutions; `RexxSyntaxException`).
- **One past the bounds** is .NET's `IndexOutOfRangeException` (98.900),
  as `BSF_ARRAY_REFERENCE` gives Java's. A Rexx Array returns `.nil` from
  `at` past its end and grows on `put`; a .NET array cannot grow, and a
  `.nil` there would hide a mistake.
- **Differences from a Rexx Array that stay:** `items` counts every element
  (a Rexx Array counts the non-empty ones), and `makeArray` / `supplier`
  give `null` elements as `.nil` (a Rexx Array skips empty ones): as
  `BSF_ARRAY_REFERENCE`. A `.NetArray` is not an instance of `.Array`.
- **A jagged array** (`int[][]`) is an array of arrays: `jag[2]` is a
  `.NetArray`, `jag[2][3]` its element.
- **By reference, as any `.NetObject`**: nothing is copied; a `.NetArray`
  goes back to .NET as the same array, and .NET sees what Rexx put.
- **Both directions.** A .NET array handed to Rexx by a .NET host
  (`rexx.Run("use arg a; a[1] = 9", arr)`) is a `.NetArray` too. Rexx code
  run by a host sees `.net` but not net.cls's classes by name (they are not
  in `.environment`): `a~class~id` is `NETARRAY`.
- `o[i]` on a `.NetObject` that holds an array (it cannot be made one now,
  but the managed side does not rely on that) also counts from 1.

## box / unbox, addHandler / removeHandler: built (09/10/2026)

`tests/phase1.rex` 108 (was 93: box / unbox), `tests/phase3.rex` 77 (was 68:
the event forms); everything else unchanged and passing on .NET 10 and .NET
8. Changes: `Bridge.cs`, `rexx/net.cls`, `TestLib/Phase3.cs`.

**`.net~box(type, x)`** makes a real .NET object holding x converted to
type, and gives it as a `.NetObject`, by reference. Where `.net~int16(x)`
only marks an argument (the conversion happens at the call), a box *is* the
.NET value: it goes to .NET as itself (`object` parameters see an `Int16`,
an overload tie is settled), it can be kept, put in a collection, compared.
A .NET method that returns it gives a Rexx string again, as any boxed
primitive. The type is a `.NetType`, any name `.net~type` takes (`"short"`,
`"System.UInt32"`, an enum, a struct whose conversion exists), or one of
CLR.CLS's (`clr.box`): the indicators `BO BY CHAR DE DO INT16 UINT16 INT32
UINT32 INT64 UINT64 SB SI ST` and the long names `Boolean Byte Character
Decimal Double Int16 UInt16 Int32 UInt32 Int64 UInt64 SByte Single String`,
caseless, shortened down to their capitals (`STring`, `BOolean`, `CHAR`).
CLR.CLS's names are tried first; none of them is also a C# alias for
another type. `.net~box(type, .nil)` is `.nil` for a reference type (as
`clr.box`); a value that does not fit is an error ("`300` cannot be a
`System.Byte`").

**`.net~unbox(o)`**: a boxed primitive, `decimal`, string or enum held by a
`.NetObject` gives its Rexx value (an enum: its name); anything else, a `.NetObject` of another kind or a Rexx object, comes
back unchanged (as `clr.unbox`).

**Events.** Besides `o~Click += h` / `-= h`: `.net~addHandler(o, "Click",
h)` and `.net~removeHandler(o, "Click", h)` (the name caseless), and .NET's
own accessor names, `o~add_Click(h)` and `o~remove_Click(h)` (also on a
type for a static event, `t~add_Shared(h)`, and exact through
`.net~invoke(o, "add_Click", h)`). An accessor name is taken as such only
when the type has an event of that name and no ordinary member with the
accessor's own name (a method called `add_Thing` wins, tested); `h` is
anything `+=` takes (a `.NetHandler`, or a delegate).

## Unknown members: built (09/10/2026)

**Decided:** an unknown message behaves as it does on any Rexx object: the
object's `UNKNOWN` gets it first; only if nothing handles it, **SYNTAX 97.1**
("Object ... does not understand message ..."), with the .NET exception that
describes the failure in the condition's additional information. Before, it
was 98.900 (".NET error: ... has no public member ..."). BSF4ooRexx raises
its own error naming either a missing method or an execution error; here,
with no compatible bridge to keep, the message is the one every Rexx
programmer knows.

`tests/phase1.rex` 124 (was 108); everything else unchanged and passing on
.NET 10 and .NET 8; `smoke/` too. Changes: `Bridge.cs`, `Handles.cs`,
`native/rexxnet.cpp`, `rexx/net.cls`.

- **The 97.1.** `condition("O")~additional` is what ooRexx gives a 97.1 —
  [1] the receiver (the very proxy, or the object given to `.net~invoke`,
  `.net~get`, `.net~set`, `.net~addHandler`), [2] the message name as Rexx
  sent it (`NOSUCHTHING`, `NOSUCHTHING=` for a set, the exact name through
  `.net~invoke`) — plus **[3] a `System.MissingMemberException`** (a
  `.NetObject`) whose message says what was looked for (".. has no public
  instance member ..."; the hint about `.net~typeObject` on a type). There
  is no .NET exception when the bridge's own lookup fails, so it makes one.
  *Position [3]: the first two are ooRexx's; asked whether [3] is what was
  meant.* Only a missing member is 97.1; the other errors of a lookup (an
  ambiguous name, a property that cannot be read, a field given arguments)
  stay 98.900, and so do exceptions thrown by .NET code.
- **`UNKNOWN` first.** On a `.NetObject`, .NET's members are found by its
  `UNKNOWN` method (they are not Rexx methods). So "UNKNOWN first" is Rexx's
  own rule, once Rexx code can make objects of a subclass:
  **`.MyClass~new(o)`**, with `MyClass` a subclass of `.NetObject` (or
  `.NetArray`) and `o` a `.NetObject`, is an object of that class standing
  for o's .NET object (one more proxy for the same handle: `== o`, the same
  `netId`, released by its `uninit`). Its methods win over .NET members of
  the same name; its `UNKNOWN` gets every other message and reaches .NET
  with `FORWARD CLASS (SUPER)`; if .NET has no such member either, 97.1.
  Tested: a subclass answering `SHOUT` itself, `Length` through .NET, its
  `capacity` method hiding .NET's `Capacity`, `NOPE` a 97.1, its instance
  going to .NET as the `StringBuilder`, 2 000 instances released.
- **Not done:** NOMETHOD. ooRexx raises the NOMETHOD condition instead of
  97.1 when it is trapped and the object has no `UNKNOWN`; a `.NetObject`
  always has one (the bridge's), so as for any Rexx class with an `UNKNOWN`,
  SYNTAX 97.1 is what comes. A .NET object returned by .NET later is a plain
  `.NetObject` again (the subclass is a view chosen by Rexx code, not a
  property of the .NET object). A Rexx class that *extends* a .NET class (so
  that .NET calls its overrides) is a different, larger feature, not
  started.

## Enums as objects: built (09/10/2026)

**Decided:** an enum value is an object, as Java enums are in BSF4ooRexx: a
**`.NetEnum`** (a subclass of `.NetObject`). On an enum type, `makeArray`
(`DO OVER`) gives its values and `supplier` (`DO WITH`) numbers as indexes
and names as items (BSF4ooRexx's `1-071_demoDoOver_Enum.rxj`: ordinals and
names). **Built ahead of the answers to three open questions** (the string
value, `=` against a string, flags), with the choices below; they are easy
to change.

`tests/phase2.rex` 127 (was 106), `tests/HostTests` 186 (was 184);
everything else unchanged and passing on .NET 10 and .NET 8; `smoke/` too.
Changes: `Bridge.cs`, `Collections.cs`, `Convert.cs`, `Host/RexxInterpreter.cs`,
`Host/RexxInterpreter.BothWays.cs`, `native/rexxnet.cpp`, `rexx/net.cls`.

| Rexx | |
|---|---|
| `say d`, `"is" d`, `d~string`, `d~makeString` | its name: `Monday`; flags `Bold, Italic`; a value with no name, its number |
| `d~name`, `d~ordinal` (`d~value`) | its name; its number (the underlying value: `1` for `Monday`) |
| `d = "monday"`, `d = "italic, bold"`, `d = 1`, `d = other` | the same value: a name as .NET reads one (caseless; flags in any order), its number, or another `.NetEnum` of the same type and value; `\=`, `<>`, `><` |
| `d == "Monday"`, `d == other` | strictly: exactly its name, or another `.NetEnum` of the same type and value; `\==` |
| `d~HasFlag(f)`, `d~CompareTo(x)`... | .NET's own members, as before |
| `p~Day(d)`, `p~Day("monday")` | to .NET as the enum value; a name or number still converts |
| `DO x OVER t`, `t~makeArray` (t an enum type) | its values (`.NetEnum`s), in number order (.NET's `GetValues`) |
| `DO WITH INDEX n ITEM name OVER t`, `t~supplier` | numbers and names |
| `.net~unbox(d)` | its name |

Settled:

- **The string value is the name.** Code written for names keeps working:
  `say`, concatenation, `SELECT ... WHEN d = "Thursday"`, `pos(...)`; only
  code that relied on it *being* a string object (`d~length`, `d~upper`:
  messages to the object) sees a `.NetEnum`: `d~name~upper`.
- **`=` compares values**, as `CLR.CLS`'s `CLR_Enum` compares names
  caselessly, but through .NET's own parser (`Enum.TryParse`, caseless): so
  flags match in any order and spacing, and a number matches the value with
  that number (Rexx's `=` is numeric for numbers too). `==` is strict:
  exactly the name, as `==` on strings. Values of two enum types are never
  equal. `hashCode` is the name's (consistent with `==`), so a `.NetEnum` is
  a good index for a Directory or a Set.
- **The "ordinal" is the number.** Java's `ordinal()` is the position in
  the declaration; .NET enums have no such thing, only the underlying value
  (and `GetValues` orders by it); flags and explicit numbers (`None = 0,
  Bold = 1, Italic = 2, Under = 4`) make the value the only meaningful
  index. `ordinal` and `value` both give it.
- **A .NET object, by reference, as before**: a `.NetEnum` goes back to
  .NET as the boxed enum value. Values from a .NET host to Rexx are
  `.NetEnum`s too (`rexx.Run("use arg d; ...", DayOfWeek.Monday)`), and come
  back as the enum value.
- **Cost**: every enum value that reaches Rexx is a proxy (a handle), not a
  string; its name and number are asked once, when first needed.
- **Open** (asked): whether the string value should be the name (as here),
  whether `=` against a string should be allowed (as here), and how flags
  should look (as here: .NET's `"Bold, Italic"`; `d = "bold, italic"`;
  `d~HasFlag(f)`).

