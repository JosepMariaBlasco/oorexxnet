// Collections (notes/netobject-design.md, phase 2): DO OVER (the items of an
// IEnumerable), DO WITH INDEX ITEM (indexes and items), and o[i, ...] (array
// elements and indexers, 0-based as in C#).
//
// An enum type is enumerable too: DO OVER its names, DO WITH names and values.
//
// Indexes for DO WITH are what o[index] takes back: an IDictionary's keys
// (also a generic IDictionary / IReadOnlyDictionary's), the 0-based positions
// of an array or list (for an array of rank > 1, an Array of positions), and
// 1..n for any other enumerable, which has no index of its own.
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
        if (o is StaticOf { Type.IsEnum: true } en)             // an enum type: its names
        {
            foreach (var n in Enum.GetNames(en.Type)) a.Add('S', n);
            w.Add('A', a.ToArray());
            return;
        }
        foreach (var x in Enumerable(o)) Conv.ToRexx(a, x);
        w.Add('A', a.ToArray());
    }

    public static void Pairs(object o, Writer w)
    {
        var idx = new Writer();
        var items = new Writer();
        if (o is StaticOf { Type.IsEnum: true } en)             // an enum type: names and values
        {
            var under = Enum.GetUnderlyingType(en.Type);
            foreach (var v in Enum.GetValues(en.Type))
            {
                idx.Add('S', v.ToString()!);
                Conv.ToRexx(items, System.Convert.ChangeType(v, under));
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
                foreach (var p in at) pos.Add('S', p.ToString());
                idx.Add('A', pos.ToArray());
                Conv.ToRexx(items, arr.GetValue(at));
            }
        }
        else
        {
            long i = IsList(o) ? 0 : 1;
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
        if (o is Array a) { Conv.ToRexx(w, a.GetValue(Positions(a, idx))); return; }
        var getters = Members.Indexers(o.GetType()).Where(p => p.GetMethod is { IsPublic: true }).Select(p => p.GetMethod!).ToList();
        if (getters.Count == 0) throw new BridgeException($"{Types.Display(o.GetType())} has no indexer");
        var (m, conv) = Members.Choose(getters, idx, $"{Types.Display(o.GetType())}[]");
        Conv.ToRexx(w, m.Invoke(o, conv), m.ReturnType);
    }

    public static void SetIndex(object o, Rec value, List<Rec> idx)
    {
        if (o is StaticOf so) throw new BridgeException($"{Types.Display(so.Type)} is a type: it has no indexer");
        if (o is Array a)
        {
            var et = a.GetType().GetElementType()!;
            if (Conv.TryConvert(value, et, out var v) == Conv.Fail)
                throw new BridgeException($"cannot store \"{Conv.Describe(value)}\" in a {Types.Display(a.GetType())}");
            a.SetValue(v, Positions(a, idx));
            return;
        }
        var setters = Members.Indexers(o.GetType()).Where(p => p.SetMethod is { IsPublic: true }).Select(p => p.SetMethod!).ToList();
        if (setters.Count == 0)
            throw new BridgeException($"{Types.Display(o.GetType())} has no indexer that can be set");
        var args = new List<Rec>(idx) { value };                   // the setter: (indices..., value)
        var (m, conv) = Members.Choose(setters, args, $"{Types.Display(o.GetType())}[] =");
        m.Invoke(o, conv);
    }

    static long[] Positions(Array a, List<Rec> idx)
    {
        if (idx.Count != a.Rank)
            throw new BridgeException($"a {Types.Display(a.GetType())} takes {a.Rank} index{(a.Rank == 1 ? "" : "es")}, not {idx.Count}");
        var at = new long[idx.Count];
        for (int i = 0; i < idx.Count; i++)
        {
            if (Conv.TryConvert(idx[i], typeof(long), out var v) == Conv.Fail)
                throw new BridgeException($"an array index is a whole number, not \"{Conv.Describe(idx[i])}\"");
            at[i] = (long)v!;
        }
        return at;
    }
}
