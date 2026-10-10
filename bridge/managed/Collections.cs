// Collections (notes/netobject-design.md, phase 2 and "Arrays as Rexx
// Arrays"): DO OVER (the items of an IEnumerable), DO WITH INDEX ITEM
// (indexes and items), o[i, ...] (indexers, 0-based as in C#), and .NET
// arrays as Rexx Arrays (.NetArray: from 1 in every dimension, as
// BSF4ooRexx's BSF_ARRAY_REFERENCE does for Java arrays).
//
// An enum type is enumerable too (as BSF4ooRexx's Java enum classes): DO OVER
// gives its values (.NetEnums) by number, DO WITH numbers and names.
//
// Indexes for DO WITH are what o[index] takes back: an IDictionary's keys
// (also a generic IDictionary / IReadOnlyDictionary's), the 1-based positions
// of an array (for an array of rank > 1, an Array of positions), the 0-based
// positions of a list (lists stay as .NET documents them), and 1..n for any
// other enumerable, which has no index of its own.
//
// Everything is a snapshot taken at the time of the call (as Rexx's own
// makeArray and supplier): the items of a lazy enumerable are produced at
// once, so an endless one never ends.
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace Rexx.Net;

public static class Collections
{
    static IEnumerable Enumerable(object o) => o switch
    {
        StaticOf so => throw new BridgeException($"{Types.Display(so.Type)} is a type, not a collection"),
        IEnumerable e => e,
        _ => throw new BridgeException($"{Types.Display(o.GetType())} is not enumerable (it is no IEnumerable)"),
    };

    public static void Items(object o, Writer w)
    {
        var a = new Writer();
        if (o is StaticOf { Type.IsEnum: true } en)             // an enum type: its values (objects), by number
        {
            foreach (var v in Enum.GetValues(en.Type)) Conv.ToRexx(a, v);
            w.Add('A', a.ToArray());
            return;
        }
        foreach (var x in Enumerable(o))
        {
            if (OperatingSystem.IsWindows()) Com.Inherit(o, x);    // DO OVER a COM collection: its language
            Conv.ToRexx(a, x);
        }
        w.Add('A', a.ToArray());
    }

    public static void Pairs(object o, Writer w)
    {
        var idx = new Writer();
        var items = new Writer();
        if (o is StaticOf { Type.IsEnum: true } en)             // an enum type: numbers and names
        {
            foreach (var v in Enum.GetValues(en.Type))
            {
                idx.Add('S', Bridge.EnumNumber(v));
                items.Add('S', v.ToString()!);
            }
            var b = new Writer(); b.Add('A', idx.ToArray()); b.Add('A', items.ToArray());
            w.Add('A', b.ToArray());
            return;
        }
        var e = Enumerable(o);
        if (o is IDictionary d)
        {
            foreach (DictionaryEntry de in d) { Conv.ToRexx(idx, de.Key); Conv.ToRexx(items, de.Value); }
        }
        else if (KeyValue(o.GetType()) is (PropertyInfo key, PropertyInfo value))
        {
            foreach (var x in e) { Conv.ToRexx(idx, key.GetValue(x)); Conv.ToRexx(items, value.GetValue(x)); }
        }
        else if (o is Array arr && arr.Rank > 1)
        {
            var at = new long[arr.Rank];
            for (long n = 0; n < arr.LongLength; n++)
            {
                long rest = n;                                   // n as positions, the last one fastest
                for (int k = arr.Rank - 1; k >= 0; k--) { at[k] = rest % arr.GetLength(k); rest /= arr.GetLength(k); }
                var pos = new Writer();
                foreach (var p in at) pos.Add('S', (p + 1).ToString());   // from 1, as a Rexx Array
                idx.Add('A', pos.ToArray());
                Conv.ToRexx(items, arr.GetValue(at));
            }
        }
        else
        {
            long i = IsList(o) && o is not Array ? 0 : 1;   // a list from 0 (as .NET), an array from 1
            foreach (var x in e) { idx.Add('S', (i++).ToString()); Conv.ToRexx(items, x); }
        }
        var both = new Writer();
        both.Add('A', idx.ToArray());
        both.Add('A', items.ToArray());
        w.Add('A', both.ToArray());
    }

    static bool IsList(object o) =>
        o is Array || o is IList || o.GetType().GetInterfaces().Any(i => i.IsGenericType &&
            (i.GetGenericTypeDefinition() == typeof(IList<>) || i.GetGenericTypeDefinition() == typeof(IReadOnlyList<>)));

    // A generic dictionary that is not an IDictionary: its pairs' Key and Value.
    static (PropertyInfo, PropertyInfo)? KeyValue(Type t)
    {
        var i = t.GetInterfaces().FirstOrDefault(i => i.IsGenericType &&
            (i.GetGenericTypeDefinition() == typeof(IDictionary<,>) || i.GetGenericTypeDefinition() == typeof(IReadOnlyDictionary<,>)));
        if (i == null) return null;
        var kv = typeof(KeyValuePair<,>).MakeGenericType(i.GetGenericArguments());
        return (kv.GetProperty("Key")!, kv.GetProperty("Value")!);
    }

