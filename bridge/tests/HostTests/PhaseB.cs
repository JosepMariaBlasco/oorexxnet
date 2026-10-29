// .NET -> ooRexx, phase B: tests of the environment (commands, I/O,
// cancellation). notes/rexx-from-net-design.md, "Phase B: built".
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Rexx.Net;

/// Holds a delegate that Rexx code hands over (HandlerAsFunction).
public sealed class Holder { public Func<RexxFunctionCall, object?>? F; public void Set(Func<RexxFunctionCall, object?> f) => F = f; }

static partial class Program
{

    static void PhaseB()
    {
        var err = new StringWriter();
        using var rexx = RexxInterpreter.Create(new RexxOptions { Error = err });
        Commands(rexx, err);
        Io(rexx, err);
        Cancellation(rexx);
        rexx.Dispose();
        CommandsWhileRexxRuns();
        HandlerAsFunction();
        SignalPastTheHost();
        OptionsErrorSyntax();
        HaltBackAsHalt();
        ReliableCancellationOff();
        HandlersGoOnDispose();
        ContextAfterTheHandler();
    }

    // The context is valid only while its handler runs: kept and used after,
    // ObjectDisposedException (its proxy is made on first use, released at
    // the end).
    static void ContextAfterTheHandler()
    {
        using var rexx = RexxInterpreter.Create();
        RexxCommandContext? kept = null, unused = null;
        rexx.AddCommandEnvironment("KEEP", (c, ctx) => { kept = ctx; return ctx.HasVar("NOPE") ? 1 : 0; });
        rexx.AddCommandEnvironment("UNUSED", (c, ctx) => { unused = ctx; return 0; });
        Ok("a handler that asks its context", rexx.Run("address keep 'x'; return rc"), "0");
        Throws<ObjectDisposedException>("... the context kept and used after the handler", () => kept!.HasVar("X"));
        Ok("a handler that never asks it", rexx.Run("address unused 'x'; return rc"), "0");
        Throws<ObjectDisposedException>("... the same after the handler", () => unused!.HasVar("X"));
    }

    // Disposing an instance lets its command handlers go, even while the
    // application keeps the RexxInterpreter object (oorexx-bridges, command
    // handlers: a lesson of the Python bridge).
    static void HandlersGoOnDispose()
    {
        var rexx = RexxInterpreter.Create();
        var weak = AddHeldHandler(rexx);
        Ok("a handler's delegate lives while its instance does", weak.IsAlive, true);
        rexx.Dispose();
        GC.Collect(); GC.WaitForPendingFinalizers(); GC.Collect();
        Ok("... and goes when it is disposed (the instance object kept)", weak.IsAlive, false);
        GC.KeepAlive(rexx);
    }

    [System.Runtime.CompilerServices.MethodImpl(System.Runtime.CompilerServices.MethodImplOptions.NoInlining)]
    static WeakReference AddHeldHandler(RexxInterpreter rexx)
    {
        var state = new object();
        Func<string, RexxCommandContext, object?> h = (c, ctx) => state.GetHashCode();
        rexx.AddCommandEnvironment("HELD", h);
        return new WeakReference(h);
    }

