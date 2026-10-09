// .NET -> ooRexx, phase C: both ways in one process (notes/rexx-from-net-design.md,
// "Phase C: built"). .NET objects to Rexx as .NetObjects and back; Rexx code
// calling this host's own .NET code (HostLib), which receives Rexx objects as
// RexxObjects, calls Rexx back nested (RexxInterpreter.Current) and lets
// Rexx errors through; the 98.900 round trip.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Rexx.Net;

/// This host's own code, called from its Rexx code (.net~type("HostLib")).
public static class HostLib
{
    public static RexxInterpreter? Host;
    public static Exception? LastThrown;

    public static object? Echo(object? o) => o;
    public static string ClassOf(RexxObject o) => o.Send("CLASS")!.Send<string>("ID");
    public static int Count(RexxObject o) => o.Send<int>("ITEMS");
    public static string Kind(object o) => "object:" + o.GetType().Name;
    public static string Kind(RexxObject o) => "RexxObject";
    public static string Str(RexxString s) => "[" + s.Value + "]";
    public static bool SameAsHost() => RexxInterpreter.Current == Host && Host != null;
    public static int Nested() => RexxInterpreter.Current!.Run<int>("return 6 * 7");
    public static RexxObject? CallBack(RexxObject o, string message) => o.Send(message);
    public static string Withdraw(RexxObject account, int n) => account.Send<string>("WITHDRAW", n);
    public static void Boom() { LastThrown = new InvalidOperationException("boom"); throw LastThrown; }
    public static RexxObject MakeDirectory() =>
        RexxInterpreter.Current!.NewDirectory(new[] { new KeyValuePair<string, object?>("A", 1), new("B", 2) });
    public static string Items(RexxObject o) { dynamic d = o; return (string)d.Items(); }
    public static int OnOtherThread(RexxObject o) => Task.Run(() => o.Send<int>("ITEMS")).Result;
    public static int Twice(RexxObject routine, int x) => ((RexxRoutine)routine).Call<int>(x) * 2;
    public static int Length(StringBuilder sb) => sb.Length;
    public static string Catches()
    {
        var r = RexxInterpreter.Current!;
        try { r.Run("raise syntax 40.1 array('f')"); return "no"; }
        catch (RexxException e) { return $"caught {e.Code}, then {r.Run<int>("return 3 + 4")}"; }
    }
    public static string Wrapped(RexxObject account) =>
        HostLibWrap(() => account.Send<string>("WITHDRAW", 1000));
    static string HostLibWrap(Func<string> f)
    {
        try { return f(); }
        catch (RexxException e) { throw new ApplicationException("wrapped: " + e.Message, e); }
    }
}

static partial class Program
{
    static void PhaseC()
    {
        using var rexx = RexxInterpreter.Create();
        HostLib.Host = rexx;
        NetToRexx(rexx);
        RexxCallsHost(rexx);
        // ooRexx bug #2106 (patches/oorexx/README.md): CallRoutine slow on the main thread.
        // On a thread of its own: on Linux, ooRexx's CallRoutine costs ~200 µs on a
        // process's main thread (Activity::run asks for the stack base each time,
        // and glibc reads /proc/self/maps for the main thread's), 5 µs elsewhere
        var costs = new System.Threading.Thread(() => { using (rexx.Enter()) BothWaysCosts(rexx); });
        costs.Start(); costs.Join();
        rexx.Dispose();
    }

