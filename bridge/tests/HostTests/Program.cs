// .NET -> ooRexx, phases A and B: tests (notes/rexx-from-net-design.md). A .NET
// application hosting ooRexx through Rexx.Net, no native code of ours.
// Run by tests/run.sh (dotnet HostTests.dll); prints FAIL lines and a total.
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Rexx.Net;

static partial class Program
{
    static int count, fails;

    static void Ok(string name, object? got, object? want)
    {
        count++;
        if (Equals(got?.ToString(), want?.ToString())) return;
        fails++;
        Console.WriteLine($"FAIL {name}: got [{got}], want [{want}]");
    }

    static void Throws<E>(string name, Action a, string fragment = "") where E : Exception
    {
        count++;
        try { a(); fails++; Console.WriteLine($"FAIL {name}: no exception"); }
        catch (E e) when (e.Message.Contains(fragment)) { }
        catch (Exception e) { fails++; Console.WriteLine($"FAIL {name}: {e.GetType().Name}: {e.Message}"); }
    }

    const string Account =
        "::class Account public\n" +
        "::attribute balance get\n" +
        "::method init; expose balance; use arg balance = 0\n" +
        "::method deposit; expose balance; use arg n; balance += n; return balance\n" +
        "::method withdraw; expose balance; use arg n\n" +
        "  if n > balance then raise syntax 88.900 array('insufficient funds:' balance)\n" +
        "  balance -= n; return balance\n" +
        "::method bump unguarded; expose balance; guard on; balance += 1\n" +
        "::routine twice public; use arg x; return 2 * x\n" +
        "::routine hidden; return 'hidden'\n";