    // Rexx -> the host (a command handler, a function) -> Rexx code that
    // RAISEs USER, with no Rexx activation of the bridge in between, and
    // SIGNAL ON USER in the caller. Up to ooRexx r13320 the condition was lost
    // where the API runs Rexx code (bug #2123); now it comes back as itself,
    // with its description (rule 1 of oorexx-bridges' command handlers), and
    // the SIGNAL does not unwind through .NET's frames: the host raises it
    // again on its own context, which the native call returns to.
    static void SignalPastTheHost()
    {
        using var rexx = RexxInterpreter.Create();
        rexx.AddCommandEnvironment("RAISING", (c, ctx) => ctx.Interpreter.Run("raise user x description 'd' return 7"));
        rexx.AddFunction("RAISING", call => call.Interpreter.Run("raise user x description 'd' return 7"));
        Ok("SIGNAL ON past the host: a command, the condition as itself",
           rexx.Run("signal on user x; address raising 'go'; return 'not trapped, rc' rc\nx: return condition('C') condition('D')"), "USER X d");
        Ok("... a function",
           rexx.Run("signal on user x; v = raising(); return 'not trapped:' v\nx: return condition('C') condition('D')"), "USER X d");
        // A message the handler sends (RexxObject.Send) to a Rexx method that
        // raises a condition: ooRexx looked for the trap past .NET's frames,
        // and the caller's SIGNAL ended the process (a C++ exception through
        // the CLR). Sent nested now, as from a thread of its own: a HALT
        // comes back as a HALT, a NOTREADY as itself (rule 1; since #2123).
        rexx.AddCommandEnvironment("SENDING", (c, ctx) => ((RexxObject)ctx["O"]!).Send(c));
        rexx.AddFunction("SENDING", call => ((RexxObject)call.Arguments[0]!).Send(call.Arg<string>(1)));
        const string Raiser = "\n::class Raiser\n::method halt; raise halt\n::method notready; raise notready description 'd' return 9";
        Ok("SIGNAL ON HALT past the host's Send: a command",
           rexx.Run("o = .Raiser~new; signal on halt name x; address sending 'halt'; return 'not trapped'\nx: return condition('C')" + Raiser), "HALT");
        Ok("... SIGNAL ON NOTREADY: a command, NOTREADY",
           rexx.Run("o = .Raiser~new; signal on notready name x; address sending 'notready'; return 'not trapped, rc' rc\nx: return condition('C') condition('D')" + Raiser), "NOTREADY d");
        Ok("... SIGNAL ON HALT: a function",
           rexx.Run("signal on halt name x; v = sending(.Raiser~new, 'halt'); return 'not trapped'\nx: return condition('C')" + Raiser), "HALT");
        // An object that is not a string, made text by the host (ToString:
        // ooRexx's requestString, which raises NOSTRING when the caller traps
        // it): its text, no NOSTRING (before, the SIGNAL ended the process).
        rexx.AddFunction("TEXT", call => call.Arguments[0]!.ToString());
        Ok("SIGNAL ON NOSTRING, the host makes .object~new text",
           rexx.Run("signal on nostring name x; return text(.object~new)\nx: return 'NOSTRING'"), "an Object");
        Ok("... SIGNAL ON NOTREADY: a function",
           rexx.Run("signal on notready name x; v = sending(.Raiser~new, 'notready'); return 'not trapped:' v\nx: return condition('C') condition('D')" + Raiser), "NOTREADY d");
        // An object whose own STRING (or MAKESTRING) raises a condition, made
        // text by the host: a RexxException, and from a function the caller's
        // SIGNAL ON traps it as itself (oorexx-bridges, lesson 6). A SYNTAX
        // crashed the process (a null string read); a SUPPLIER answering no
        // Supplier too (now Error 98.994, as DO ... OVER gives).
        const string Repliers = "\n::class S\n::method init; expose k; use arg k\n" +
            "::method string; expose k; if k = 'SYNTAX' then raise syntax 93.900 array('string says no'); raise user says description 'd'\n" +
            "::class D subclass directory\n::method init; expose k; use arg k; self~init:super; self['A'] = 1\n" +
            "::method supplier; expose k; if k = 'WRONG' then return 'x'; if k = 'USER' then raise user says description 'd'";
        var syntaxString = rexx.Run<RexxObject>("return .S~new('SYNTAX')" + Repliers);
        Throws<RexxException>("ToString, the object's STRING raising SYNTAX", () => syntaxString.ToString(), "string says no");
        var userString = rexx.Run<RexxObject>("return .S~new('USER')" + Repliers);
        Throws<RexxException>("... raising USER", () => userString.ToString(), "USER");
        Ok("... from a function, SIGNAL ON SYNTAX in the caller",
           rexx.Run("signal on syntax name x; return text(.S~new('SYNTAX'))\nx: return condition('O')~code" + Repliers), "93.900");
        Ok("... SIGNAL ON USER in the caller",
           rexx.Run("signal on user says name x; return text(.S~new('USER'))\nx: return condition('C') condition('D')" + Repliers), "USER SAYS d");
        var noSupplier = rexx.Run<RexxObject>("return .D~new('NOTHING')" + Repliers);
        Throws<RexxException>("Supplier, its SUPPLIER answering nothing", () => noSupplier.Supplier(), "to a supplier object");
        Throws<RexxException>("... converted to a dictionary", () => RexxConvert.To<Dictionary<string, object?>>(noSupplier), "to a supplier object");
        var wrongSupplier = rexx.Run<RexxObject>("return .D~new('WRONG')" + Repliers);
        Throws<RexxException>("... answering a string", () => wrongSupplier.Supplier(), "to a supplier object");
        var userSupplier = rexx.Run<RexxObject>("return .D~new('USER')" + Repliers);
        Throws<RexxException>("... raising USER", () => userSupplier.Supplier(), "USER");
        // RAISE ... RETURN value, untrapped (or after CALL ON): the function
        // answers the value, as in plain Rexx
        Ok("... untrapped, a function: RAISE ... RETURN's value",
           rexx.Run("v = raising(); return 'went on:' v"), "went on: 7");
        Ok("... after CALL ON USER",
           rexx.Run("call on user x name h; v = raising(); return 'resumed:' v\nh: return"), "resumed: 7");
        // untrapped, a condition other than SYNTAX or HALT is ignored, as in
        // plain Rexx: the command goes on, its RC the RETURN value (what a
        // handler written in Rexx doing the same would answer)
        Ok("... untrapped: the caller goes on",
           rexx.Run("address raising 'go'; return 'went on, rc' rc"), "went on, rc 7");
    }

