# CLR.CLS compatibility package

*Built 09/10/2026. The package: `bridge/rexx/CLR.CLS` (copied next to
`net.cls` by `bridge/build.sh`). Tests: `bridge/tests/clr.rex` (36, in
`tests/run.sh`) and `bridge/tests/clr-samples.sh` (CLR.CLS's own portable
samples, fetched from BSF4ooRexx's SVN; 10 checks).*

## What it is

BSF4ooRexx's `CLR.CLS` (ooRexx.NET, 2016, by Rony G. Flatscher with Manuel
Raffel and Adrian Baginski) reached .NET Framework through Java and jni4net.
`notes/bsf4oorexx-clr.md` (decision 3) proposed our own bridge with a
`CLR.CLS` compatibility package on top, so that programs written for it run
unchanged. This is that package: a program that says `::REQUIRES CLR.CLS`
finds ours (in the bridge's build directory, or wherever `net.cls` is) and
runs on .NET 8+ through `net.cls`, without Java.

It is a thin layer: about 250 lines of Rexx. Everything it does not mention
is `net.cls`'s (events, properties, enums, arrays, conversions).

## The interface

| CLR.CLS | Here |
|---|---|
| `.clr~new(typeName, args...)` | a `CLR` (a subclass of `.NetObject`) for a new object of that type; a wrapper type (`"System.Int16"`, ..., `"System.String"`) with one value: that value boxed, as `clr.box` |
| `clr.import(typeName [, name4local])` | a `CLR_Class` (a subclass of `.NetType`): static members, `~new(args...)`; put in `.local` only when named |
| `.clr~clr.import(typeName [, name4local])` | the same, put in `.local` by default under the type name (`.System.Console`), as CLR.CLS |
| `o~clr.dispatch(name, args...)` | the .NET member of that name, whatever Rexx method shares it (`Start`, `Init`...) |
| `o~clr.object`, `o~clr.type` | the proxy itself (there is no Java peer); its `System.Type` |
| `clr.createEventHandler(rexxObj [, userData])` | a `.net~handler` calling `rexxObj~invoke(sender, eventArgs, slotDir)`, `slotDir~userData` the user data (as BSF4ooRexx appends a slotDir); it fits any delegate type, not only `EventHandler` |
| `o~Click += h`, `o~Click -= h` | `net.cls`'s events |
| `clr.createArray(typeName, n)` | a .NET array, a `.NetArray` (from 1, as `BSF_ARRAY_REFERENCE`) |
| `clr.box(indicator, value)`, `clr.unbox(o)` | `.net~box` (CLR.CLS's indicators and long names) as a CLR proxy; `.net~unbox` |
| `clr.wrap(value)` | a CLR proxy: a .NET object as itself, a Rexx number boxed as Int32, Int64 or Decimal, any other string as a `System.String` |
| `clr.addAssembly(name)` | `.net~load(name)` |
| `CLRThread` (subclass, `run`, `~start([data])`) | `run` on a new Rexx thread (`Object~start`), with a slotDir whose `userData` is the data; a Rexx thread reaches .NET as any other |
| `CLRLogger` | the same levels and messages; the package itself logs nothing |
| `CLR_Enum` (`=` caseless with a string) | `net.cls`'s `.NetEnum` (`=` through `Enum.TryParse`, caseless) |
| `pp(x)` (from `BSF.CLS`) | `"[" x "]"`, as the samples use it |

## What the package adds to `net.cls`

For the objects it makes (`.clr~new`, `clr.import`) and every .NET object
they return (wrapped as `CLR_Proxy`):

- **A whole number argument goes as an `Int32`** (an `Int64` past its range),
  as `clr.wrap` made it. Programs written for CLR.CLS rely on it:
  `Convert~ToChar(stream~Read)` (Baginski's 03) must choose `ToChar(int)`,
  where `net.cls` alone would choose `ToChar(string)` for the Rexx string
  `"84"`. Other arguments convert as `net.cls` converts them (a superset of
  what CLR.CLS accepted: CLR.CLS required exact types, through
  `Type.GetMethod(name, types)`).
- **Instance and static members together.** CLR.CLS looked members up with
  `Type.GetMethod` / `GetProperty`'s default flags, which find static members
  through an instance: `.clr~new("System.DateTime")~Now` (Baginski's 09),
  `process~clr.dispatch("Start", file)` for the static `Process.Start(string)`
  (Baginski's `PROCESS.CLS`). The bridge has a lookup mode for this (`"b"` in
  a `send` / `set` request: both scopes' members as one set, overloads chosen
  among all of them), used only by this package.
- **An imported type also reaches its `System.Type`'s members** when no static
  member has the name (`clr.import("System.String")~Name`), as `CLR_Class`
  did.
- **Results stay CLR proxies** (`isA(.CLR)`), so these rules go on applying
  to the objects a program gets back. Strings, numbers, `.nil`, enums and
  arrays come as `net.cls` gives them.

## Differences that stay

- `say o` shows `net.cls`'s `a CLR_PROXY (System.Text.StringBuilder #12)`,
  not CLR.CLS's `a CLR_PROXY[...->[ToString]]`; `o~ToString` gives the text.
- `clr.object` / `clr.type` are .NET objects of this bridge (there is no BSF
  peer); code that sent them BSF messages does not run.
- Types are found as `net.cls` finds them (framework assemblies loaded on
  demand; `.net~load` / `clr.addAssembly` for others), not through
  `Assembly.LoadWithPartialName`.
- A Rexx string that looks like a whole number goes as an `Int32`, so it no
  longer reaches a `string` parameter (`sb~Append("007")` appends `7`): as in
  CLR.CLS. Outside this package, `net.cls`'s rule applies (the parameter's
  type decides).

## The samples (`bridge/tests/clr-samples.sh`)

| Sample | Result (Linux, .NET 10 and 8) |
|---|---|
| raffel/01-helloworld-clr | runs |
| raffel/05-server-clr, 05-client-clr | run (a TCP message from one to the other) |
| baginski/02-streamwriter, 03-streamreader | run |
| baginski/07-MAC | runs up to its last step: the MAC is right (checked against Python's `hmac`); then `Process.Start(file)` opens the file with the default editor on Windows, and on Linux .NET tries to run it |
| baginski/09-clock | runs (in a terminal: `Console.ReadKey`) |
| baginski/08-WebClient | not run here (needs the internet; `WebClient` still exists) |
| raffel/02-eventlog, 03-systemevents, 04-forms; baginski/01, 04, 05, 06, 10–13, 15 | Windows only (event log, system events and sounds, WinForms, `MessageBox`, `SendKeys`, speech): `tests/clr-samples-windows.ps1` runs them, with the person at the keyboard saying whether each did what it should (see `netobject-design.md`, "Windows", for what the bridge needed) |
| baginski/14-menu, 16-GeoLocation | cannot run: `MainMenu` and `System.Device.Location` are not in .NET Core |
| raffel/00-helloworld-bsf | BSF4ooRexx's Java bridge, not CLR.CLS |

## Bridge bugs the samples found (fixed, with tests in `phase1.rex`)

- `.net~type("System.Console")` failed: a type was looked for in the framework
  assemblies named by a prefix of its name (`System.Text.RegularExpressions`
  for `...Regex`), not in one named exactly as the type (`System.Console.dll`).
- `Console.WriteLine("text")` was ambiguous between `WriteLine(string)` and
  `WriteLine(string, params object[])`: a candidate that needs an empty
  `params` array, or a default filled in, now loses a tie, as in C#.
- Also: `.net~type(o)` with `o` a `System.Type` object gives that type.