    static int Main()
    {
        using var rexx = RexxInterpreter.Create();
        Ok("version", rexx.Version.StartsWith("5."), true);
        Ok("language level", rexx.LanguageLevel.Length > 0, true);

        // Run: a routine from source
        Ok("Run",                    rexx.Run("use arg a, b; return a + b", 2, 40), "42");
        Ok("Run gives a RexxString", rexx.Run("return 'x'") is RexxString, true);
        Ok("Run<int>",               rexx.Run<int>("use arg a, b; return a + b", 2, 40), 42);
        Ok("Run<double>",            rexx.Run<double>("return 1 / 4"), 0.25);
        Ok("Run<int> ' 1E3 '",       rexx.Run<int>("return ' 1E3 '"), 1000);
        Ok("Run<int> '- 7'",         rexx.Run<int>("return '- 7'"), -7);
        Ok("Run<bool>",              rexx.Run<bool>("return 1 = 1"), true);
        Ok("Run<long> 20 digits",    rexx.Run<decimal>("numeric digits 30; return 2 ** 70"), 1180591620717411303424m);
        Throws<InvalidCastException>("not whole",  () => rexx.Run<int>("return 1.5"), "not a whole number");
        Throws<InvalidCastException>("too large",  () => rexx.Run<byte>("return 300"), "does not fit");
        Throws<InvalidCastException>("not logical", () => rexx.Run<bool>("return 'yes'"), "not a Rexx logical value");
        Throws<InvalidCastException>("not a number", () => rexx.Run<int>("return 'abc'"), "not a Rexx number");
        Ok(".nil -> null",           rexx.Run("return .nil") == null, true);
        Ok("no result -> null",      rexx.Run("return") == null, true);
        Ok("bool, double, decimal, char args", rexx.Run("use arg a, b, c, d; return a b c d", true, 0.1, 2.50m, 'x'), "1 0.1 2.50 x");
        Ok("null arg -> .nil",       rexx.Run("use arg a; return a == .nil", (object?)null), "1");
        Ok("omitted",                rexx.Run("return arg() arg(2, 'O') arg(3)", 1, RexxValue.Omitted, 3), "3 1 3");

        // packages, classes, dynamic
        var pkg = rexx.LoadPackage("account.cls", Account);
        Ok("package name",           pkg.Name, "account.cls");
        Ok("public classes",         string.Join(",", pkg.PublicClasses.Keys), "ACCOUNT");
        Ok("routines",               string.Join(",", pkg.Routines.Keys.OrderBy(k => k)), "HIDDEN,TWICE");
        Ok("public routines",        string.Join(",", pkg.PublicRoutines.Keys), "TWICE");
        var cls = pkg.FindClass("Account")!;
        Ok("class name",             cls.Name, "ACCOUNT");
        Ok("FindClass (environment)", rexx.FindClass("Array")!.Name, "Array");
        Ok("FindClass none",         rexx.FindClass("NoSuchClass") == null, true);
        dynamic acct = cls.New(100)!;
        acct.Deposit(50);
        int balance = acct.Balance;
        Ok("dynamic: method, attribute, int", balance, 150);
        Ok("Send<int>",              ((RexxObject)acct).Send<int>("balance"), 150);
        Ok("Is, HasMethod",          $"{((RexxObject)acct).Is(cls)} {((RexxObject)acct).HasMethod("deposit")} {((RexxObject)acct).HasMethod("nope")}", "True True False");
        dynamic bal = acct.Balance;
        Ok("Rexx operators",         $"{bal + 1} {bal * 2} {bal / 4} {bal % 4} {-bal}", "151 300 37.5 2 -150");
        Ok("comparison, if",         (bal > 100) ? "big" : "small", "big");
        Ok("comparison, false",      (bal < 100) ? "small" : "not small", "not small");
        string text = acct.Balance;
        Ok("dynamic to string",      text, "150");
        Ok("explicit (int)",         (int)(RexxString)((RexxObject)acct).Send("balance")!, 150);
        Ok("Convert.ToInt32",        Convert.ToInt32(((RexxObject)acct).Send("balance")), 150);
        var twice = (RexxRoutine)pkg.Routines["TWICE"]!;
        Ok("routine Call",           twice.Call(21), "42");
        dynamic dtwice = twice;
        Ok("routine, dynamic invoke", dtwice(5), "10");
        Throws<NotSupportedException>("named arguments", () => acct.Deposit(n: 1), "named arguments");

        // errors
        try { acct.Withdraw(1000); Ok("RexxException", "none", "thrown"); }
        catch (RexxException e)
        {
            Ok("RexxException code, rc, line", $"{e.Code} {e.Rc} {e.Line} {e.ConditionName}", "88.900 88 6 SYNTAX");
            Ok("... message",        e.Message, "insufficient funds: 150.");
            Ok("... program",        e.Program, "account.cls");
            Ok("... traceback",      e.Traceback.Contains("raise syntax 88.900"), true);
            dynamic cond = e.Condition!;
            Ok("... condition object", cond["CODE"], "88.900");
        }
        try { rexx.Run("say 1 +"); Ok("compile error", "none", "thrown"); }
        catch (RexxException e) { Ok("compile error", e.Code, "35.1"); }
        try { rexx.Run("return 1 + 'a'"); Ok("41.1", "none", "thrown"); }
        catch (RexxException e) { Ok("41.1", e.Code + " " + e.Message.Contains("\"a\""), "41.1 True"); }
        try { rexx.Run("x = .nil~nosuch"); Ok("97.1", "none", "thrown"); }
        catch (RexxException e) { Ok("97.1 (no method)", e.Code, "97.1"); }

        // identity and collections
        var o1 = rexx.Run("use arg a; return a", (RexxObject)acct);
        Ok("same proxy",             ReferenceEquals(o1, (RexxObject)acct), true);
        rexx.Local["ACCT"] = (RexxObject)acct;                   // .acct: an environment symbol looks up "ACCT"
        Ok("Local[] =, .acct",       rexx.Run(".acct~deposit(1); return .acct~balance"), "151");
        Ok("Local[]",                ReferenceEquals(rexx.Local["ACCT"], (RexxObject)acct), true);
        Ok("Environment",            rexx.Environment["ARRAY"] is RexxClass, true);
        var arr = rexx.NewArray("a", "b", 3);
        Ok("NewArray, [1]",          arr[1], "a");
        arr[4] = "dd";
        Ok("[]=, items",             arr.Send<int>("items"), 4);
        Ok("foreach",                string.Join(",", arr.Select(x => x?.ToString())), "a,b,3,dd");
        dynamic darr = arr;
        Ok("dynamic [2]",            darr[2], "b");
        var dir = rexx.NewDirectory(new Dictionary<string, object?> { ["ONE"] = 1, ["TWO"] = "two" });
        Ok("NewDirectory",           dir["TWO"], "two");
        Ok("Supplier",               string.Join(",", dir.Supplier().Select(p => $"{p.Key}={p.Value}").OrderBy(s => s)), "ONE=1,TWO=two");
        var st = rexx.NewStringTable(new Dictionary<string, object?> { ["k"] = "v" });
        Ok("NewStringTable",         st["k"], "v");
        var key = rexx.Run("return 'k'")!;
        var map = new Dictionary<RexxString, int> { [(RexxString)key] = 1 };
        Ok("RexxString as a key",    map.ContainsKey(new RexxString("k")), true);
        Ok("RexxString == string",   ((RexxString)key).Equals("k"), true);

        // RunFile
        var file = Path.Combine(Path.GetTempPath(), $"hosttests-{Environment.ProcessId}.rex");
        File.WriteAllText(file, "use arg who\nreturn 'hello,' who\n");
        Ok("RunFile",                rexx.RunFile(file, "world"), "hello, world");
        File.Delete(file);
        Throws<RexxException>("RunFile, no file", () => rexx.RunFile("/no/such/file.rex"));

        // threads: attached per call, Enter for a batch, 4 at once
        var r0 = (RexxObject)acct;
        int start = r0.Send<int>("balance");
        Parallel.For(0, 4, new ParallelOptions { MaxDegreeOfParallelism = 4 }, _ =>
        {
            for (int i = 0; i < 250; i++) r0.Send("bump");
        });
        Ok("4 threads, attached per call", r0.Send<int>("balance") - start, 1000);
        string inside = "";
        var t = new Thread(() =>
        {
            using (rexx.Enter())
                for (int i = 0; i < 100; i++) r0.Send("bump");
            inside = r0.Send<string>("balance");
        });
        t.Start(); t.Join();
        Ok("Enter (a batch)",        int.Parse(inside) - start, 1100);
        Throws<InvalidOperationException>("Dispose on another thread", () =>
        {
            Exception? err = null;
            var x = new Thread(() => { try { rexx.Dispose(); } catch (Exception e) { err = e; } });
            x.Start(); x.Join();
            if (err != null) throw err;
        }, "on the thread that created it");

        // halt
        string halted = "not halted";
        var looping = new Thread(() =>
        {
            try { rexx.Run("do forever; nop; end"); }
            catch (RexxException e) { halted = e.Code; }        // an untrapped HALT ends as Error 4.1
        });
        looping.Start(); Thread.Sleep(300); rexx.Halt();
        Ok("Halt",                   looping.Join(5000) ? halted : "still running", "4.1");

        // lifetime: proxies released by Dispose and by the finalizer
        int before = rexx.ObjectCount;
        for (int i = 0; i < 2000; i++) using (cls.New(i)!) { }
        Ok("Dispose releases",       rexx.ObjectCount - before, 0);
        MakeGarbage(cls, 2000);
        GC.Collect(); GC.WaitForPendingFinalizers(); GC.Collect();
        rexx.Run("return 1");                                     // the queued releases go with a call
        Ok("finalizer releases",     rexx.ObjectCount - before <= 1, true);
        // local references: none left behind on the creating thread's long-lived
        // context (each one left makes every later release slower: a leak
        // showed as a call going from 2 to 800 µs over 100 000 calls). On a
        // fresh instance, created on its own thread (it shows there).
        var leakThread = new Thread(LeakChecks);
        leakThread.Start(); leakThread.Join();
        var dead = cls.New(1)!;
        dead.Dispose();
        Throws<ObjectDisposedException>("disposed object", () => dead.Send("balance"));

        // phase B: commands, I/O, cancellation (PhaseB.cs), on an instance of its own
        PhaseB();
        // phase C: both ways in one process (PhaseC.cs)
        PhaseC();
        // phase D: .net from the start (PhaseD.cs)
        PhaseD(rexx);

        rexx.Dispose();
        Throws<ObjectDisposedException>("disposed interpreter", () => rexx.Run("return 1"));

        Console.WriteLine(fails == 0 ? $"host (.NET -> ooRexx): all {count} tests passed"
                                     : $"host (.NET -> ooRexx): {fails} of {count} tests FAILED");
        return fails == 0 ? 0 : 1;
    }