    // A HALT in Rexx code that a .NET handler (or function) runs, not trapped
    // there, reaches .NET as SYNTAX 4.1; the Rexx code that sent the command
    // (called the function) gets a HALT again, by halting its thread
    // (oorexx-bridges, command handlers, rule 1): SIGNAL ON HALT traps it,
    // CALL ON HALT runs after the next clause, untrapped it is SYNTAX 4.1.
    // RexxOptions.ReliableCancellation (on by default: the RXINI exit). Off,
    // the instance has no RXINI exit; programs, routines and cancellation of
    // running code work as before.
    static void ReliableCancellationOff()
    {
        using var rexx = RexxInterpreter.Create(new RexxOptions { ReliableCancellation = false });
        Ok("ReliableCancellation off: a routine call", rexx.Run("call r; return result\n::routine r; return 'ran'"), "ran");
        using var cts = new System.Threading.CancellationTokenSource();
        var t = new System.Threading.Thread(() => { System.Threading.Thread.Sleep(300); cts.Cancel(); });
        t.Start();
        string got;
        try { rexx.Run("do forever; nop; end", cts.Token); got = "not cancelled"; }
        catch (OperationCanceledException) { got = "cancelled"; }
        t.Join();
        Ok("... a running Run still cancelled", got, "cancelled");
    }

    static void HaltBackAsHalt()
    {
        using var rexx = RexxInterpreter.Create();
        rexx.AddCommandEnvironment("HALTING", (c, ctx) => ctx.Interpreter.Run("raise halt"));
        rexx.AddFunction("HALTING", call => call.Interpreter.Run("raise halt"));
        Ok("a HALT through a .NET command handler: SIGNAL ON HALT",
           rexx.Run("signal on halt; address halting 'go'; return 'not trapped'\nhalt: return condition('C')"), "HALT");
        Ok("... CALL ON HALT, after the next clause",
           rexx.Run("h = 0; call on halt name seen; address halting 'go'; nop; nop; return rc h\nseen: h = 1; return"), "0 1");
        Ok("... untrapped: SYNTAX 4.1",
           rexx.Run("signal on syntax; address halting 'go'; return 'nothing'\nsyntax: return condition('O')~code"), "4.1");
        Ok("a HALT through a .NET function: SIGNAL ON HALT",
           rexx.Run("signal on halt; v = halting(); return 'not trapped'\nhalt: return condition('C')"), "HALT");
        Ok("... CALL ON HALT, after the next clause",
           rexx.Run("h = 0; call on halt name seen; v = halting(); nop; nop; return h\nseen: h = 1; return"), "1");
        Ok("... untrapped: SYNTAX 4.1",
           rexx.Run("signal on syntax; v = halting(); return 'nothing'\nsyntax: return condition('O')~code"), "4.1");
    }

    // ::OPTIONS ERROR SYNTAX in the code that sends the command (ooRexx #2119,
    // fixed in r13282: it turned a handler's non-ERROR condition into SYNTAX
    // 98.970). The bridge raises ERROR and FAILURE on the sender itself
    // (RaiseCondition), not through the path #2119 was in: measured the same
    // on r13278 and r13282. A guard: they stay themselves under the option.
    static void OptionsErrorSyntax()
    {
        using var rexx = RexxInterpreter.Create();
        rexx.AddCommandEnvironment("F", (c, ctx) => ctx.RaiseFailure(9));
        rexx.AddCommandEnvironment("E", (c, ctx) => ctx.RaiseError(4));
        const string traps = "signal on failure; signal on error; signal on syntax\naddress {0} 'x'\nreturn 'none'\n" +
            "failure: return 'FAILURE' rc\nerror: return 'ERROR' rc\nsyntax: return 'SYNTAX' condition('O')~code\n" +
            "::options error syntax\n";
        Ok("::options error syntax: FAILURE stays FAILURE (#2119)", rexx.Run(string.Format(traps, "F")), "FAILURE 9");
        Ok("... ERROR stays ERROR (raised by the bridge)", rexx.Run(string.Format(traps, "E")), "ERROR 4");
    }

    // A .NetHandler made in Rexx, given to the application, which adds it as
    // a function: its Rexx error comes back whole (the condition rexxnet
    // holds, raised again: its substitutions too).
    static void HandlerAsFunction()
    {
        using var rexx = RexxInterpreter.Create();
        var holder = new Holder();
        rexx.Run("use arg h; h~Set(.net~handler(.F~new, 'TWICE')); return\n" +
                 "::requires 'net.cls'\n::class F\n::method twice\n  use arg call\n  return call~Arguments[1] * 2", holder);
        rexx.AddFunction("NETFN", holder.F!);
        Ok("a .NetHandler as a function",  rexx.Run("return netfn(3)"), "6");
        Ok("... its Rexx error, whole",    rexx.Run("signal on syntax; x = netfn('a'); return 'no'\n" +
                                                    "syntax: return condition('O')~code '|' condition('O')~message"),
                                          "41.1 | Nonnumeric value (\"a\") used in arithmetic operation.");
    }

