// Phase C test types (tests/bothways.rex): .NET code called by Rexx code run
// by ooRexx itself (rexx bothways.rex), i.e. guest mode: the instance is
// ooRexx's, reached through RexxInterpreter.Current.
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Rexx.Net;

namespace RexxNetTests;

public static class BothWays
{
    static RexxInterpreter? first;
    static RexxObject? kept;

    public static bool IsGuest() => RexxInterpreter.Current?.IsGuest == true;
    public static bool SameInstance()
    {
        first ??= RexxInterpreter.Current;
        return first != null && ReferenceEquals(first, RexxInterpreter.Current);
    }
    public static int Nested() => RexxInterpreter.Current!.Run<int>("return 6 * 7");
    public static string ClassOf(RexxObject o) => o.Send("CLASS")!.Send<string>("ID");
    public static object? Echo(object? o) => o;
    // A StringTable to a dictionary (a copy)
    public static string Ints(Dictionary<string, int> d) => string.Join(",", d.OrderBy(p => p.Key, StringComparer.Ordinal).Select(p => $"{p.Key}={p.Value + 1}"));
    public static string Strings(IReadOnlyDictionary<string, string> d) => string.Join(",", d.OrderBy(p => p.Key, StringComparer.Ordinal).Select(p => $"{p.Key}={p.Value}"));
    public static string Objects(IDictionary<string, object?> d) => string.Join(",", d.OrderBy(p => p.Key, StringComparer.Ordinal).Select(p => $"{p.Key}:{p.Value?.GetType().Name ?? "null"}"));
    public static string NonGeneric(IDictionary d) => $"{d.Count} {d["k"]}";
    public static int Grow(Dictionary<string, int> d) { d["new"] = 1; return d.Count; }
    public static StringBuilder Builder(Dictionary<string, StringBuilder> d) => d["sb"];
    public static string Which(RexxObject o) => "reference";
    public static string Which(Dictionary<string, int> d) => "copy";
    public static string Cases(Dictionary<string, int> d) => string.Join(",", d.Keys.OrderBy(k => k, StringComparer.Ordinal));
    public static int LengthInRexx(string s) =>
        RexxInterpreter.Current!.Run<int>("use arg sb; return sb~Length", new StringBuilder(s));
    public static string BackFromRexx() =>
        RexxInterpreter.Current!.Run<object>("return .net~System~Text~StringBuilder~new('abc')") is StringBuilder sb ? sb.ToString() : "not one";
    public static string Withdraw(RexxObject account, int n) => account.Send<string>("WITHDRAW", n);
    public static string Catches()
    {
        var r = RexxInterpreter.Current!;
        try { r.Run("raise syntax 40.1 array('f')"); return "no"; }
        catch (RexxException e) { return $"caught {e.Code}, then {r.Run<int>("return 3 + 4")}"; }
    }
    public static int DisposeDoesNothing()
    {
        var r = RexxInterpreter.Current!;
        r.Dispose();
        return r.Run<int>("return 1");
    }
    public static int FromAnotherThread(RexxObject o) => Task.Run(() => o.Send<int>("ITEMS")).Result;
    public static void Keep(RexxObject o) => kept = o;
    public static int UseKept() => kept!.Send<int>("ITEMS");
    public static int UseKeptElsewhere() => Task.Run(() => kept!.Send<int>("ITEMS")).Result;
    // a handler's result that is a Rexx object (G: its reference handed over)
    public static string HandlerGives(Func<object?> f) => f() is RexxObject r ? ClassOf(r) + " " + r.Send<string>("X") : "not a RexxObject";
    public static string HandlerGivesElsewhere(Func<object?> f) =>
        Task.Run(() => f() is RexxObject r ? ClassOf(r) + " " + r.Send<string>("X") : "not a RexxObject").Result;
    public static void Boom() => throw new InvalidOperationException("boom");
    public static string CatchesBoom()
    {
        try { RexxInterpreter.Current!.Run(".net~RexxNetTests~BothWays~Boom"); return "no"; }
        catch (RexxException e) { return e.Code + " " + e.InnerException?.GetType().Name + " " + e.InnerException?.Message; }
    }
    public static string Command()
    {
        string? got = null;
        var r = RexxInterpreter.Current!;
        r.AddCommandEnvironment("BOTHWAYS", cmd => { got = cmd.Command; return 7; });
        return r.Run<string>("address bothways 'hello'; return rc") + " " + got;
    }
}
