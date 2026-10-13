// For tests/extend.rex: classes and interfaces for Rexx classes to extend.
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace RexxNetTests;

/// An abstract class with a virtual call in its constructor and protected
/// members of every kind.
public abstract class Shape
{
    protected Shape(string name) { Name = name; Created = Describe(); }
    protected Shape() : this("shape") { }
    public string Name { get; }
    public string Created { get; }                      // Describe() as the constructor saw it
    public abstract double Area();
    public virtual string Describe() => $"{Name}: {Area()}";
    public string Report() => Describe();
    public int SidesSeen => Sides;
    public string Greet(string who) => Hello(who);

    protected int secret = 42;
    protected static string Kind = "shape";
    protected readonly string fixedName = "fixed";
    protected string Hidden() => "hidden " + Name;
    protected string Hidden(int n) => "hidden " + n;
    protected virtual int Sides => 0;
    protected virtual string Hello(string who) => "hello " + who;
    protected string Label { get; set; } = "none";
}

public interface IValue
{
    int Value { get; set; }
    string Describe(string prefix);
}

public interface ICounter : IValue
{
    int Next();
}

/// Parameters by reference, to override and implement.
public interface IFinder
{
    bool TryFind(string key, out int value);
    void Twice(ref int n);
}

public class Parser
{
    public virtual bool TryParse(string s, out int n) { n = int.TryParse(s, out var v) ? v : -1; return n >= 0; }
}

/// Generic methods to override: abstract (the result a type parameter),
/// virtual, constrained, protected, with an out parameter.
public abstract class Factory
{
    public abstract T Make<T>(string text);
    public virtual List<T> Pair<T>(T a, T b) => new() { a, b };
    public virtual string Show<T>(T x) where T : IFormattable => "base " + x.ToString(null, System.Globalization.CultureInfo.InvariantCulture);
    protected virtual T First<T>(T[] xs) => xs[0];
    public T CallFirst<T>(params T[] xs) => First(xs);
    public virtual bool TryGet<T>(string key, out T value) { value = default!; return false; }
}

public interface IConverter
{
    TOut Convert<TIn, TOut>(TIn x);
}

public static class ExtendProbe
{
    public static string UseFactory(Factory f) =>
        $"{f.Make<int>("41") + 1} {f.Make<string>("s")} {f.Make<DateTime>("2026-10-11").Year} {f.Make<List<int>>("x").Count}";
    public static string Pair(Factory f) => string.Join(",", f.Pair(1, 2)) + " " + string.Join(",", f.Pair("a", "b"));
    public static string Show(Factory f) => f.Show(1.5) + " / " + f.Show(7);
    public static string First(Factory f) => f.CallFirst(3, 4) + " " + f.CallFirst("p", "q") + " " + f.CallFirst(5, 6, 7);
    public static string TryGet(Factory f) => (f.TryGet<int>("n", out var n) ? $"{n}" : "-") + " " + (f.TryGet<string>("s", out var s) ? s : "-");
    public static string Convert(IConverter c) => c.Convert<int, string>(5) + " " + (c.Convert<string, int>("6") + 1);

    public static string Find(IFinder f, string key) => f.TryFind(key, out var v) ? $"found {v}" : $"none {v}";
    public static int Twice(IFinder f, int n) { f.Twice(ref n); return n; }
    public static string Parse(Parser p, string s) => $"{p.TryParse(s, out var n)} {n}";

    /// The property names an INotifyPropertyChanged reports, as they come.
    public static List<string> Watch(System.ComponentModel.INotifyPropertyChanged o)
    {
        var seen = new List<string>();
        o.PropertyChanged += (sender, e) => seen.Add($"{e.PropertyName}{(ReferenceEquals(sender, o) ? "" : "?")}");
        return seen;
    }

    public static double TotalArea(IEnumerable<Shape> shapes) => shapes.Sum(s => s.Area());
    public static object Same(object o) => o;
    public static string OnAnotherThread(Shape s) => Task.Run(() => s.Describe()).Result;
    public static string UseValue(IValue v)
    {
        v.Value = v.Value + 10;
        return v.Describe("v=") + " " + v.Value;
    }
    public static string Count(ICounter c) => $"{c.Next()} {c.Next()} {((IValue)c).Value}";
    public static string Fail(Shape s)
    {
        try { return s.Report(); }
        catch (Exception e) { return e.GetType().Name; }
    }
}

/// For tests/lifetime.rex: .NET holding instances of Rexx classes and handlers alone,
/// and its collector run.
public static class GcProbe
{
    static readonly List<object> kept = new();
    static readonly object gate = new();
    public static void Keep(object o) { lock (gate) kept.Add(o); }
    public static int Count { get { lock (gate) return kept.Count; } }
    public static object Take(int i) { lock (gate) return kept[i]; }
    public static void Clear() { lock (gate) kept.Clear(); }
    /// Report() of each one kept: their overrides, called by .NET.
    public static string Reports() { lock (gate) return string.Join(",", kept.OfType<Shape>().Select(s => s.Report())); }
    /// The same from another thread (not a Rexx thread).
    public static string ReportsElsewhere() => Task.Run(Reports).Result;
    public static void Collect()
    {
        for (int i = 0; i < 3; i++) { GC.Collect(); GC.WaitForPendingFinalizers(); }
    }
    /// Delegates (Rexx handlers) kept by .NET alone, and called.
    static readonly List<Action> actions = new();
    public static void KeepAction(Action a) { lock (gate) actions.Add(a); }
    public static int RunActions() { Action[] all; lock (gate) all = actions.ToArray(); foreach (var a in all) a(); return all.Length; }
    public static void ClearActions() { lock (gate) actions.Clear(); }
    /// The types .net~extend made that are still loaded (each in a collectible assembly).
    public static int ExtendedTypes() => AppDomain.CurrentDomain.GetAssemblies().Count(a => a.GetName().Name!.StartsWith("Rexx.Extended."));
    /// A synchronous use: the comparison called, nothing kept.
    public static string SortWith(Comparison<string> c) { var l = new List<string> { "ccc", "a", "bb" }; l.Sort(c); return string.Join(" ", l); }
}