    // Environments added while other threads run Rexx in the instance, and
    // ADDRESS to environments not added yet: ooRexx bugs #2111 (adding without
    // the kernel lock: a livelock or a corrupted heap) and #2112 (resolving an
    // unknown environment: a crash), fixed in ooRexx r13274 and r13275.
    static void CommandsWhileRexxRuns()
    {
        const int envs = 200, threads = 4, n = 2000;
        const string prog = """
            use arg n, envs
            hits = 0
            do i = 1 to n
              e = "E" || random(1, envs)
              s = copies(e, 20)~reverse~lower
              address value e
              'x' s
              if rc == 7 then hits += 1
            end
            return hits
            """;
        bool done = true; long hits = 0;
        for (int round = 0; round < 3 && done; round++)
        {
            using var rexx = RexxInterpreter.Create(new RexxOptions { Error = new StringWriter() });
            var work = Enumerable.Range(0, threads).Select(_ => Task.Run(() => long.Parse(rexx.Run(prog, n, envs)!.ToString()!))).ToArray();
            for (int e = 1; e <= envs; e++) rexx.AddCommandEnvironment("E" + e, (c, ctx) => 7);
            // a new name each time (adding a name again only stacks a handler
            // over it), until the threads end
            var sw = System.Diagnostics.Stopwatch.StartNew();
            for (int k = 0; !work.All(t => t.IsCompleted) && sw.ElapsedMilliseconds < 60000; k++)
                rexx.AddCommandEnvironment($"X{round}_{k}", (c, ctx) => 7);
            done = Task.WaitAll(work, 60000);
            if (done) hits += work.Sum(t => t.Result);
        }
        Ok("environments added while 4 threads run Rexx (ooRexx #2111, #2112)", done && hits > 0, true);
    }

