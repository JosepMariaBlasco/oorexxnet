// Test types for the bridge's phase-1 tests (tests/phase1.rex): cases the
// standard library does not give cleanly.
using System;
using System.Collections.Generic;
using System.Linq;

namespace RexxNetTests;

public static class Probe
{
    public static string Ambig(int a, long b) => "int,long";
    public static string Ambig(long a, int b) => "long,int";
    public static string Opt(int a, int b = 5) => $"{a},{b}";
    public static int Sum(params int[] xs) => xs.Sum();
    public static string Kind(object? o) => o?.GetType().FullName ?? "null";
    // C#'s tie-break: no params array to fill, no default to fill in, wins
    public static string Tie(string s) => "plain";
    public static string Tie(string s, params object[] rest) => "params " + rest.Length;
    public static string Tie2(string s) => "plain";
    public static string Tie2(string s, int n = 1) => "default";
    public static string Num(int x) => "int";
    public static string Num(double x) => "double";
    public static string Num(string x) => "string";
    public static string NumOnly(int x) => "int";
    public static string NumOnly(long x) => "long";
    public static string NumOnly(double x) => "double";
    public static string Small(byte x) => "byte " + x;
    public static string Flag(bool b) => b ? "yes" : "no";
    public static string Ch(char c) => "char " + c;
    public static string Day(DayOfWeek d) => d.ToString();
    public static string Join(IEnumerable<string> xs) => string.Join("+", xs);
    public static int Arr(int[] xs) => xs.Sum();
    public static string? Nothing() => null;
    public static void Void() { }
    public static void Throw() => throw new InvalidOperationException("boom");
    public static int Counter;
    public const int Answer = 42;
    public static Pt MakePt(int x, int y) => new Pt(x, y);
    public static string Same(object a, object b) => ReferenceEquals(a, b) ? "same" : "different";
}

public struct Pt
{
    public int X, Y;
    public Pt(int x, int y) { X = x; Y = y; }
    public override string ToString() => $"({X}, {Y})";
}

public class Case
{
    public int Value { get; set; } = 1;
    public int value = 2;                   // a public field differing only in case
    public int Fixed => 7;
}

public class Base { public string Who() => "base"; }
public class Derived : Base { public new string Who() => "derived"; }

public class Machine
{
    public bool Started;
    public void Start() => Started = true;
    public string Send(string x) => "sent " + x;
    public string Copy() => "copied";
}

/// What a COM object gives back, as .NET sees the VARIANT (Int32 for VT_I4,
/// Double for VT_R8, Boolean for VT_BOOL, Object[,] for a 2-D SAFEARRAY...):
/// what the bridge sent it, for tests/com.rex (Scripting.Dictionary keeps it).
public static class ComProbe
{
    public static string TypeOf(object com, string member, object arg)
    {
        var r = com.GetType().InvokeMember(member,
            System.Reflection.BindingFlags.InvokeMethod | System.Reflection.BindingFlags.GetProperty,
            null, com, new[] { arg });
        return r?.GetType().Name ?? "null";
    }

    /// The same for the items of an array the COM object gives back.
    public static string ItemTypes(object com, string member, object arg)
    {
        var r = (Array)com.GetType().InvokeMember(member,
            System.Reflection.BindingFlags.InvokeMethod | System.Reflection.BindingFlags.GetProperty,
            null, com, new[] { arg })!;
        return string.Join(" ", r.Cast<object?>().Select(x => x?.GetType().Name ?? "null"));
    }

    /// The same for the items of the first item, itself an array (nested arrays).
    public static string InnerItemTypes(object com, string member, object arg)
    {
        var r = (Array)com.GetType().InvokeMember(member,
            System.Reflection.BindingFlags.InvokeMethod | System.Reflection.BindingFlags.GetProperty,
            null, com, new[] { arg })!;
        return string.Join(" ", ((Array)r.GetValue(0)!).Cast<object?>().Select(x => x?.GetType().Name ?? "null"));
    }
}