    // .NET objects to Rexx (.NetObject, by reference) and back (themselves)
    static void NetToRexx(RexxInterpreter rexx)
    {
        var sb = new StringBuilder();
        Ok("C: Rexx uses a .NET object",   rexx.Run<int>("use arg sb; sb~Append('ab'); return sb~Length", sb), 2);
        Ok("C: by reference",               sb.ToString(), "ab");
        Ok("C: comes back as itself",       ReferenceEquals(rexx.Run<StringBuilder>("use arg o; return o", sb), sb), true);
        Ok("C: Run<object>",                ReferenceEquals(rexx.Run<object>("use arg o; return o", sb), sb), true);
        var proxy = rexx.Run("use arg o; return o", sb)!;
        Ok("C: Run gives a proxy",          proxy.GetType().Name, "RexxObject");
        Ok("C: NetValue",                   ReferenceEquals(proxy.NetValue, sb), true);
        Ok("C: other objects: no NetValue", rexx.Run("return .directory~new")!.NetValue == null, true);
        Ok("C: Rexx sees a NetObject",      rexx.Run<string>("use arg o; return o~class~id", sb), "NETOBJECT");
        Ok("C: .net is there",              rexx.Run<object>("return .net~System~Text~StringBuilder~new('x')") is StringBuilder { Length: 1 }, true);
        Ok("C: a type",                     rexx.Run<string>("use arg t; return t~Name", typeof(string)), "String");
        Ok("C: a type comes back",          ReferenceEquals(rexx.Run<object>("use arg t; return t", typeof(string)), typeof(string)), true);
        Ok("C: a NetType comes back as its Type", ReferenceEquals(rexx.Run<object>("return .net~System~Math"), typeof(Math)), true);
        Ok("C: List<int>, DO OVER",         rexx.Run<int>("use arg l; t = 0; do x over l; t += x; end; return t", new List<int> { 1, 2, 3 }), 6);
        var arr = new[] { 1, 2, 3 };
        rexx.Run("use arg a; a[1] = 9", arr);
        Ok("C: an array by reference",      arr[0], 9);
        Ok("C: an enum is a .NetEnum",      rexx.Run<string>("use arg d; return d~class~id d d~ordinal (d = 'monday')", DayOfWeek.Monday),
           "NETENUM Monday 1 1");
        Ok("C: an enum comes back as itself", rexx.Run<object>("use arg d; return d", DayOfWeek.Friday), DayOfWeek.Friday);
        Ok("C: an array is a .NetArray (from 1)",
           rexx.Run<string>("use arg a; return a~class~id a~items a~dimension a[3]", arr), "NETARRAY 3 1 3");
        Func<int, int> twice = x => x * 2;
        Ok("C: a delegate",                 rexx.Run<int>("use arg f; return f~Invoke(21)", twice), 42);
        Ok("C: same object, same identity", rexx.Run<bool>("use arg a, b; return a == b", sb, sb), true);
        rexx.Local["FORM"] = sb;
        Ok("C: Local[...] = a .NET object", rexx.Run<string>("return .form~ToString"), "ab");
        dynamic local = rexx.Local;
        Ok("C: dynamic gives the object",   ReferenceEquals((object)local["FORM"], sb), true);
        Ok("C: indexer gives the object",   ReferenceEquals(rexx.Local["FORM"], sb), true);
        dynamic d = rexx.Run("return .directory~new")!;
        d.SB = sb;                                                     // ~SB=(sb): a .NetObject
        Ok("C: dynamic member result",      ReferenceEquals((object)d.SB, sb), true);
        object? seen = null;
        rexx.AddCommandEnvironment("NETVAR", cmd => { seen = cmd["SB"]; return null; });
        rexx.Run("use arg sb; address netvar 'look'", sb);
        Ok("C: a command's variable",       ReferenceEquals(seen, sb), true);
        var items = (RexxObject)rexx.Run("use arg o; return .array~of(o, 'x')", sb)!;
        Ok("C: foreach gives the object",   ReferenceEquals(items.First(), sb), true);
        Ok("C: Send<T> gives the object",   ReferenceEquals(items.Send<StringBuilder>("AT", 1), sb), true);
        Ok("C: a .NET error in Rexx",       rexx.Run<string>("use arg sb; signal on syntax; sb~Insert(99, 'x'); return 'no'; " +
                                                             "syntax: return condition('O')~code", sb), "98.900");
    }