    static void Commands(RexxInterpreter rexx, StringWriter err)
    {
        // a handler gets the command and ooRexx's own .CommandContext (RexxCommandContext)
        string? lastEnvironment = null, lastCommand = null;
        rexx.AddCommandEnvironment("APP", (c, ctx) =>
        {
            lastEnvironment = ctx.Environment; lastCommand = c;
            if (c == "null") return null;
            if (c.StartsWith("error ")) return ctx.RaiseError(int.Parse(c[6..]));
            if (c.StartsWith("failure ")) return ctx.Raise("FAILURE", int.Parse(c[8..]), "it could not run", "the additional");
            if (c == "throw") throw new InvalidOperationException("the application is not ready");
            if (c == "nested") return ctx.Interpreter.Run("use arg a; return a * 7", 6);
            if (c == "nested error") return ctx.Interpreter.Run("return 1 + 'a'");
            if (c == "object") return rexx.NewArray("a", "b");
            return c.Length;
        });
        Ok("command: RC",                rexx.Run("address app 'open the door'; return rc"), "13");
        Ok("... environment, command",   $"{lastEnvironment}|{lastCommand}", "APP|open the door");
        Ok("ADDRESS app, then a command", rexx.Run("address app; 'hello'; return rc"), "5");
        Ok("ADDRESS 'app' (case)",       rexx.Run("address 'app' 'x'; return rc"), "1");
        Ok("null result: RC 0",          rexx.Run("address app 'null'; return rc"), "0");
        Ok("an object as RC",            rexx.Run("address app 'object'; return rc~class~id rc~items"), "Array 2");
        Ok("RaiseError: ERROR, trapped", rexx.Run("signal on error; address app 'error 5'; return 'no'\n" +
                                                   "error: return condition('C') rc"), "ERROR 5");
        Ok("ERROR, untrapped: RC",       rexx.Run("address app 'error 7'; return rc"), "7");
        Ok("Raise FAILURE, trapped",     rexx.Run("signal on failure; address app 'failure 9'; return 'no'\n" +
                                                   "failure: return condition('C') rc condition('D') '|' condition('A')"),
                                         "FAILURE 9 it could not run | the additional");
        Ok("FAILURE untrapped -> ERROR", rexx.Run("signal on error; address app 'failure 9'; return 'no'\n" +
                                                   "error: return condition('C') rc"), "ERROR 9");
        Ok(".NET exception: SYNTAX 98.900", rexx.Run("signal on syntax; address app 'throw'; return 'no'\n" +
                                                   "syntax: o = condition('O'); return o~code '|' o~additional[1]"),
                                         "98.900 | .NET error: System.InvalidOperationException: the application is not ready");
        Ok("... the exception, additional[2]", rexx.Run("signal on syntax; address app 'throw'; return 'no'\n" +
                                                   "syntax: return condition('O')~additional[2]~Message"), "the application is not ready");
        try { rexx.Run("address app 'throw'"); Ok("... untrapped", "none", "thrown"); }
        catch (RexxException e) { Ok("... untrapped", $"{e.Code} {e.InnerException?.GetType().Name}", "98.900 InvalidOperationException"); }
        Ok("RC's sign raises nothing",   rexx.Run("signal on error; signal on failure; address app 'x'; a = rc\n" +
                                                   "address app 'abc'; return a rc\nerror: failure: return 'raised'"), "1 3");
        Ok("handler calls Rexx",         rexx.Run("address app 'nested'; return rc"), "42");
        Ok("... its error, raised again", rexx.Run("signal on syntax; address app 'nested error'; return 'no'\n" +
                                                    "syntax: return condition('O')~code"), "41.1");
        try { rexx.Run("address app 'nested error'"); Ok("... untrapped", "none", "thrown"); }
        catch (RexxException e) { Ok("... untrapped", e.Code, "41.1"); }

        // an Action; as ooRexx's .CommandHandler~register / ~deregister: stacked, uncovered
        rexx.AddCommandEnvironment("PLAIN", (c, ctx) => "ran " + c);
        Ok("a handler",                  rexx.Run("address plain 'x'; return rc"), "ran x");
        int seen = 0;
        rexx.AddCommandEnvironment("LOG", (string c, RexxCommandContext ctx) => { seen++; });
        Ok("Action: RC 0",               rexx.Run("address log 'a'; address log 'b'; return rc") + " " + seen, "0 2");
        var coveredPlain = rexx.AddCommandEnvironment("PLAIN", (c, ctx) => "stacked");
        Ok("a second handler covers the first", rexx.Run("address plain 'x'; return rc"), "stacked");
        Ok("... the first, the answer", coveredPlain?.Send("ISA", rexx.FindClass("CommandHandler")), "1");
        Ok("... .CommandHandler~handlers", rexx.Run("return .CommandHandler~handlers('PLAIN')~items"), "2");
        Ok("an unknown environment (RXSUBCOM_NOTREG)", rexx.Run("address nosuch 'x'; return rc"), "30");
        var removedPlain = rexx.RemoveCommandEnvironment("plain");
        Ok("removing: the handler removed", removedPlain.Send("ISA", rexx.FindClass("CommandHandler")), "1");
        Ok("... uncovers the first", rexx.Run("address plain 'x'; return rc"), "ran x");
        rexx.RemoveCommandEnvironment("PLAIN");
        using (var gone = RexxInterpreter.Create()) { gone.Dispose(); Throws<ObjectDisposedException>("RemoveCommandEnvironment, disposed", () => gone.RemoveCommandEnvironment("X")); }
        Throws<InvalidOperationException>("RemoveCommandEnvironment: none there", () => rexx.RemoveCommandEnvironment("PLAIN"), "no command environment PLAIN");
        Ok("... then FAILURE, RC 30, as unknown", rexx.Run("signal on failure; address plain 'x'; return 'no'\n" +
                                                   "failure: return condition('C') rc condition('D') (condition('O')~additional == .nil)"), "FAILURE 30 x 1");
        rexx.AddCommandEnvironment("PLAIN", (c, ctx) => "back");
        Ok("... added again",            rexx.Run("address plain 'x'; return rc"), "back");
        rexx.Run(".CommandHandler~deregister('PLAIN')");
        rexx.AddCommandEnvironment("PLAIN", (c, ctx) => "back");
        Ok("... added again after .CommandHandler~deregister", rexx.Run("address plain 'x'; return rc"), "back");
        var keptOutput = rexx.Output;
        rexx.Output = new StringWriter();                 // the I/O forwarders installed
        Ok("the bridge's own entries are not among the environments",
           rexx.Run("return .CommandHandler~environments~allIndexes~makeString('l', ' ')~pos('REXXNET')"), "0");
        rexx.Output = keptOutput;
        Throws<ArgumentNullException>("a null handler", () => rexx.AddCommandEnvironment("NULL", (Func<string, RexxCommandContext, object?>)null!));
        using (var other = RexxInterpreter.Create())
        {
            other.AddCommandEnvironment("APP", (c, ctx) => "other");
            Ok("two instances, one name", other.Run("address app 'x'; return rc") + " " + rexx.Run("address app 'x'; return rc"), "other 1");
            other.Dispose();
        }

        // the variables of the code that sent the command, as ooRexx's context has them
        RexxCommandContext? kept = null;
        rexx.AddCommandEnvironment("VARS", (c, ctx) =>
        {
            kept = ctx;
            switch (c)
            {
                case "get": return $"{ctx["x"]} {ctx["S.1"]} {ctx.GetVar("s.2")} {ctx["nope"]} {ctx.HasVar("x")} {ctx.HasVar("nope")}";
                case "set": ctx["y"] = 5; ctx.SetVar("T.1", "one"); ctx["N"] = null; ctx.DropVar("z"); return null;
                case "all": return ctx.Variables.Send("HASINDEX", "A")?.ToString() + ctx.Variables.Send("HASINDEX", "NOPE");
                case "object": return ctx["A"] is RexxObject a && a.Send<int>("items") == 3;
                case "valid": return ctx.IsValid;
            }
            return null;
        });
        Ok("variables: get (no value: its name)", rexx.Run("x = 'ex'; s.1 = 'one'; s.2 = 'two'; drop nope; address vars 'get'; return rc"),
                                         "ex one two NOPE True False");
        Ok("variables: set, drop",       rexx.Run("z = 1; address vars 'set'; return y t.1 (n == .nil) symbol('Z')"), "5 one 1 LIT");
        Ok("variables: all",             rexx.Run("a = 1; b = 2; address vars 'all'; return rc"), "10");
        Ok("variables: an object",       rexx.Run("a = .array~of(1, 2, 3); address vars 'object'; return rc"), "1");
        Ok("IsValid while it runs",      rexx.Run("address vars 'valid'; return rc"), "1");
        Throws<ObjectDisposedException>("the context after its command: released", () => _ = kept!["x"], "");

        // ADDRESS ... WITH: the context's streams
        rexx.AddCommandEnvironment("SORT", (c, ctx) =>
        {
            if (!ctx.IsRedirected("Input"))
            {
                Console.Out.WriteLine("to the console");          // without WITH: the handler's own output
                try { ctx.Output.Send("LINEOUT", "x"); return "an output"; }
                catch (RexxException e) { return "no output: " + e.Code; }
            }
            var lines = new List<string>();
            while (ctx.Input.Send("LINES")!.ToString() != "0") lines.Add(ctx.Input.Send("LINEIN")!.ToString()!);
            lines.Sort(StringComparer.Ordinal);
            foreach (var l in lines) ctx.Output.Send("LINEOUT", l);
            if (ctx.IsRedirected("Error")) ctx.Error.Send("LINEOUT", $"{lines.Count} lines");
            return lines.Count;
        });
        Ok("ADDRESS ... WITH",           rexx.Run("i.1 = 'pear'; i.2 = 'apple'; i.3 = 'fig'; i.0 = 3\n" +
                                                   "address sort 'sort' with input stem i. output stem o. error stem e.\n" +
                                                   "return rc o.0 o.1 o.2 o.3 '/' e.1"), "3 3 apple fig pear / 3 lines");
        Ok("... into an Array",          rexx.Run("out = .array~new; address sort 'sort' with input using (.array~of('b', 'a')) output using (out)\n" +
                                                   "return out~makeString('l', ',')"), "a,b");
        var console = Console.Out;
        var cout = new StringWriter();
        Console.SetOut(cout);
        string notRedirected;
        try { notRedirected = rexx.Run("address sort 'x'; return rc")!.ToString()!; }
        finally { Console.SetOut(console); }
        Ok("... not redirected: Output is SYNTAX 98.900, the console the handler's", $"{notRedirected}|{cout.ToString().Trim()}",
                                         "no output: 98.900|to the console");
        rexx.AddCommandEnvironment("CAT", (c, ctx) =>
        {
            var text = new List<string>();
            while (ctx.Input.Send("LINES")!.ToString() != "0") text.Add(ctx.Input.Send("LINEIN")!.ToString()!);
            // (the core's .CommandOutput splits at .endOfLine: CRLF on Windows)
            ctx.Output.Send("CHAROUT", string.Join(Environment.NewLine, text) + Environment.NewLine + "end");
            return null;
        });
        Ok("CHAROUT (lines)",            rexx.Run("o = .array~new; address cat 'cat' with input using (.array~of('x', 'y')) output using (o)\n" +
                                                   "return o~makeString('l', ',')"), "x,y,end");

        // commands from other threads; a handler's own calls stay on its thread
        int handlerThread = 0, nestedThread = 0;
        rexx.AddCommandEnvironment("WHERE", (c, ctx) =>
        {
            handlerThread = Environment.CurrentManagedThreadId;
            ctx.Interpreter.Run("return 1");
            nestedThread = Environment.CurrentManagedThreadId;
            return Environment.CurrentManagedThreadId;
        });
        int caller = 0;
        string rc = Task.Run(() => { caller = Environment.CurrentManagedThreadId; return rexx.Run("address where 'x'; return rc")!.ToString(); }).Result;
        Ok("a command from another .NET thread", rc == caller.ToString() && handlerThread == caller && nestedThread == caller, true);
        var counts = new int[4];
        rexx.AddCommandEnvironment("COUNT", (c, ctx) => { Interlocked.Increment(ref counts[int.Parse(c)]); return null; });
        Parallel.For(0, 4, i => rexx.Run("use arg i; do 100; address count i; end", i));
        Ok("4 threads, 100 commands each", string.Join(",", counts), "100,100,100,100");

        // the cost of a command
        rexx.AddCommandEnvironment("NOP", (c, ctx) => null);
        var sw = System.Diagnostics.Stopwatch.StartNew();
        rexx.Run("do 20000; address nop 'x'; end");
        double us = sw.Elapsed.TotalMilliseconds * 1000 / 20000;
        if (Environment.GetEnvironmentVariable("HOSTTESTS_RATES") != null) Console.WriteLine($"     a command: {us:F2} µs");
        Ok("a command costs little",     us < 200, true);     // (~10 µs on Linux; a request costs ~36 µs on the Windows runners)
    }

