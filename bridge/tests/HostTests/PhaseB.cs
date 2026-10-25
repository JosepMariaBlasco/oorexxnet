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
    static string Execute(string command) => "ran " + command;     // a handler taking a plain string

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
    }

    // Rexx -> the host (a command handler, a function) -> Rexx code that
    // RAISEs USER, with no Rexx activation of the bridge in between, and
    // SIGNAL ON USER in the caller. On ooRexx r13275 the condition is lost
    // where the API runs Rexx code (oorexx-bridges, oorexx-bugs/2026-10-19-api-
    // calls-drop-non-syntax-conditions.md): the caller's trap never fires, so
    // no C++ unwinding crosses .NET's frames. Should ooRexx deliver it one
    // day, a SIGNAL would unwind through them: this test then fails (or the
    // process ends) and the path needs a guard.
    static void SignalPastTheHost()
    {
        using var rexx = RexxInterpreter.Create();
        rexx.AddCommandEnvironment("RAISING", cmd => cmd.Interpreter.Run("raise user x description 'd' return 7"));
        rexx.AddFunction("RAISING", call => call.Interpreter.Run("raise user x description 'd' return 7"));
        Ok("SIGNAL ON past the host: a command (ooRexx drops it)",
           rexx.Run("signal on user x; address raising 'go'; return 'not trapped, rc' rc\nx: return 'trapped'"), "not trapped, rc 7");
        Ok("... a function (ooRexx drops it)",
           rexx.Run("signal on user x; v = raising(); return 'not trapped:' v\nx: return 'trapped'"), "not trapped: 7");
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
        rexx.AddCommandEnvironment("HALTING", cmd => cmd.Interpreter.Run("raise halt"));
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
        rexx.AddCommandEnvironment("F", cmd => throw new RexxCommandException(9, "could not", failure: true));
        rexx.AddCommandEnvironment("E", cmd => throw new RexxCommandException(4, "it failed"));
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
            for (int e = 1; e <= envs; e++) rexx.AddCommandEnvironment("E" + e, cmd => 7);
            // a new name each time (adding a name again only replaces the handler
            // here, ooRexx's table does not change), until the threads end
            var sw = System.Diagnostics.Stopwatch.StartNew();
            for (int k = 0; !work.All(t => t.IsCompleted) && sw.ElapsedMilliseconds < 60000; k++)
                rexx.AddCommandEnvironment($"X{round}_{k}", cmd => 7);
            done = Task.WaitAll(work, 60000);
            if (done) hits += work.Sum(t => t.Result);
        }
        Ok("environments added while 4 threads run Rexx (ooRexx #2111, #2112)", done && hits > 0, true);
    }

    static void Commands(RexxInterpreter rexx, StringWriter err)
    {
        string? lastAddress = null, lastCommand = null;
        rexx.AddCommandEnvironment("APP", cmd =>
        {
            lastAddress = cmd.Address; lastCommand = cmd.Command;
            string c = cmd.Command;
            if (c == "null") return null;
            if (c.StartsWith("error ")) throw new RexxCommandException(int.Parse(c[6..]));
            if (c.StartsWith("failure ")) throw new RexxCommandException(int.Parse(c[8..]), "it could not run", failure: true);
            if (c == "throw") throw new InvalidOperationException("the application is not ready");
            if (c == "nested") return cmd.Interpreter.Run("use arg a; return a * 7", 6);
            if (c == "nested error") return cmd.Interpreter.Run("return 1 + 'a'");
            if (c == "object") return rexx.NewArray("a", "b");
            return c.Length;
        });
        Ok("command: RC",                rexx.Run("address app 'open the door'; return rc"), "13");
        Ok("... address, command",       $"{lastAddress}|{lastCommand}", "APP|open the door");
        Ok("ADDRESS app, then a command", rexx.Run("address app; 'hello'; return rc"), "5");
        Ok("ADDRESS 'app' (case)",       rexx.Run("address 'app' 'x'; return rc") + " " + lastAddress, "1 app");
        Ok("null result: RC 0",          rexx.Run("address app 'null'; return rc"), "0");
        Ok("an object as RC",            rexx.Run("address app 'object'; return rc~class~id rc~items"), "Array 2");
        Ok("ERROR, trapped",             rexx.Run("signal on error; address app 'error 5'; return 'no'\n" +
                                                   "error: return condition('C') rc condition('D')"), "ERROR 5 error 5");
        Ok("ERROR, untrapped: RC",       rexx.Run("address app 'error 7'; return rc"), "7");
        Ok("FAILURE, trapped",           rexx.Run("signal on failure; address app 'failure 9'; return 'no'\n" +
                                                   "failure: return condition('C') rc condition('A')"), "FAILURE 9 it could not run");
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

        // a plain-string handler, an Action, replacing one, two instances
        rexx.AddCommandEnvironment("PLAIN", cmd => Execute(cmd));
        Ok("handler taking a string",    rexx.Run("address plain 'x'; return rc"), "ran x");
        int seen = 0;
        rexx.AddCommandEnvironment("LOG", (RexxCommand cmd) => { seen++; });
        Ok("Action: RC 0",               rexx.Run("address log 'a'; address log 'b'; return rc") + " " + seen, "0 2");
        // as ooRexx's .CommandHandler~register / ~deregister: stacked, uncovered
        var coveredPlain = rexx.AddCommandEnvironment("PLAIN", cmd => "stacked");
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
        rexx.AddCommandEnvironment("PLAIN", cmd => "back");
        Ok("... added again",            rexx.Run("address plain 'x'; return rc"), "back");
        rexx.Run(".CommandHandler~deregister('PLAIN')");
        rexx.AddCommandEnvironment("PLAIN", cmd => "back");
        Ok("... added again after .CommandHandler~deregister", rexx.Run("address plain 'x'; return rc"), "back");
        var keptOutput = rexx.Output;
        rexx.Output = new StringWriter();                 // the I/O forwarders installed
        Ok("the bridge's own entries are not among the environments",
           rexx.Run("return .CommandHandler~environments~allIndexes~makeString('l', ' ')~pos('REXXNET')"), "0");
        rexx.Output = keptOutput;
        Throws<ArgumentNullException>("a null handler", () => rexx.AddCommandEnvironment("NULL", (Func<RexxCommand, object?>)null!));
        using (var other = RexxInterpreter.Create())
        {
            other.AddCommandEnvironment("APP", cmd => "other");
            Ok("two instances, one name", other.Run("address app 'x'; return rc") + " " + rexx.Run("address app 'x'; return rc"), "other 1");
            other.Dispose();
        }

        // variables of the Rexx code
        RexxCommand? kept = null;
        rexx.AddCommandEnvironment("VARS", cmd =>
        {
            kept = cmd;
            switch (cmd.Command)
            {
                case "get": return $"{cmd["x"]} {cmd["S.1"]} {cmd["s.2"]} {cmd["nope"] == null} {cmd.HasVariable("x")} {cmd.HasVariable("nope")}";
                case "set": cmd["y"] = 5; cmd["T.1"] = "one"; cmd["N"] = null; cmd.Drop("z"); return null;
                case "all": return string.Join(",", cmd.Variables.Keys.Where(k => k.Length == 1).OrderBy(k => k));
                case "object": return cmd["A"] is RexxObject a && a.Send<int>("items") == 3;
            }
            return null;
        });
        Ok("variables: get",             rexx.Run("x = 'ex'; s.1 = 'one'; s.2 = 'two'; address vars 'get'; return rc"), "ex one two True True False");
        Ok("variables: set, drop",       rexx.Run("z = 1; address vars 'set'; return y t.1 (n == .nil) symbol('Z')"), "5 one 1 LIT");
        Ok("variables: all",             rexx.Run("a = 1; b = 2; address vars 'all'; return rc"), "A,B");
        Ok("variables: an object",       rexx.Run("a = .array~of(1, 2, 3); address vars 'object'; return rc"), "1");
        Throws<InvalidOperationException>("RexxCommand after its handler", () => _ = kept!["x"], "only while its handler runs");

        // ADDRESS ... WITH
        rexx.AddCommandEnvironment("SORT", cmd =>
        {
            if (!cmd.IsRedirected)
                return (cmd.WriteLine("to the console") ? "redirected" : "not redirected") + (cmd.WriteErrorLine("an error") ? "!" : "");
            var lines = new List<string>();
            for (string? l; (l = cmd.ReadLine()) != null;) lines.Add(l);
            lines.Sort(StringComparer.Ordinal);
            foreach (var l in lines) cmd.WriteLine(l);
            cmd.WriteErrorLine($"{lines.Count} lines");
            return lines.Count;
        });
        Ok("ADDRESS ... WITH",           rexx.Run("i.1 = 'pear'; i.2 = 'apple'; i.3 = 'fig'; i.0 = 3\n" +
                                                   "address sort 'sort' with input stem i. output stem o. error stem e.\n" +
                                                   "return rc o.0 o.1 o.2 o.3 '/' e.1"), "3 3 apple fig pear / 3 lines");
        Ok("... into an Array",          rexx.Run("out = .array~new; address sort 'sort' with input using (.array~of('b', 'a')) output using (out)\n" +
                                                   "return out~makeString('l', ',')"), "a,b");
        var (console, consoleErr) = (Console.Out, Console.Error);
        var (cout, cerr) = (new StringWriter(), new StringWriter());
        Console.SetOut(cout); Console.SetError(cerr);
        string notRedirected;
        try { notRedirected = rexx.Run("address sort 'x'; return rc")!.ToString()!; }
        finally { Console.SetOut(console); Console.SetError(consoleErr); }
        Ok("... not redirected: to the console", $"{notRedirected}|{cout.ToString().Trim()}|{cerr.ToString().Trim()}",
                                         "not redirected|to the console|an error");
        rexx.AddCommandEnvironment("CAT", cmd => { cmd.Write(cmd.ReadToEnd() + "\nend"); return null; });
        Ok("ReadToEnd, Write (lines)",   rexx.Run("o = .array~new; address cat 'cat' with input using (.array~of('x', 'y')) output using (o)\n" +
                                                   "return o~makeString('l', ',')"), "x,y,end");

        // commands from other threads; a handler's own calls stay on its thread
        int handlerThread = 0, nestedThread = 0;
        rexx.AddCommandEnvironment("WHERE", cmd =>
        {
            handlerThread = Environment.CurrentManagedThreadId;
            cmd.Interpreter.Run("return 1");
            nestedThread = Environment.CurrentManagedThreadId;
            return Environment.CurrentManagedThreadId;
        });
        int caller = 0;
        string rc = Task.Run(() => { caller = Environment.CurrentManagedThreadId; return rexx.Run("address where 'x'; return rc")!.ToString(); }).Result;
        Ok("a command from another .NET thread", rc == caller.ToString() && handlerThread == caller && nestedThread == caller, true);
        var counts = new int[4];
        rexx.AddCommandEnvironment("COUNT", cmd => { Interlocked.Increment(ref counts[int.Parse(cmd.Command)]); return null; });
        Parallel.For(0, 4, i => rexx.Run("use arg i; do 100; address count i; end", i));
        Ok("4 threads, 100 commands each", string.Join(",", counts), "100,100,100,100");

        // the cost of a command
        rexx.AddCommandEnvironment("NOP", cmd => null);
        var sw = System.Diagnostics.Stopwatch.StartNew();
        rexx.Run("do 20000; address nop 'x'; end");
        double us = sw.Elapsed.TotalMilliseconds * 1000 / 20000;
        if (Environment.GetEnvironmentVariable("HOSTTESTS_RATES") != null) Console.WriteLine($"     a command: {us:F2} µs");
        Ok("a command costs little",     us < 50, true);
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
        rexx.AddCommandEnvironment("SLOW", cmd => { Thread.Sleep(300); return null; });
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
