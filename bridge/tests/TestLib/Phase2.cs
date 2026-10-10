// Test types for the bridge's phase-2 tests (tests/phase2.rex): collections,
// indexers, objects of non-public types; generic methods, structs, enums,
// tasks, ref / out.
using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics.CodeAnalysis;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;

namespace RexxNetTests;

public interface IShape { string Name { get; } double Area(); }

internal sealed class Hidden : IShape
{
    public string Name => "hidden";
    public double Area() => 2;
    public string Secret() => "secret";            // public, but on a non-public type: C# cannot reach it
}

public static class Coll
{
    public static IShape MakeHidden() => new Hidden();
    public static IEnumerable<int> Range(int n) { for (int i = 1; i <= n; i++) yield return i * 10; }
    public static int[,] Grid() => new[,] { { 1, 2, 3 }, { 4, 5, 6 } };
    public static int[][] Jagged() => new[] { new[] { 1, 2 }, new[] { 4, 5, 6 } };
    public static string TypesOf(object?[] a) => string.Join(" ", a.Select(x => x?.GetType().Name ?? "null"));
    public static int SumAll(int[,] g) { int n = 0; foreach (var x in g) n += x; return n; }
    public static string Shape(Array a) =>                    // type, lengths, a[0, last] and a[last, 0]
        $"{a.GetType().Name} {string.Join("x", Enumerable.Range(0, a.Rank).Select(a.GetLength))} " +
        (a.Rank == 2 ? $"{a.GetValue(0, a.GetLength(1) - 1)} {a.GetValue(a.GetLength(0) - 1, 0)}" : "");
    public static IReadOnlyDictionary<string, int> ReadOnly() => new RoDict(new() { ["x"] = 1, ["y"] = 2 });
    public static IList<string> Hidden2() => new List<string> { "p", "q" }.AsReadOnly();
}

/// A dictionary that is not an IDictionary (only the generic read-only one).
public sealed class RoDict : IReadOnlyDictionary<string, int>
{
    readonly Dictionary<string, int> d;
    public RoDict(Dictionary<string, int> d) { this.d = d; }
    public int this[string key] => d[key];
    public IEnumerable<string> Keys => d.Keys;
    public IEnumerable<int> Values => d.Values;
    public int Count => d.Count;
    public bool ContainsKey(string key) => d.ContainsKey(key);
    public bool TryGetValue(string key, [MaybeNullWhen(false)] out int value) => d.TryGetValue(key, out value);
    public IEnumerator<KeyValuePair<string, int>> GetEnumerator() => d.GetEnumerator();
    IEnumerator IEnumerable.GetEnumerator() => d.GetEnumerator();
}

/// Indexers under another name ([IndexerName]), overloaded.
public sealed class Matrix
{
    readonly int[,] cells = new int[3, 3];
    [IndexerName("Cell")] public int this[int r, int c] { get => cells[r, c]; set => cells[r, c] = value; }
    [IndexerName("Cell")] public string this[string what] => what == "name" ? "matrix" : "?";
}

[Flags] public enum Style { None = 0, Bold = 1, Italic = 2, Under = 4 }

public struct Counter { public int N; public void Inc() => N++; }

/// Generic methods, enums, structs, ref / out / in, tasks.
public static class Gen
{
    public static string Kind<T>(T x) => typeof(T).Name;
    public static string Kind(int x) => "int (non-generic)";
    public static T First<T>(IEnumerable<T> xs) => xs.First();
    public static T[] Pair<T>(T a, T b) => new[] { a, b };
    public static T Make<T>() where T : new() => new T();
    public static string Both<A, B>(A a, B b) => typeof(A).Name + "," + typeof(B).Name;
    public static string Many<T>(params T[] xs) => typeof(T).Name + " " + xs.Length;
    public static string Styled(Style s) => s.ToString();
    public static int StyleValue(Style s) => (int)s;
    public static Style StyleOf(int n) => (Style)n;
    public static Pt Moved(Pt p, int dx) { p.X += dx; return p; }
    public static void Swap(ref int a, ref int b) { (a, b) = (b, a); }
    public static bool Split(string s, out string head, out string tail)
    {
        head = s.Length > 0 ? s.Substring(0, 1) : ""; tail = s.Length > 0 ? s.Substring(1) : "";
        return s.Length > 0;
    }
    public static int Twice(in int x) => x * 2;
    public static async Task<int> AddLater(int a, int b) { await Task.Delay(20); return a + b; }
    public static async Task Later() => await Task.Delay(10);
    public static async Task<int> FailLater() { await Task.Delay(10); throw new InvalidOperationException("late boom"); }
    public static ValueTask<string> Value() => new ValueTask<string>("vt");
}