    static void Io(RexxInterpreter rexx, StringWriter err)
    {
        var o = new StringWriter();
        rexx.Output = o;
        rexx.Run("say 'hello'; call lineout , 'two'; call charout , 'a'; call charout , 'b'; .output~lineout('three'); say");
        Ok("Output: say, lineout, charout, .output", o.ToString().Replace("\r", ""), "hello\ntwo\nabthree\n\n");
        Ok("say of an object",           Captured(o, () => rexx.Run("say .object~new")), "an Object\n");
        int e0 = err.ToString().Length;
        rexx.Run("call lineout 'STDERR', 'e1'; .error~lineout('e2'); .error~charout('e3')");
        Ok("Error: STDERR, .error",      err.ToString()[e0..].Replace("\r", ""), "e1\ne2\ne3");
        e0 = err.ToString().Length;
        rexx.Run("trace r; x = 1 + 1; trace off");
        var trace = err.ToString()[e0..];
        Ok("Error: trace output",        trace.Contains("*-* x = 1 + 1;") && trace.Contains(">>>   \"2\""), true);
        e0 = err.ToString().Length;
        try { rexx.Run("x = 1 + 'a'"); } catch (RexxException) { }
        Ok("an error ending a call is not written", err.ToString().Length - e0, 0);

        rexx.Input = new StringReader("l1\nl2\nl3\n");
        Ok("Input: pull, parse linein, linein(), lines()",
           rexx.Run("pull a; parse linein b; c = linein(); d = lines(); e = linein(); f = lines(); return a b c d '['e']' f"),
           "L1 l2 l3 1 [] 0");
        rexx.Input = new StringReader("xy");
        Ok("Input: charin(), .input",    rexx.Run("return charin() || .input~charin || '['charin()']'"), "xy[]");

        // back to the process's own streams, and again
        rexx.Output = null;
        Ok("Output = null: the forwarder passes through", rexx.Run("return .output~current~active"), "0");
        var o2 = new StringWriter();
        rexx.Output = o2;
        rexx.Run("say 'again'");
        Ok("Output set again",           o2.ToString().Replace("\r", "") + "|" + o.ToString().Contains("again"), "again\n|False");
        Ok("a Rexx destination of its own", Captured(o2, () => rexx.Run(
            "d = .array~new; .output~destination(.ArrayStream~new(d)); say 'mine'; .output~destination; say 'ours'; return d[1]\n" +
            "::class ArrayStream; ::method init; expose a; use arg a\n" +
            "::method say; expose a; use arg s; a~append(s); return 0\n" +
            "::method lineout; expose a; use arg s; a~append(s); return 0")), "ours\n");

        // a Rexx thread of its own (reply), writing while .NET waits
        var later = rexx.LoadPackage("threads.cls", "::class Later public\n::method go; reply; call syssleep 0.05; say 'from a Rexx thread'\n").FindClass("Later")!;
        var oThreads = new StringWriter();
        rexx.Output = oThreads;
        later.New()!.Send("go");
        for (int i = 0; i < 100 && !oThreads.ToString().Contains("from a Rexx thread"); i++) Thread.Sleep(20);
        Ok("Output from a Rexx thread", oThreads.ToString().Replace("\r", ""), "from a Rexx thread\n");

        // given at creation
        var oc = new StringWriter();
        using (var created = RexxInterpreter.Create(new RexxOptions { Output = oc, Input = new StringReader("in") }))
        {
            created.Run("parse pull x; say 'got' x");
            Ok("RexxOptions Output, Input", oc.ToString().Replace("\r", ""), "got in\n");
            created.Dispose();
        }

        // the cost of a SAY through the forwarder
        var sink = new StringWriter();
        rexx.Output = sink;
        var sw = System.Diagnostics.Stopwatch.StartNew();
        rexx.Run("do 5000; say 'line'; end");
        double us = sw.Elapsed.TotalMilliseconds * 1000 / 5000;
        if (Environment.GetEnvironmentVariable("HOSTTESTS_RATES") != null) Console.WriteLine($"     a say: {us:F2} µs");
        Ok("5000 says, all there",       sink.ToString().Split('\n').Length - 1, 5000);
        rexx.Output = null;
    }

