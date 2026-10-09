# BSF4ooRexx's CLR support ("ooRexx.NET") — reading notes

*08/10/2026. Read from BSF4ooRexx SVN trunk, r1125
(`https://svn.code.sf.net/p/bsf4oorexx/code/trunk`).*

## Where it is

There is no `samples/CLR`: the material is called `oorexx.net`.

- `trunk/bsf4oorexx.dev/oorexx.net/` — the whole thing:
  - `src/CLR.CLS` (1659 lines; = `bin/CLR.CLS`), version `100.20160812`,
    last changed r928 (2022-08-04, after r582 2018, r356–358 2016);
  - `src/Helper4ooRexx4Net/…/Helper4ooRexx4Net.java` (932 lines; version
    `100.20190815`): boxing / unboxing and caseless member-name lookup, done
    in Java for speed;
  - `src/jni4net/` — `oorexx.net.proxygen.xml` (jni4net proxies generated
    for `System.EventHandler` and `System.EventArgs` only) and the C# side,
    `oorexx.net.dll` (strong-named, must go into the GAC);
  - `src/gacutilrgf/` — a small C# tool to install into the GAC;
  - `bin/` — `jni4net.j-0.8.8.0.jar`, `jni4net.n-0.8.8.0.dll`,
    `jni4net.n.w32/w64.v20/v40-0.8.8.0.dll`, `oorexx.net.jar/.dll`,
    `install_clr_support.cmd`;
  - `docs/` — Manuel Raffel's thesis (2015-08-10, *ooRexx.NET — Bridging
    .NET and ooRexx*, WU Wien) and Adrian Baginski's cookbook (2016-07-23),
    plus ooRexxDoc of `CLR.CLS`;
  - `samples/clr/raffel/` (00–05) and `samples/clr/baginski/` (01–16 +
    `PROCESS.CLS`).
- `trunk/samples/oorexx.net/` — Raffel's samples 01–05 again (the ones that
  ship; shorter headers, same code).

Authors: Manuel Raffel (design and first implementation, fall 2015), Rony
(rework, summer 2016). Apache 2.0.

## How it reaches .NET: confirmed, jni4net

    Rexx → BSF4ooRexx → JVM (JNI) → jni4net 0.8.8.0 → CLR (.NET Framework)

- jni4net is a Java↔.NET bridge over JNI; its last release (0.8.8.0, ~2015)
  supports .NET Framework 2.0 / 4.0, Windows only (`w32` / `w64` DLLs), and
  Java up to 8 — **hence the support being confined to Java 8**. Unmaintained.
- `CLR.CLS` starts jni4net (`net.sf.jni4net.Bridge~init`), loads assemblies by
  `Assembly.LoadWithPartialName` (obsolete since .NET 2.0), and caches the
  exported type names of `mscorlib` and `System` to map a type name to its
  assembly; for other types it guesses the assembly as the namespace
  (`System.Windows.Forms.Form` → assembly `System.Windows.Forms`).
- Every CLR object is a BSF (Java) object proxying a jni4net proxy. The thesis
  itself lists the confusion "a CLR or a BSF_REFERENCE?" as a defect.
- **Only ooRexx → .NET.** There is no .NET → ooRexx direction (no way for a
  .NET program to run Rexx), apart from event callbacks into Rexx objects.
  The bidirectional half is new ground.

## The API

`::requires CLR.CLS` (which requires `BSF.CLS`).

