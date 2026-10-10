// Phase 3 test types: events, delegates, callbacks from other threads.
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Threading;
using System.Threading.Tasks;

namespace RexxNetTests;

public class ValueEventArgs : EventArgs
{
    public int Value { get; }
    public ValueEventArgs(int v) { Value = v; }
}

public delegate void RefDelegate(ref int x);

/// Something with events, as a WinForms control would have.
public class Button
{
    public string Name { get; set; } = "button";
    public event EventHandler? Click;
    public event EventHandler<ValueEventArgs>? ValueChanged;
    public event EventHandler<CancelEventArgs>? Closing;
    public static event EventHandler? Shared;
#pragma warning disable CS0067   // never raised: the tests only check that it is refused
    public event RefDelegate? WithRef;
#pragma warning restore CS0067

    public int ClickSubscribers => Click?.GetInvocationList().Length ?? 0;
    public event EventHandler? Thing;
    public string add_Thing(object x) => "method";              // a method with an accessor's name
    public void RaiseThing() => Thing?.Invoke(this, EventArgs.Empty);

    public void PerformClick() => Click?.Invoke(this, EventArgs.Empty);
    public void SetValue(int v) => ValueChanged?.Invoke(this, new ValueEventArgs(v));

    /// Raises Closing; true if nobody cancelled.
    public bool Close()
    {
        var e = new CancelEventArgs();
        Closing?.Invoke(this, e);
        return !e.Cancel;
    }

    public static void RaiseShared() => Shared?.Invoke(null, EventArgs.Empty);

    /// Raises Click count times from another thread while this one waits
    /// (as Application.Run): the number of clicks done, and whether the
    /// handler ran on another thread.
    public string ClickFromOtherThread(int count)
    {
        int caller = Environment.CurrentManagedThreadId, other = 0;
        var t = new Thread(() => { other = Environment.CurrentManagedThreadId; for (int i = 0; i < count; i++) PerformClick(); });
        t.Start();
        t.Join();
        return $"{count} {other != caller}";
    }

    /// Raises ValueChanged 1..count from a background thread, every ms; returns at once.
    public void StartValues(int count, int ms)
    {
        var t = new Thread(() => { for (int i = 1; i <= count; i++) { Thread.Sleep(ms); SetValue(i); } }) { IsBackground = true };
        t.Start();
    }
}

public static class Delegates
{
    public static int Apply(Func<int, int, int> f, int a, int b) => f(a, b);
    public static string Text(Func<string> f) => f();
    public static bool Check(Predicate<string> p, string s) => p(s);
    public static void Run(Action a) => a();
    public static object? RunDelegate(Delegate d) => d.DynamicInvoke();
    public static string Kind(Action a) => "Action";
    public static string Kind(Func<int> f) => "Func<int>:" + f();
    public static int Sum(IEnumerable<int> xs, Func<int, int> f) { int s = 0; foreach (var x in xs) s += f(x); return s; }
    public static void WithRef(RefDelegate d) { int x = 1; d(ref x); }

    /// Calls a and reports the exception it throws: "type|code|line|message|inner".
    public static string Catch(Action a)
    {
        try { a(); return "no exception"; }
        catch (Exception e)
        {
            var r = e as Rexx.Net.RexxException;
            return $"{e.GetType().Name}|{r?.Code}|{r?.Line}|{e.Message}|{e.InnerException?.GetType().Name}";
        }
    }

    /// Calls a and lets its exception through, wrapped (as List.Sort does).
    public static void Wrap(Action a)
    {
        try { a(); }
        catch (Exception e) { throw new InvalidOperationException("wrapped", e); }
    }

    /// Calls a on count threads at once; the number of calls that ended.
    public static int Parallel(Action a, int count)
    {
        int done = 0;
        var ts = new Thread[count];
        for (int i = 0; i < count; i++) { ts[i] = new Thread(() => { a(); Interlocked.Increment(ref done); }); ts[i].Start(); }
        foreach (var t in ts) t.Join();
        return done;
    }

    public static void Throw(string m) => throw new System.IO.FileNotFoundException(m);
}