    static void LeakChecks()
    {
        using var r = RexxInterpreter.Create();
        var same = r.LoadPackage("same.cls", "::class Same public\n::method same; use arg x; return x\n" +
                                              "::method fail; raise syntax 98.900 array('x')\n").FindClass("Same")!.New()!;
        var arr = r.NewArray("a", "b");
        r.AddCommandEnvironment("NOP", cmd => cmd.Command.Length);
        r.Output = new StringWriter();
        var command = r.Compile("command", "address nop 'x'; say rc; return rc");
        double Rate(Action act, int n)
        {
            var sw = System.Diagnostics.Stopwatch.StartNew();
            for (int i = 0; i < n; i++) act();
            return sw.Elapsed.TotalMilliseconds / n;
        }
        foreach (var (what, act) in new (string, Action)[] {
            ("a String back", () => same.Send("same", "x")), ("a number back", () => same.Send("same", 1)),
            ("Run<int>", () => r.Run<int>("return 1 + 1")), ("Supplier", () => arr.Supplier()),
            ("an exception", () => { try { same.Send("fail"); } catch (RexxException) { } }),
            ("a command and a say (phase B)", () => command.Call()) })
        {
            // measured warm, the best of three rounds each (a shared machine is noisy)
            double Best() => Math.Min(Rate(act, 3000), Math.Min(Rate(act, 3000), Rate(act, 3000)));
            Rate(act, 1000);
            double first = Best();
            for (int i = 0; i < 15000; i++) act();
            double last = Best();
            if (Environment.GetEnvironmentVariable("HOSTTESTS_RATES") != null)
                Console.WriteLine($"     {what}: {first * 1000:F1} -> {last * 1000:F1} µs per call");
            Ok($"no local references left: {what}", last < first * 4, true);
        }
    }

    static void MakeGarbage(RexxClass cls, int n)
    {
        for (int i = 0; i < n; i++) cls.New(i);
    }
}