    // Rexx code calling this host's .NET code: Rexx objects, nesting, errors
    static void RexxCallsHost(RexxInterpreter rexx)
    {
        const string H = ".net~type('HostLib')";
        Ok("C: a RexxObject parameter",     rexx.Run<string>($"return {H}~ClassOf(.directory~new)"), "Directory");
        Ok("C: its messages",               rexx.Run<int>($"d = .directory~new; d~a = 1; d~b = 2; return {H}~Count(d)"), 2);
        Ok("C: RexxObject before object",   rexx.Run<string>($"return {H}~Kind(.directory~new)"), "RexxObject");
        Ok("C: a string still a string",    rexx.Run<string>($"return {H}~Kind('x')"), "object:String");
        Ok("C: a RexxString parameter",     rexx.Run<string>($"return {H}~Str('abc')"), "[abc]");
        Ok("C: back as itself",             rexx.Run<bool>($"d = .directory~new; return {H}~Echo(d) == d"), true);
        Ok("C: a routine",                  rexx.Run<int>($"r = .routine~new('r', 'return arg(1) + 1'); return {H}~Twice(r, 20)"), 42);
        Ok("C: RexxInterpreter.Current",    rexx.Run<bool>($"return {H}~SameAsHost"), true);
        Ok("C: no Current outside Rexx",    RexxInterpreter.Current == null, true);
        Ok("C: nested call into Rexx",      rexx.Run<int>($"return {H}~Nested"), 42);
        Ok("C: a Rexx object made by .NET", rexx.Run<int>($"d = {H}~MakeDirectory; return d~a + d~b"), 3);
        Ok("C: a Rexx object from a call",  rexx.Run<string>($"d = .directory~new; d~x = 5; c = {H}~CallBack(d, 'COPY'); return c~x (c == d)"), "5 0");
        Ok("C: dynamic in .NET",            rexx.Run<int>($"d = .directory~new; d~a = 1; return {H}~Items(d)"), 1);
        Ok("C: from another .NET thread",   rexx.Run<int>($"d = .directory~new; d~a = 1; d~b = 1; return {H}~OnOtherThread(d)"), 2);
        Ok("C: a NetObject parameter",      rexx.Run<int>($"use arg sb; return {H}~Length(sb)", new StringBuilder("xyz")), 3);

        // a Rexx error in Rexx code that .NET called comes back to Rexx as it was
        var account = FindAccount(rexx).New(10)!;
        Ok("C: Rexx error raised again",    rexx.Run<string>($"use arg a; signal on syntax; {H}~Withdraw(a, 100); return 'no'; " +
                                                             "syntax: return condition('O')~code condition('O')~message", account),
                                            "88.900 insufficient funds: 10.");
        try { rexx.Run($"use arg a; {H}~Withdraw(a, 100)", account); Ok("C: untrapped, to the host", "no exception", "88.900"); }
        catch (RexxException e) { Ok("C: untrapped, to the host", e.Code + " " + e.Message, "88.900 insufficient funds: 10."); }
        Ok("C: through a wrapping exception", rexx.Run<string>($"use arg a; signal on syntax; {H}~Wrapped(a); return 'no'; " +
                                                               "syntax: return condition('O')~code condition('O')~message", account),
                                              "88.900 insufficient funds: 10.");
        Ok("C: .NET catches a nested error", rexx.Run<string>($"signal on syntax; r = {H}~Catches; return r; syntax: return 'error'"),
                                             "caught 40.1, then 7");

        // 98.900 round trip: a .NET exception thrown under Rexx code, back in .NET
        try { rexx.Run($"{H}~Boom"); Ok("C: 98.900 to the host", "no exception", "98.900"); }
        catch (RexxException e)
        {
            Ok("C: 98.900 to the host",     e.Code, "98.900");
            Ok("C: InnerException",         ReferenceEquals(e.InnerException, HostLib.LastThrown) && HostLib.LastThrown != null, true);
        }
        try { rexx.Run("return .net~System~Int32~Parse('x')"); }
        catch (RexxException e) { Ok("C: InnerException's type", e.InnerException?.GetType().Name, "FormatException"); }
    }

    static RexxClass FindAccount(RexxInterpreter rexx) =>
        rexx.LoadPackage("account-c.cls", Account).FindClass("Account")!;

    // costs: no growth over many calls each way (local references, handles)
    static void BothWaysCosts(RexxInterpreter rexx)
    {
        var sb = new StringBuilder("x");
        var pass = rexx.Compile("pass", "use arg o; return o");
        var call = rexx.Compile("call", "use arg d; return .net~type('HostLib')~Echo(d)");
        var dir = rexx.Run("return .directory~new")!;
        double Rate(Action a, int n)                        // the best of three samples: a GC pause in one is noise, not growth
        {
            double best = double.MaxValue;
            for (int k = 0; k < 3; k++)
            {
                var w = Stopwatch.StartNew();
                for (int i = 0; i < n; i++) a();
                best = Math.Min(best, w.Elapsed.TotalMilliseconds * 1000 / n);
            }
            return best;
        }
        for (int i = 0; i < 200; i++) { pass.Call(sb); call.Call(dir); }
        double p1 = Rate(() => pass.Call<object>(sb), 2000), c1 = Rate(() => call.Call(dir), 2000);
        for (int i = 0; i < 20000; i++) { pass.Call<object>(sb); call.Call(dir); }
        double p2 = Rate(() => pass.Call<object>(sb), 2000), c2 = Rate(() => call.Call(dir), 2000);
        Console.WriteLine($"     phase C: a .NET object to Rexx and back {p1:F1} -> {p2:F1} µs; " +
                          $"Rexx object to a .NET method and back {c1:F1} -> {c2:F1} µs; handles {Handles.Count}");
        Ok("C: no growth, .NET objects",    p2 < 4 * p1 + 5, true);
        Ok("C: no growth, Rexx objects",    c2 < 4 * c1 + 5, true);
    }
}
