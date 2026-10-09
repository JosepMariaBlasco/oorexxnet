# Decisions — 08/10/2026

*The open decisions of the initial design, settled on 08/10/2026. The design
notes refer to them by number.*

**Guiding principle:** we design our bridge without limitations;
compatibility layers (e.g. with BSF4ooRexx's `CLR.CLS`) come afterwards, on
top, and only if needed.

1. **Runtimes: .NET 8 and later only.** Cross-platform and current (also what
   PowerShell 7 runs on). .NET Framework 4.8 stays out of v1: its CLR hosting
   is a different mechanism (COM). Keep the managed code free of needless
   .NET-8-only dependencies, so that Framework support stays possible if a
   real need appears (old applications, PowerShell 5.1).

2. **Names: `.net` (environment) and `.NetObject` (class)**, parallel to
   `.js` / `.JSObject`. `.CLR` is left free for a possible `CLR.CLS`
   compatibility package.

3. **Compatibility with `CLR.CLS`: not a design constraint** (principle
   above). A compatibility package on top later, if needed; its feasibility
   is sketched in `bsf4oorexx-clr.md`.

4. **Callbacks: synchronous by default, queue as an option.** By default a
   .NET callback (event, delegate) runs in Rexx at once, on the .NET thread
   that raises it (thread attached to the interpreter instance), and its
   result goes back to .NET. A queue taken by a Rexx thread (`.JSObject`'s
   model) is available as an option.
   *Why it differs from `.JSObject`:* JavaScript is single-threaded and a
   queue is natural there; .NET is not. GUI handlers (WinForms, WPF) run on
   the GUI thread while the main Rexx thread sits in `Application.Run`, and
   often must answer synchronously (`FormClosing`'s `e.Cancel`, return
   values); a queue cannot do that.
   *To verify in the prototype:* the ooRexx kernel lock while a Rexx thread is
   inside native code (`Application.Run`), so that an attached thread can run.

5. **Overloads and conversions: choose the member first, then convert.**
   Candidates by name and argument count; each Rexx string converted to the
   parameter's type (numbers to any numeric type they fit, `1`/`0` to `bool`,
   one character to `char`, `.nil` to `null` for reference and nullable
   types). Preference: exact, then widening, then conversion from string.
   Ambiguity is an error listing the candidates. Forcing: typed values
   (`.net~int16(x)` …) and a way to give the signature explicitly.
   (The opposite of `CLR.CLS`, which fixes each value's .NET type before
   choosing.)

6. **All of it in v1**, in this order: generics, structs, `IEnumerable`
   (`DO x OVER`), arrays and indexers; then `ref` / `out` (the call also
   returns the out values); then `Task` (`~await`).

7. **The .NET side's API for Rexx objects: both** `dynamic` (`r.Upper()`)
   and an explicit `SendMessage(name, args)`.

8. **Packaging: in the end, an ooRexx extension.** For ooRexx: an extension
   package (`net.cls` + the native library + the managed assembly); for .NET
   applications: a NuGet package with the native shim per platform. Until
   then the code lives in this project.

9. **PowerShell: later.** A sample of its own, not a v1 priority (the
   PowerShell SDK comes from NuGet and runs on Linux too).

10. **Coordination with ooRexx/Python: later.** The shared conventions
    document is not written now.
