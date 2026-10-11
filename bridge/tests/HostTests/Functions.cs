// .NET -> ooRexx: functions and VALUE selectors of the application
// (notes/rexx-from-net-design.md, "Application functions and values").
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Rexx.Net;

static partial class Program
{
    static double Hypot(double a, double b) => Math.Sqrt(a * a + b * b);

    static void Functions()
    {
        using var rexx = RexxInterpreter.Create();
        const string Trap = "\nsyntax: return condition('O')~code condition('O')~message";

        // a handler with the call
        rexx.AddFunction("appInfo", f => $"{f.Name} {f.Arguments.Count} {f.IsSubroutine} " +
                                         string.Join(",", f.Arguments.Select(a => a is RexxString s ? s.Value : a == RexxValue.Omitted ? "-" : a?.GetType().Name ?? "nil")));
        Ok("function: name, arguments",  rexx.Run("return appInfo(1, , 'x')"), "APPINFO 3 False 1,-,x");
        Ok("CALL: subroutine, RESULT",   rexx.Run("call appinfo 7; return result"), "APPINFO 1 True 7");
        Ok("a literal name keeps its case", rexx.Run("return 'appInfo'()"), "appInfo 0 False ");
        Ok("objects and .nil",           rexx.Run("return appInfo(.array~new, .nil)"), "APPINFO 2 False RexxObject,nil");
        rexx.AddFunction("twice", f => f.Arg<int>(0) * 2);
        Ok("Arg<T>",                     rexx.Run("return twice(21) + 1"), "43");
        rexx.AddFunction("caller", f => { f["SEEN"] = f["X"] + "!"; return f.HasVariable("NOPE"); });
        Ok("the caller's variables",     rexx.Run("x = 'hi'; r = caller(); return r seen"), "0 hi!");
        rexx.AddFunction("nested", f => f.Interpreter.Run("use arg a; return a * 7", f.Arguments[0]));
        Ok("a function calling Rexx",    rexx.Run("return nested(6)"), "42");
        rexx.AddFunction("net", f => new List<int> { 1, 2, 3 });
        Ok("a .NET object as result",    rexx.Run("return net()~Count"), "3");
        rexx.AddFunction("nothing", f => null);
        Ok("null: .nil",                 rexx.Run("return nothing() == .nil"), "1");
        rexx.AddFunction("quiet", (RexxFunctionCall f) => { });
        Ok("no result: CALL",            rexx.Run("call quiet; return var('RESULT')"), "0");
        Ok("no result as a function: 44", rexx.Run("signal on syntax; x = quiet(); return 'no'" + Trap), "44.1 No data returned from function \"QUIET\".");

        // typed delegates
        rexx.AddFunction("hypot", Hypot);
        Ok("a method, converted arguments", rexx.Run("return hypot(3, '4')"), "5");
        rexx.AddFunction("greet", (string who, string greeting = "hello") => $"{greeting}, {who}");
        Ok("a default value",            rexx.Run("return greet('Rony') '/' greet('JM', 'hola')"), "hello, Rony / hola, JM");
        Ok("an omitted argument: its default", rexx.Run("return greet('x', )"), "hello, x");
        rexx.AddFunction("sum", (int[] xs) => xs.Sum());
        Ok("an array parameter: one argument", rexx.Run("signal on syntax; return sum(1, 2)" + Trap), "40.4 Too many arguments in invocation of SUM; maximum expected is 1.");
        rexx.AddFunction("total", (string label, params int[] xs) => label + xs.Sum());
        Ok("params: the rest",           rexx.Run("return total('t=', 1, 2, 3) total('none')"), "t=6 none0");
        rexx.AddFunction("ctx", (RexxFunctionCall f, int n) => f.Name + n);
        Ok("a RexxFunctionCall parameter", rexx.Run("return ctx(5)"), "CTX5");
        rexx.AddFunction("log", (string s) => { lastLog = s; });
        Ok("a void delegate",            rexx.Run("call log 'x y'; return var('RESULT')") + " " + lastLog, "0 x y");
        Ok("too few arguments: 40.3",    rexx.Run("signal on syntax; return hypot(1)" + Trap), "40.3 Not enough arguments in invocation of HYPOT; minimum expected is 2.");
        Ok("too many: 40.4",             rexx.Run("signal on syntax; return hypot(1, 2, 3)" + Trap), "40.4 Too many arguments in invocation of HYPOT; maximum expected is 2.");
        Ok("a required one omitted: 40.5", rexx.Run("signal on syntax; return hypot(, 2)" + Trap), "40.5 Missing argument in invocation of HYPOT; argument 1 is required.");
        Ok("not a number: 40.900",       rexx.Run("signal on syntax; return hypot('a', 2)" + Trap), "40.900 HYPOT, argument 1: \"a\" is not a Rexx number.");

        // errors
        rexx.AddFunction("boom", (Func<RexxFunctionCall, object?>)(f => throw new InvalidOperationException("not ready")));
        Ok(".NET exception: 40.900",     rexx.Run("signal on syntax; return boom()" + Trap), "40.900 not ready.");
        try { rexx.Run("return boom()"); Ok("... untrapped: thrown", "none", "thrown"); }
        catch (RexxException e) { Ok("... untrapped: thrown", e.Code, "40.900"); }
        rexx.AddFunction("bad", f => f.Interpreter.Run("return 1 + 'a'"));
        Ok("Rexx error inside: itself",  rexx.Run("signal on syntax; return bad()" + Trap), "41.1 Nonnumeric value (\"a\") used in arithmetic operation.");

        // what wins
        Ok("an internal routine wins",   rexx.Run("return twice(1)\ntwice: return 'mine'"), "mine");
        Ok("a ::routine wins",           rexx.Run("return twice(1)\n::routine twice; return 'routine'"), "routine");
        Ok("a built-in wins",            rexx.Run("return length('abc')"), "3");
        rexx.AddFunction("length", f => "app");
        Ok("... even when added",        rexx.Run("return length('abc')"), "3");
        Ok("unknown names: as before",   rexx.Run("signal on syntax; return noSuchFunction()" + Trap), "43.1 Could not find routine \"NOSUCHFUNCTION\".");
        rexx.AddFunction("TWICE", f => "replaced");
        Ok("adding again replaces",      rexx.Run("return twice(1)"), "replaced");

        // from other threads
        rexx.AddFunction("sq", (int n) => n * n);
        var results = new int[4];
        Parallel.For(0, 4, i => { int s = 0; for (int k = 0; k < 50; k++) s += rexx.Run<int>("use arg n; return sq(n)", i); results[i] = s; });
        Ok("4 threads x 50 calls",       string.Join(",", results), "0,50,200,450");

        // cost, warm: an application function in a Rexx loop, against a ::routine
        const string Loop = "use arg n; t = time('R'); do i = 1 to n; x = sq(i); end; return time('E')";
        rexx.Run(Loop, 50000);
        double app = Enumerable.Range(0, 3).Min(_ => rexx.Run<double>(Loop, 50000)) / 50000 * 1e6;
        rexx.AddFunction("hypot", Hypot);
        double typed = Enumerable.Range(0, 3).Min(_ => rexx.Run<double>(Loop.Replace("sq(i)", "hypot(i, 1)"), 50000)) / 50000 * 1e6;
        double routine = Enumerable.Range(0, 3).Min(_ => rexx.Run<double>(Loop + "\n::routine sq; return arg(1) * arg(1)", 50000)) / 50000 * 1e6;
        Console.WriteLine($"     functions: an application function {app:F2} µs a call (typed, 2 args: {typed:F2}); a ::routine {routine:F2}");

        // VALUE selectors
        var settings = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase) { ["Color"] = "blue", ["Size"] = 12 };
        rexx.AddValueSelector("APP", n => settings.TryGetValue(n, out var v) ? v : null, (n, v) => settings[n] = v);
        Ok("VALUE(name, , 'APP')",       rexx.Run("return value('Color', , 'APP') value('size', , 'app')"), "blue 12");
        Ok("VALUE set: the old value",   rexx.Run("return value('Color', 'red', 'APP')") + " " + settings["Color"], "blue red");
        Ok("unknown name: .nil",         rexx.Run("return value('nope', , 'APP') == .nil"), "1");
        rexx.AddValueSelector("RO", n => n.ToUpperInvariant());
        Ok("a read-only selector",       rexx.Run("return value('abc', , 'RO')"), "ABC");
        Ok("... set: 40.900",            rexx.Run("signal on syntax; return value('abc', 1, 'RO')" + Trap), "40.900 VALUE: the selector RO cannot set abc.");
        Ok("ENVIRONMENT still ooRexx's", rexx.Run("return value('PATH', , 'ENVIRONMENT') \\== ''"), "1");
        Ok("unknown selector: as before", rexx.Run("signal on syntax; return value('x', , 'NOSUCH')" + Trap)?.ToString()?.Split(' ')[0], "40.914");

        rexx.Dispose();
        Throws<ObjectDisposedException>("AddFunction after Dispose", () => rexx.AddFunction("x", f => null));
    }

    static string? lastLog;
}