    static string Captured(StringWriter w, Action a)
    {
        int n = w.ToString().Length;
        a();
        return w.ToString()[n..].Replace("\r", "");
    }

    static void Cancellation(RexxInterpreter rexx)
    {
        // a loop, cancelled
        using (var cts = new CancellationTokenSource(300))
        {
            try { rexx.Run("do forever; nop; end", cts.Token); Ok("cancelled", "returned", "OperationCanceledException"); }
            catch (OperationCanceledException e)
            {
                Ok("cancelled: OperationCanceledException", e.CancellationToken == cts.Token, true);
                Ok("... InnerException 4.1", (e.InnerException as RexxException)?.Code, "4.1");
            }
        }
        // a message, cancelled (Send with a token)
        var spinner = rexx.Run("return .spinner~new\n::class spinner\n::method spin; use arg n; do forever; n += 1; end\n" +
                               "::method add; use arg a, b; return a + b")!;
        using (var cts = new CancellationTokenSource(300))
        {
            try { spinner.Send("SPIN", cts.Token, 0); Ok("Send cancelled", "returned", "OperationCanceledException"); }
            catch (OperationCanceledException e) { Ok("Send cancelled: OperationCanceledException", (e.InnerException as RexxException)?.Code, "4.1"); }
        }
        Ok("Send<T> with a token, not cancelled", spinner.Send<int>("ADD", new CancellationTokenSource().Token, 40, 2), 42);
        Throws<OperationCanceledException>("Send: already cancelled", () => spinner.Send("ADD", new CancellationToken(true), 1, 2));
        // already cancelled: nothing runs
        rexx.Local["RAN"] = "no";
        var done = new CancellationToken(true);
        Throws<OperationCanceledException>("already cancelled", () => rexx.Run(".local~ran = 'yes'", done));
        Ok("... nothing ran",            rexx.Local["RAN"], "no");
        // a token that is never cancelled
        Ok("not cancelled",              rexx.Run("use arg a; return a + 1", new CancellationTokenSource().Token, 41), "42");
        // Rexx code that traps HALT decides
        using (var cts = new CancellationTokenSource(200))
            Ok("HALT trapped: the result",
               rexx.Run("signal on halt; do forever; nop; end\nhalt: return 'cleaned up'", cts.Token), "cleaned up");
        // only the calling thread is halted
        using (var a = new CancellationTokenSource())
        using (var b = new CancellationTokenSource())
        {
            string ra = "", rb = "";
            var ta = new Thread(() => { try { rexx.Run("do forever; nop; end", a.Token); } catch (OperationCanceledException) { ra = "cancelled"; } });
            var tb = new Thread(() => { try { rexx.Run("do forever; nop; end", b.Token); } catch (OperationCanceledException) { rb = "cancelled"; } });
            ta.Start(); tb.Start(); Thread.Sleep(200);
            a.Cancel();
            bool aDone = ta.Join(5000);
            Thread.Sleep(200);
            Ok("one thread cancelled, the other running", $"{aDone} {ra} {tb.IsAlive} [{rb}]", "True cancelled True []");
            b.Cancel();
            Ok("... then the other",     tb.Join(5000) ? rb : "still running", "cancelled");
        }
        // a token cancelled after its call has returned halts nothing
        using (var cts = new CancellationTokenSource())
        {
            rexx.Run("return 1", cts.Token);
            var t = Task.Run(() => { Thread.Sleep(100); cts.Cancel(); });
            Ok("cancelled after the call: no effect", rexx.Run("call syssleep 0.3; return 'finished'"), "finished");
            t.Wait();
        }
        // RexxRoutine.Call and RunFile
        var loop = rexx.Compile("loop", "do forever; nop; end");
        using (var cts = new CancellationTokenSource(200))
            Throws<OperationCanceledException>("RexxRoutine.Call", () => loop.Call(cts.Token));
        var file = Path.Combine(Path.GetTempPath(), $"hosttests-loop-{Environment.ProcessId}.rex");
        File.WriteAllText(file, "do forever; nop; end\n");
        using (var cts = new CancellationTokenSource(200))
            Throws<OperationCanceledException>("RunFile", () => rexx.RunFile(file, cts.Token));
        File.Delete(file);
        // cancelled while the Rexx code is inside a command handler
        rexx.AddCommandEnvironment("SLOW", (c, ctx) => { Thread.Sleep(300); return null; });
        using (var cts = new CancellationTokenSource(100))
            Throws<OperationCanceledException>("cancelled during a command", () => rexx.Run("address slow 'x'; do forever; nop; end", cts.Token));
        // a compile error is a compile error
        using (var cts = new CancellationTokenSource())
        {
            try { rexx.Run("say 1 +", cts.Token); Ok("cancellable Run, compile error", "none", "35.1"); }
            catch (RexxException e) { Ok("cancellable Run, compile error", e.Code, "35.1"); }
        }
        // and the instance still works
        Ok("after cancellations",        rexx.Run("return 'fine'"), "fine");
    }
}