    // ------------------------------------------------------------- o[i, ...]

    public static void Index(object o, List<Rec> idx, Writer w)
    {
        if (o is StaticOf so) throw new BridgeException($"{Types.Display(so.Type)} is a type: it has no indexer");
        if (o is Array a) { ArrayAt(a, idx, w); return; }
        if (Com.Is(o)) { Com.Index(o, idx, w); return; }
        var getters = Members.Indexers(o.GetType()).Where(p => p.GetMethod is { IsPublic: true }).Select(p => p.GetMethod!).ToList();
        if (getters.Count == 0) throw new BridgeException($"{Types.Display(o.GetType())} has no indexer");
        var (m, conv) = Members.Choose(getters, idx, $"{Types.Display(o.GetType())}[]");
        Conv.ToRexx(w, m.Invoke(o, conv), m.ReturnType);
    }

    public static void SetIndex(object o, Rec value, List<Rec> idx)
    {
        if (o is StaticOf so) throw new BridgeException($"{Types.Display(so.Type)} is a type: it has no indexer");
        if (Com.Is(o)) { Com.SetIndex(o, value, idx); return; }
        if (o is Array a) { ArrayPut(a, value, 2, idx); return; }
        var setters = Members.Indexers(o.GetType()).Where(p => p.SetMethod is { IsPublic: true }).Select(p => p.SetMethod!).ToList();
        if (setters.Count == 0)
            throw new BridgeException($"{Types.Display(o.GetType())} has no indexer that can be set");
        var args = new List<Rec>(idx) { value };                   // the setter: (indices..., value)
        var (m, conv) = Members.Choose(setters, args, $"{Types.Display(o.GetType())}[] =");
        m.Invoke(o, conv);
    }

    // ------------------------------------------- a .NET array as a Rexx Array

    // a~at(i, j), a[i, j], a~at(.array~of(i, j)): from 1 in every dimension.
    public static void ArrayAt(Array a, List<Rec> idx, Writer w) =>
        Conv.ToRexx(w, a.GetValue(Positions(a, idx, 1)));

    // a~put(v, i, j), a[i, j] = v; first: the argument number of the first
    // index (2 for put, 3 for putStrict), for Rexx's error messages.
    public static void ArrayPut(Array a, Rec value, int first, List<Rec> idx)
    {
        var at = Positions(a, idx, first);
        var et = a.GetType().GetElementType()!;
        if (Conv.TryConvert(value, et, out var v) == Conv.Fail)
            throw new BridgeException($"cannot store \"{Conv.Describe(value)}\" in a {Types.Display(a.GetType())}");
        a.SetValue(v, at);
    }

    // a~dimension: the rank; a~dimension(n): the length of dimension n (0
    // past the rank), as a Rexx Array answers.
    public static void ArrayDimension(Array a, List<Rec> args, Writer w)
    {
        if (args.Count == 0) { w.Add('S', a.Rank.ToString()); return; }
        if (args.Count > 1) throw new RexxSyntaxException(93902, "1");
        long n = Whole(args[0]) ?? throw new RexxSyntaxException(93907, "1", Conv.Describe(args[0]));
        w.Add('S', (n > a.Rank ? 0 : a.GetLength((int)n - 1)).ToString());
    }

    // The 0-based positions .NET wants, from the 1-based ones Rexx gives
    // (one per dimension, or one Rexx Array of them). Wrong ones raise the
    // errors a Rexx Array raises; one past the bounds is .NET's
    // IndexOutOfRangeException (a .NET array cannot grow).
    static long[] Positions(Array a, List<Rec> idx, int first)
    {
        bool one = idx.Count == 1 && idx[0].Tag == 'A';            // at(.array~of(i, j))
        if (one) idx = idx[0].Items;
        else if (idx.Count == 0) throw new RexxSyntaxException(93901, first.ToString());
        if (idx.Count < a.Rank) throw new RexxSyntaxException(93925, a.Rank.ToString());
        if (idx.Count > a.Rank) throw new RexxSyntaxException(93926, a.Rank.ToString());
        var at = new long[idx.Count];
        for (int i = 0; i < idx.Count; i++)
        {
            long? n = Whole(idx[i]);
            if (n == null)
                throw a.Rank == 1
                    ? new RexxSyntaxException(93907, (one ? first : first + i).ToString(), Conv.Describe(idx[i]))
                    : new RexxSyntaxException(93924, Conv.Describe(idx[i]));
            at[i] = n.Value - 1;
        }
        return at;
    }

    // A positive whole number, as Rexx reads one ("3", " 3 ", "3.0", "3E0").
    static long? Whole(Rec r)
    {
        if (r.Tag != 'S' || !decimal.TryParse(r.Text.Trim(), System.Globalization.NumberStyles.Float,
                System.Globalization.CultureInfo.InvariantCulture, out var d)) return null;
        if (d != decimal.Truncate(d) || d < 1 || d > long.MaxValue) return null;
        return (long)d;
    }
}
