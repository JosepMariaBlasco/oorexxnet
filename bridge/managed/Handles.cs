// The handle table: id -> object and object -> id (by reference), so the same
// .NET object always has the same id (identity works on the Rexx side, and
// repeated gets do not leak). Each time an id goes to Rexx a new Rexx proxy
// is made, so the entry counts them; each proxy's uninit releases one. A type used for its static members is held as
// a StaticOf, so that a System.Type can also be an ordinary object (o~GetType).
// The object of a pair (an instance of a Rexx class extending a .NET class)
// whose Rexx object Rexx no longer holds is held weakly (Extend.cs, Lifetime).
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
    // O: the object, held; or, held weakly (W), when its only proxy is a pair's
    // Rexx object that Rexx no longer holds (Weak: Extend.cs, "Lifetime")
    sealed class Entry { public object? O; public WeakReference? W; public int Refs; public bool Weak; }
    static readonly Dictionary<int, Entry> byId = new();
    static readonly Dictionary<object, int> byObject = new(ReferenceEqualityComparer.Instance);
    static readonly ConditionalWeakTable<object, StrongBox<int>> weakIds = new();   // the objects held weakly
    static int weakCount;
    static int next = 1;

    public static int Add(object o)
    {
        lock (gate)
        {
            if (byObject.TryGetValue(o, out int id)) { byId[id].Refs++; return id; }
            if (weakCount > 0 && weakIds.TryGetValue(o, out var box))
            {
                var e = byId[box.Value];
                e.Refs++;
                Update(box.Value, e);                       // held again: another proxy
                return box.Value;
            }
            id = next++;
            byId[id] = new Entry { O = o, Refs = 1 };
            byObject[o] = id;
            return id;
        }
    }

    public static object Get(int id)
    {
        lock (gate)
            return byId.TryGetValue(id, out var e) && (e.O ?? e.W?.Target) is object o ? o
                : throw new BridgeException($"the .NET object #{id} was released");
    }

    public static void Release(int id)
    {
        lock (gate)
        {
            if (!byId.TryGetValue(id, out var e)) return;
            if (--e.Refs > 0) { Update(id, e); return; }
            byId.Remove(id);
            if (e.O != null) byObject.Remove(e.O);
            else
            {
                weakCount--;
                if (e.W!.Target is object o) weakIds.Remove(o);
            }
        }
    }

    /// A pair's Rexx object no longer holds its .NET object (weak: true), or
    /// holds it again (false); other proxies of the object still hold it.
    internal static void SetWeak(int id, bool weak)
    {
        lock (gate)
            if (byId.TryGetValue(id, out var e)) { e.Weak = weak; Update(id, e); }
    }

    // Held while a proxy holds it: Refs, less the pair's Rexx object if weak.
    static void Update(int id, Entry e)
    {
        bool held = e.Refs > (e.Weak ? 1 : 0);
        if (held && e.O == null)
        {
            if (e.W!.Target is not object o) return;        // collected: released soon (Extend.cs)
            e.O = o; e.W = null;
            weakIds.Remove(o);
            weakCount--;
            byObject[o] = id;
        }
        else if (!held && e.O != null)
        {
            var o = e.O;
            e.W = new WeakReference(o); e.O = null;
            byObject.Remove(o);
            weakIds.AddOrUpdate(o, new StrongBox<int>(id));
            weakCount++;
        }
    }

    public static int Count { get { lock (gate) return byId.Count; } }
}

/// An error of the bridge itself (not a .NET exception of the called code).
public sealed class BridgeException : Exception
{
    public BridgeException(string message) : base(message) { }
}

/// No member of that name: Rexx's 97.1 ("Object ... does not understand
/// message ..."), with a MissingMemberException for the Rexx code to look at.
public sealed class NoMemberException : Exception
{
    public string MessageName { get; }       // as Rexx sent it: "FOO", "FOO=", or the exact name
    public MissingMemberException Missing { get; }
    public NoMemberException(string messageName, string detail) : base(detail)
    { MessageName = messageName; Missing = new MissingMemberException(detail); }
}

/// One of Rexx's own errors (93.907, 93.925...), raised as Rexx raises it,
/// where a .NET object stands for a Rexx one (a .NET array as a Rexx Array).
public sealed class RexxSyntaxException : Exception
{
    public int Code { get; }                 // 93907 for 93.907
    public string[] Substitutions { get; }
    public RexxSyntaxException(int code, params string[] substitutions)
        : base($"Rexx error {code / 1000}.{code % 1000}") { Code = code; Substitutions = substitutions; }
}