| What | How |
| --- | --- |
| New instance | `.CLR~new("System.IO.StreamWriter", path)` |
| A type (static members, `new`) | `t = clr.import("System.Console")`; `t~WriteLine("hi")`; `.clr.import`'d class `~new(args)` |
| Store a type in `.local` | `.CLR~clr.import(name [, name4local])` (default: the type name, so `.System.Console`) — the routine `clr.import` defaults to *not* storing it (inconsistent) |
| Methods, properties, fields, events | `o~Name(args)`: `unknown` looks up caselessly, in this order: method, property, field, event |
| Set a property | `o~Text = "x"` (the `name=` message) |
| Name clashes with Rexx methods | `o~clr.dispatch("Start", args…)` (e.g. `start`, `init`, `class`) |
| Events | `h = clr.createEventHandler(rexxObj [, userData])`; `o~Click += h`, `o~Click -= h` (`CLR_Event` `+` / `-` call `add_Click` / `remove_Click`); .NET calls `rexxObj~invoke(sender, eventArgs)` |
| Threads | subclass `CLRThread`, implement `run`, `~start` (a `java.lang.Thread`) |
| Arrays | `clr.createArray("System.Byte", 1024)` (empty only) |
| Explicit types | `clr.box("Int16", 5)` (indicators `BO BY CHAR DE DO INT16 UINT16 INT32 UINT32 INT64 UINT64 SB SI ST` or long names), `.CLR~new("System.Int16", 5)`; `clr.unbox(o)` |
| Peer objects | `o~clr.object`, `o~clr.type` (BSF objects) |
| Logging | `.CLRLogger~logLevel = "DEBUG"`; `.clr.dir` holds the package's state |

Classes: `CLR` (public), `CLR_Proxy` (wraps objects returned from .NET),
`CLR_Class` (imported types; class-side `unknown` tries static members first,
then instance members), `CLR_Enum` (compares with Rexx strings caselessly:
`if res = "Yes"`), `CLR_Event`, `CLRThread`, `CLRLogger`.

Names: routines and methods with a dot (`clr.import`, `clr.dispatch`,
`clr.object`) so they cannot clash with .NET members — the same trick as
BSF4ooRexx's `bsf.import`, `bsf.dispatch`.

### Values

- **Rexx → .NET** (`clr.wrap`): a whole number in the Int32 range → `Int32`,
  in the Int64 range → `Int64`, any other number → `Decimal`; any other
  string → `String`; a `CLR` object → itself; `.nil` → error.
  So `.true` (`"1"`) goes as `Int32 1`, not `Boolean`, as a method
  argument.
- **Property assignment** converts to the property's declared type: enums
  from a bare name (`form~AutoSizeMode = GrowAndShrink`, i.e. the unassigned
  symbol's value), others through `.CLR~new(propertyType, value)` (so
  `.true` → `Boolean` works there).
- **.NET → Rexx**: boxed primitives and `String` become Rexx strings
  (culture-neutral formatting, in the Java helper); `System.Enum` →
  `CLR_Enum`; everything else → `CLR_Proxy`; `void` / null → `.nil`.

### Overloads

`clr.type~GetMethod(name, argTypes)` with the runtime types of the wrapped
arguments, then `Invoke`; constructors the same (`GetConstructor(argTypes)`).
So the choice is .NET's default binder. Checked on .NET 8 (same
`DefaultBinder` as .NET Framework), with `Int32` / `String` arguments, as
`clr.wrap` produces them:

- accepted: widening (`Int32` → `Double`, `Int64`; `Math.Max(int, double)` →
  `Max(Double, Double)`), base classes, interfaces, `Object`;
- refused (no method found): narrowing (`Int32` → `Int16`, `Byte`),
  `Int32` → `Boolean` (so `.true` cannot be passed to a `bool` parameter;
  only property assignment converts), `null` arguments (`clr.wrap(.nil)`
  raises), `params`, optional arguments.

### Not supported

