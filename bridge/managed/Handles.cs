// The handle table: id -> object and object -> id (by reference), so the same
// .NET object always has the same id (identity works on the Rexx side, and
// repeated gets do not leak). Each time an id goes to Rexx a new Rexx proxy
// is made, so the entry counts them; each proxy's uninit releases one. A type used for its static members is held as
// a StaticOf, so that a System.Type can also be an ordinary object (o~GetType).
using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;

namespace Rexx.Net;

/// A type seen as the holder of its static members (a .NetType in Rexx).
public sealed class StaticOf
{
    public readonly Type Type;
    StaticOf(Type t) { Type = t; }
    static readonly ConditionalWeakTable<Type, StaticOf> cache = new();
    public static StaticOf For(Type t) => cache.GetValue(t, x => new StaticOf(x));
}

public static class Handles
{
    static readonly object gate = new();
    sealed class Entry { public object O = null!; public int Refs; }
    static readonly Dictionary<int, Entry> byId = new();
    static readonly Dictionary<object, int> byObject = new(ReferenceEqualityComparer.Instance);
    static int next = 1;

    public static int Add(object o)
    {
        lock (gate)
        {
            if (byObject.TryGetValue(o, out int id)) { byId[id].Refs++; return id; }
            id = next++;
            byId[id] = new Entry { O = o, Refs = 1 };
            byObject[o] = id;
            return id;
        }
    }

    public static object Get(int id)
    {
        lock (gate)
            return byId.TryGetValue(id, out var e) ? e.O
                : throw new BridgeException($"the .NET object #{id} was released");
    }

    public static void Release(int id)
    {
        lock (gate)
            if (byId.TryGetValue(id, out var e) && --e.Refs <= 0)
            {
                byId.Remove(id);
                byObject.Remove(e.O);
            }
    }

    public static int Count { get { lock (gate) return byId.Count; } }
}

/// An error of the bridge itself (not a .NET exception of the called code).
public sealed class BridgeException : Exception
{
    public BridgeException(string message) : base(message) { }
}