Generics (a jni4net limitation, the thesis's main "severe shortcoming");
`ref` / `out`; delegates other than `System.EventHandler` (only it was run
through proxygen); arrays with content; indexers (except through `get_Item`);
`IEnumerable` iteration (samples use `GetEnumerator` / `MoveNext` /
`Current` by hand); `Task` / async; .NET Core / .NET 5+; non-Windows.

### Threads and callbacks

Event handlers run at once, on the .NET thread that raises the event (via
BSF4ooRexx's Java callback support): model (b) of the initial design (synchronous, on the raising thread). The
samples start a `CLRThread` from every GUI handler so the handler returns at
once (and a comment in `unknown` notes that Rexx `REPLY` there broke in
2016; Java threads worked).

## The samples

| Sample | Shows | Portable to .NET 8 on Linux? |
| --- | --- | --- |
| raffel/01-helloworld | `System.Console~WriteLine` | yes |
| raffel/02-eventlog | `EventLog` entries, `SystemSounds` | no (Windows) |
| raffel/03-systemevents | `Microsoft.Win32.SystemEvents~TimeChanged +=` | no (Windows) |
| raffel/04-forms | WinForms form, progress bar, `Click +=`, `CLRThread` | Windows only (.NET 8 WinForms) |
| raffel/05-client, 05-server | `TcpClient` / `TcpListener`, `Encoding.UTF8`, byte array | yes |
| baginski/01-systemsounds | `SystemSounds` | no |
| baginski/02, 03 | `StreamWriter` / `StreamReader` | yes |
| baginski/04, 05 | `MessageBox`, `DialogResult` enums | Windows |
| baginski/06 + `PROCESS.CLS` | `Process`, `ProcessStartInfo`, `SendKeys` | partly |
| baginski/07-MAC | `ASCIIEncoding`, `HMACMD5`, `BitConverter` | yes |
| baginski/08-WebClient | `WebClient~DownloadString`, `Regex` | yes (`WebClient` obsolete but present) |
| baginski/09-clock | `DateTime~Now`, `Console~ReadKey`, `CLRThread` | yes |
| baginski/10–13 | WinForms: labels, fonts, icons, bitmaps, dialogs | Windows |
| baginski/14-menu | WinForms `MainMenu` / `MenuItem` | no: removed in .NET Core 3.1 |
| baginski/15-text.to.speech | `System.Speech` | Windows (NuGet) |
| baginski/16-GeoLocation | `System.Device.Location` | no (.NET Framework only) |

(Portability judged from what I know of .NET 8; to verify when we run them.)

## What it means for us

**Decision 3 (compatibility).** The API is small and clear, and the samples
are short and readable: good material for our own tests. Proposal: our own
bridge, with the conventions of `.JSObject` (decision 2), plus a `CLR.CLS`
compatibility package on top, as `BSF.CLS` was done for JDOR in ooRexx/WASM,
so that Raffel's and Baginski's samples run unchanged (the portable ones here,
the WinForms ones on Windows). What cannot be kept: `clr.object` /
`clr.type` returning BSF objects (no Java any more); they would return our
own handles. Everything else maps directly.

**Lessons for our design.**

- The weak spot is argument conversion: Rexx values get a .NET type before
  the method is chosen (a whole number is always `Int32`), so `bool`,
  `short`, `byte`, `char`, `float` parameters and `null` need `clr.box` or
  fail. Ours should choose the overload first and convert each Rexx string
  to the parameter's type, with explicit types when ambiguous (decision 5).
- Generics are the first thing users hit; we have no jni4net in between, so
  `List<int>` etc. are possible from the start (decision 6).
- Any delegate type, not only `EventHandler`: build the delegate on the .NET
  side with `Expression` / `DynamicMethod` for the event's own type.
- `DO x OVER o` over `IEnumerable`, and arrays with content, are cheap wins
  the thesis already asked for.
- Its callback model is (b), callbacks at once on the .NET thread; the
  samples work around its problems with a thread per handler. That argues
  for (a), the queue, as the default, and (b) as an option (decision 4).
- Its names (`clr.import`, `.CLR~new`, `clr.dispatch`, `+=`) are what
  BSF4ooRexx users know; worth keeping in the compatibility package
  regardless of what we name the native API.
- Nothing on the .NET → ooRexx side to reuse: that half is ours to design.
