// Rexx classes extending .NET classes (notes/netobject-design.md, "Rexx
// classes extending .NET classes").
//
// .net~extend(.MyClass, base [, interfaces...]) makes, with Reflection.Emit,
// a .NET type deriving from base (System.Object if base is an interface) and
// implementing the interfaces. Each virtual or abstract member of the base
// (public or protected) and each interface member that the Rexx class
// defines a method for is overridden: the override sends that message to the
// Rexx object standing for the .NET object (its "peer"), synchronously,
// through the callbacks' machinery (Callbacks.Call: a RexxHandler whose
// object is the peer and whose message is NET.OVERRIDE, which forwards to the
// method). An abstract member with no Rexx method throws
// NotImplementedException. A virtual member whose peer is gone (the pair is
// over: see Lifetime) runs the base implementation again. A generic method's override is
// generic too (the base's type parameters and constraints); the Rexx method
// gets its type arguments after its arguments, as NetTypes.
//
// Each type lives in a collectible assembly of its own, and what is known of
// it (Info: its overrides' slots too) is the type's own: a class made at run
// time is collected with its type (Members.cs keeps its caches for such a
// type in tables the type holds).
//
// The peer of an instance is set before its constructor runs (the object is
// made uninitialized, the peer registered, then the constructor invoked on
// it), so virtual calls made by a base constructor reach Rexx. When an
// instance goes back to Rexx it is its peer itself (record p), not a new
// proxy.
//
// Protected members: only through the peer (net.cls defines a private Rexx
// method for each, so that only the object's own methods reach them, as a C#
// subclass does): extMember looks a name up among public and protected
// members. base.Name (self~base.InsertItem(i, x)) calls the base
// implementation of an overridden member, non-virtually, through a private
// trampoline that the type has for each.
//
// Lifetime. An instance is a pair, its Rexx object and its .NET object, which
// lives while Rexx holds the one or .NET the other. Neither collector sees
// both halves, so the link that keeps the other half alive points one way at
// a time (rexxnet.cpp, "Pairs", has the Rexx side):
//  - while Rexx holds the Rexx object, it holds its .NET object (its handle);
//    rexxnet knows the Rexx object without holding it;
//  - when Rexx no longer holds it (the UNINIT of a sentinel that only the
//    Rexx object holds), rexxnet holds it (a global reference) and asks for
//    the .NET object to be held weakly (peerWeak): the handle holds it weakly,
//    and a finalizable Companion tied to it (a ConditionalWeakTable) tells
//    rexxnet when .NET collects it (Dead): the pair is over;
//  - when it goes to Rexx again (record p, or an override's call: a
//    crossing), it is held again (Cross), and rexxnet lets the Rexx object
//    go, with a new sentinel.
// Sent counts the crossings; peerWeak carries those rexxnet received, and is
// ignored when one is still on its way. A crossing that never reached Rexx
// (its response dropped for an error, a callback that found no interpreter)
// is taken back (Rollback), and the object is weak again if it was.
//
// Operations (Bridge.Dispatch):
//   extend    S class name, A [S name | O type]..., A [S Rexx method names]
//             -> A [O the new type, A protected member names, A base. names, A raise. names]
//   extAlloc  O type, H peer handler   -> S "id\tdisplay" (not constructed yet)
//   extInit   O object, A args         -> V (its constructor, chosen by the args)
//   extMember O object, S name, A args -> the result ("Name=": a set)
//   extBase   O object, S name, A args -> the result
//   extAbandon O object                -> V (its construction failed: no pair)
//   peerWeak  O object, S crossings    -> S 1 (held weakly now) / 0 (a crossing on its way)
//   extRaise  O object, S event, A args -> V (raise.Name: an interface's event raised)
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.CompilerServices;
using System.Threading;

namespace Rexx.Net;

public static unsafe class Extend
{
    /// What Dispatch answers when there is no Rexx peer to call (the
    /// override then runs the base implementation, or throws).
    [EditorBrowsable(EditorBrowsableState.Never)]
    public static readonly object NoPeer = new();

    // Def: a generic method's definition (its result's type known only with the type arguments)
    sealed record Slot(string Name, Type Ret, string What, MethodInfo? Def = null);

    sealed class Info
    {
        public string RexxClass = "", Shown = "";
        public Dictionary<string, List<string>> Bases = new(StringComparer.OrdinalIgnoreCase);   // Rexx name -> trampolines
        public Dictionary<string, string> Events = new(StringComparer.OrdinalIgnoreCase);        // event -> its handlers' field
        public List<Slot> Slots = new();                                                          // the overrides' (their index in the IL)
    }

    static readonly object gate = new();
    // The types made, each in a collectible assembly of its own: collected with
    // the Rexx class (whose .NetType holds it) and their instances. Info is the
    // type's own (nothing else here holds the type).
    static readonly ConditionalWeakTable<Type, Info> types = new();
    static readonly ConditionalWeakTable<object, Peer> peers = new();

    /// An instance's pair state (see Lifetime above).
    sealed class Peer
    {
        public readonly RexxHandler H;
        public int Handle;                                  // its handle (the Rexx object's netId)
        public long Sent;                                   // crossings to Rexx
        public long WeakAt = -1;                            // Sent when made weak; -1: held
        public Companion? C;
        public Peer(RexxHandler h) { H = h; }
    }

    /// Tied to a weakly held instance: finalized when .NET collects it.
    sealed class Companion
    {
        public readonly int Id;
        public volatile bool Cancelled;
        public Companion(int id) { Id = id; }
        ~Companion() { if (!Cancelled) Dead(Id); }
    }

    static readonly ConditionalWeakTable<object, Companion> companions = new();
    static readonly object pairGate = new();
    static delegate* unmanaged<int, void> nativeDead;       // rexxnet: a pair is over (no API call there)

    internal static void SetDead(IntPtr f) => nativeDead = (delegate* unmanaged<int, void>)f;

    static void Dead(int id)                                // (the finalizer thread)
    {
        Callbacks.Forget(id);
        if (nativeDead != null) nativeDead(id);
    }

    // The crossings made on this thread whose records have not reached Rexx
    // yet (a stack: nested requests and callbacks have their own part).
    [ThreadStatic] static List<(Peer P, long WeakAt)>? crossings;      // WeakAt: the pair's before it

    internal static int Mark() => crossings?.Count ?? 0;

    /// What was sent since mark reached Rexx.
    internal static void Commit(int mark)
    {
        if (crossings != null && crossings.Count > mark) crossings.RemoveRange(mark, crossings.Count - mark);
    }

    /// What was sent since mark never reached Rexx: not counted, and an
    /// object made weak before is weak again (rexxnet still holds its peer).
    internal static void Rollback(int mark)
    {
        if (crossings == null) return;
        for (int i = crossings.Count - 1; i >= mark; i--)
        {
            var (p, weakAt) = crossings[i];
            lock (pairGate)
            {
                p.Sent--;
                if (weakAt >= 0 && p.WeakAt < 0 && p.Sent == weakAt) MakeWeak(p);
            }
        }
        Commit(mark);
    }

    // An instance goes to Rexx: held, counted.
    static void Cross(object o, Peer p)
    {
        long weakAt;
        lock (pairGate)
        {
            weakAt = p.WeakAt;
            if (weakAt >= 0)
            {
                p.WeakAt = -1;
                if (p.C != null) { p.C.Cancelled = true; GC.SuppressFinalize(p.C); p.C = null; }
                companions.Remove(o);
                Handles.SetWeak(p.Handle, false);
            }
            p.Sent++;
        }
        (crossings ??= new()).Add((p, weakAt));
    }

    // (pairGate held)
    static void MakeWeak(Peer p)
    {
        object o;
        try { o = Handles.Get(p.Handle); } catch (BridgeException) { return; }
        p.WeakAt = p.Sent;
        p.C = new Companion(p.H.Id);
        companions.AddOrUpdate(o, p.C);
        Handles.SetWeak(p.Handle, true);
    }

    /// peerWeak: Rexx no longer holds the instance's Rexx object.
    public static void Weaken(Rec target, long received, Writer w)
    {
        var o = Handles.Get(target.Id);
        if (!peers.TryGetValue(o, out var p)) throw new BridgeException("not an instance of a Rexx class extending a .NET class");
        lock (pairGate)
        {
            if (p.Sent != received || p.WeakAt >= 0) { w.Add('S', "0"); return; }
            MakeWeak(p);
        }
        w.Add('S', "1");
    }
    static int serial;

    static readonly MethodInfo dispatch = typeof(Extend).GetMethod(nameof(Dispatch))!;
    static readonly FieldInfo noPeer = typeof(Extend).GetField(nameof(NoPeer))!;

    /// Is t a type made by .net~extend?
    public static bool IsExtended(Type t) => t.IsCollectible && types.TryGetValue(t, out _);

    /// An instance going to Rexx as its Rexx object (record p): its peer
    /// handler, if it has a live one (a crossing: see Lifetime).
    internal static RexxHandler? CrossingOf(object o)
    {
        if (!peers.TryGetValue(o, out var p) || p.H.Released) return null;
        Cross(o, p);
        return p.H;
    }

    /// The body of every override. Public for the emitted code only.
    [EditorBrowsable(EditorBrowsableState.Never)]
    public static object? Dispatch(object self, int slot, object?[] args)
    {
        if (!peers.TryGetValue(self, out var p) || p.H.Released || !Callbacks.Started) return NoPeer;
        Slot s;
        if (!types.TryGetValue(self.GetType(), out var info)) return NoPeer;
        lock (gate) s = info.Slots[slot];
        var all = new object?[args.Length + 1];
        all[0] = s.Name;
        Array.Copy(args, 0, all, 1, args.Length);
        int mark = Mark();
        Cross(self, p);
        return Callbacks.Call(p.H, all, s.Ret, s.What, mark);
    }

    /// The body of an override of a generic method: its type arguments go to
    /// the Rexx method after its arguments, as NetTypes. Public for the emitted code only.
    [EditorBrowsable(EditorBrowsableState.Never)]
    public static object? DispatchGeneric(object self, int slot, object?[] args, Type[] targs)
    {
        if (!peers.TryGetValue(self, out var p) || p.H.Released || !Callbacks.Started) return NoPeer;
        Slot s;
        if (!types.TryGetValue(self.GetType(), out var info)) return NoPeer;
        lock (gate) s = info.Slots[slot];
        var all = new object?[args.Length + targs.Length + 1];
        all[0] = s.Name;
        Array.Copy(args, 0, all, 1, args.Length);
        for (int i = 0; i < targs.Length; i++) all[args.Length + 1 + i] = StaticOf.For(targs[i]);
        var ret = s.Def!.MakeGenericMethod(targs).ReturnType;
        int mark = Mark();
        Cross(self, p);
        return Callbacks.Call(p.H, all, ret, s.What, mark);
    }

    // ------------------------------------------------------------ the type

    public static void Make(string rexxClass, List<Rec> typeSpecs, List<Rec> names, Writer w)
    {
        if (typeSpecs.Count == 0) throw new BridgeException(".net~extend: a base type or an interface is needed");
        var given = typeSpecs.Select(r => r.Tag == 'S' ? Types.Parse(r.Text)
                                          : Handles.Get(r.Id) is StaticOf so ? so.Type
                                          : Handles.Get(r.Id) as Type ?? throw new BridgeException(".net~extend: not a type: " + Conv.Describe(r)))
                             .ToList();
        var baseType = given[0].IsInterface ? typeof(object) : given[0];
        var ifaces = given.Skip(given[0].IsInterface ? 0 : 1).ToList();
        foreach (var t in given)
        {
            if (t.ContainsGenericParameters)
                throw new BridgeException($".net~extend: {Types.Display(t)} is an open generic type: give its type arguments");
            if (!t.IsVisible) throw new BridgeException($".net~extend: {Types.Display(t)} is not public");
        }
        foreach (var i in ifaces)
            if (!i.IsInterface) throw new BridgeException($".net~extend: {Types.Display(i)} is not an interface (only the first type may be a class)");
        if (baseType.IsSealed || baseType.IsValueType || typeof(Delegate).IsAssignableFrom(baseType) || baseType == typeof(Array) || baseType == typeof(Enum))
            throw new BridgeException($".net~extend: {Types.Display(baseType)} cannot be extended (sealed, a struct, a delegate, an enum or an array)");

        var rexxNames = new HashSet<string>(names.Select(n => n.Text.ToUpperInvariant()));
        rexxNames.ExceptWith(new[] { "INIT", "UNINIT", "UNKNOWN" });
        var closure = ifaces.SelectMany(i => new[] { i }.Concat(i.GetInterfaces())).Distinct().ToList();
        foreach (var i in closure)
            if (i.IsAssignableFrom(baseType))
                throw new BridgeException($".net~extend: {Types.Display(baseType)} already implements {Types.Display(i)}: " +
                                          "define methods for its members (they are overridden if virtual), do not name the interface");

        Type created;
        var info = new Info { RexxClass = rexxClass, Shown = $"{rexxClass} extending {string.Join(", ", given.Select(Types.Display))}" };
        lock (gate)
        {
            var name = "Rexx.Extended." + Clean(rexxClass) + "_" + (++serial);
            var module = AssemblyBuilder.DefineDynamicAssembly(new AssemblyName(name), AssemblyBuilderAccess.RunAndCollect)
                                        .DefineDynamicModule(name);
            var tb = module.DefineType(name, TypeAttributes.Public | TypeAttributes.Class | TypeAttributes.BeforeFieldInit, baseType);
            foreach (var i in closure) tb.AddInterfaceImplementation(i);

            // Constructors: the base's public and protected ones, made public.
            int ctors = 0;
            foreach (var c in baseType.GetConstructors(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic))
            {
                if (!(c.IsPublic || c.IsFamily || c.IsFamilyOrAssembly)) continue;
                var ps = c.GetParameters().Select(p => p.ParameterType).ToArray();
                if (ps.Any(Unsupported)) continue;
                var cb = tb.DefineConstructor(MethodAttributes.Public | MethodAttributes.HideBySig, CallingConventions.Standard, ps);
                var pars = c.GetParameters();
                for (int i = 0; i < pars.Length; i++) cb.DefineParameter(i + 1, ParameterAttributes.None, pars[i].Name);
                var il = cb.GetILGenerator();
                il.Emit(OpCodes.Ldarg_0);
                for (int i = 0; i < ps.Length; i++) il.Emit(OpCodes.Ldarg, (short)(i + 1));
                il.Emit(OpCodes.Call, c);
                il.Emit(OpCodes.Ret);
                ctors++;
            }
            if (ctors == 0) throw new BridgeException($".net~extend: {Types.Display(baseType)} has no public or protected constructor");

            // The base class's virtual members.
            foreach (var m in Virtuals(baseType))
            {
                var rn = RexxName(m);
                bool mine = rn != null && rexxNames.Contains(rn);
                if (!mine && !m.IsAbstract) continue;
                bool ok = Supported(m);
                var attrs = (m.IsPublic ? MethodAttributes.Public : MethodAttributes.Family) |
                            MethodAttributes.Virtual | MethodAttributes.HideBySig | MethodAttributes.ReuseSlot;
                if (m.IsSpecialName) attrs |= MethodAttributes.SpecialName;
                var sig = DefineLike(tb, m.Name, attrs, m);
                string what = $"{rexxClass}~{rn ?? m.Name} ({Types.Display(baseType)}.{m.Name})";
                if (mine && ok)
                {
                    Body(sig, m, NewSlot(info, rn!, m, what), !m.IsAbstract, $"{Types.Display(baseType)}.{m.Name}: no Rexx peer to call");
                    if (!m.IsAbstract)
                    {
                        var tr = Trampoline(tb, m);
                        if (!info.Bases.TryGetValue(rn!, out var list)) info.Bases[rn!] = list = new();
                        list.Add(tr);
                    }
                }
                else Throw(sig.Builder.GetILGenerator(), mine
                    ? $"{what}: pointer or span parameters, or a result by reference, are not supported"
                    : $"{rexxClass} does not define {rn ?? m.Name}, which the abstract {Types.Display(baseType)}.{m.Name} needs");
            }

            // The interfaces' events: a field holding the handlers, and add /
            // remove as C#'s field-like events have them (public, so that
            // Rexx's o~Name += h finds the event too); raise.Name raises it.
            var eventAccessors = new HashSet<MethodInfo>();
            var publicEvents = new HashSet<string>(StringComparer.Ordinal);
            foreach (var i in closure)
                foreach (var ev in i.GetEvents())
                {
                    if (ev.AddMethod == null || ev.RemoveMethod == null || !ev.AddMethod.IsAbstract) continue;
                    var ht = ev.EventHandlerType!;
                    bool open = publicEvents.Add(ev.Name);         // a second event of the same name: explicit
                    var fb = tb.DefineField("<event>" + i.FullName + "." + ev.Name, typeof(Delegate), FieldAttributes.Private);
                    var attrs = (open ? MethodAttributes.Public : MethodAttributes.Private) | MethodAttributes.Virtual |
                                MethodAttributes.Final | MethodAttributes.HideBySig | MethodAttributes.NewSlot | MethodAttributes.SpecialName;
                    string prefix = open ? "" : i.FullName + ".";
                    var add = Accessor(tb, prefix + "add_" + ev.Name, attrs, ht, fb, combine);
                    var remove = Accessor(tb, prefix + "remove_" + ev.Name, attrs, ht, fb, removeHandler);
                    tb.DefineMethodOverride(add, ev.AddMethod);
                    tb.DefineMethodOverride(remove, ev.RemoveMethod);
                    var eb = tb.DefineEvent(prefix + ev.Name, EventAttributes.None, ht);
                    eb.SetAddOnMethod(add);
                    eb.SetRemoveOnMethod(remove);
                    eventAccessors.Add(ev.AddMethod);
                    eventAccessors.Add(ev.RemoveMethod);
                    if (!info.Events.ContainsKey(ev.Name)) info.Events[ev.Name] = fb.Name;
                }

            // The interfaces' members: explicit implementations.
            foreach (var i in closure)
                foreach (var m in i.GetMethods(BindingFlags.Instance | BindingFlags.Public))
                {
                    if (eventAccessors.Contains(m)) continue;
                    var rn = RexxName(m);
                    bool evt = m.IsSpecialName && (m.Name.StartsWith("add_") || m.Name.StartsWith("remove_"));
                    bool mine = rn != null && rexxNames.Contains(rn) && !evt;
                    if (!mine && !m.IsAbstract) continue;           // a default implementation: kept
                    bool ok = Supported(m);
                    var sig = DefineLike(tb, i.FullName + "." + m.Name,
                        MethodAttributes.Private | MethodAttributes.Virtual | MethodAttributes.Final |
                        MethodAttributes.HideBySig | MethodAttributes.NewSlot, m);
                    tb.DefineMethodOverride(sig.Builder, m);
                    string what = $"{rexxClass}~{rn ?? m.Name} ({Types.Display(i)}.{m.Name})";
                    if (mine && ok)
                        Body(sig, m, NewSlot(info, rn!, m, what), false, $"{Types.Display(i)}.{m.Name}: no Rexx peer to call");
                    else Throw(sig.Builder.GetILGenerator(), evt ? $"{Types.Display(i)}.{m.Name}: this event's accessors are not supported"
                        : mine ? $"{what}: pointer or span parameters, or a result by reference, are not supported"
                        : $"{rexxClass} does not define {rn ?? m.Name}, which {Types.Display(i)} needs");
                }

            created = tb.CreateType()!;
            types.AddOrUpdate(created, info);
        }

        var all = new Writer();
        Conv.AddObject(all, StaticOf.For(created));
        var prot = new Writer();
        foreach (var n in ProtectedNames(baseType)) prot.Add('S', n);
        all.Add('A', prot.ToArray());
        var bases = new Writer();
        foreach (var n in info.Bases.Keys) bases.Add('S', n);
        all.Add('A', bases.ToArray());
        var events = new Writer();
        foreach (var n in info.Events.Keys) events.Add('S', n.ToUpperInvariant());
        all.Add('A', events.ToArray());
        w.Add('A', all.ToArray());
    }

    static string Clean(string s) => new string(s.Select(c => char.IsLetterOrDigit(c) ? c : '_').ToArray());

    // A generic method's own type parameters are fine, unless one may be a
    // ref struct ("allows ref struct", .NET 9: it could not be boxed for Rexx).
    const GenericParameterAttributes AllowByRefLike = (GenericParameterAttributes)0x20;

    static bool Unsupported(Type t) => t.IsByRef || t.IsPointer || t.IsByRefLike ||
        (t.IsGenericParameter && t.DeclaringMethod == null);

    // A parameter: by reference too (ref / out: a ComRef for the Rexx method), but no pointer or span
    static bool UnsupportedParameter(Type t) => t.IsByRef ? Unsupported(t.GetElementType()!) : Unsupported(t);

    static bool Supported(MethodInfo m) =>
        !m.GetParameters().Any(p => UnsupportedParameter(p.ParameterType)) && !Unsupported(m.ReturnType) &&
        !(m.IsGenericMethodDefinition && m.GetGenericArguments().Any(g => (g.GenericParameterAttributes & AllowByRefLike) != 0));

    static int NewSlot(Info info, string name, MethodInfo m, string what)
    {
        info.Slots.Add(new Slot(name, m.ReturnType, what, m.IsGenericMethodDefinition ? m : null));
        return info.Slots.Count - 1;
    }

    // A method of the new type with m's signature: for a generic method, its
    // own type parameters (same names, same constraints) and the signature
    // in terms of them.
    sealed record Signature(MethodBuilder Builder, Type[] Params, Type Ret, Type[] TypeParams);

    static Signature DefineLike(TypeBuilder tb, string name, MethodAttributes attrs, MethodInfo m)
    {
        var mb = tb.DefineMethod(name, attrs, CallingConventions.HasThis);
        Type[] gps = Type.EmptyTypes;
        if (m.IsGenericMethodDefinition)
        {
            var orig = m.GetGenericArguments();
            var made = mb.DefineGenericParameters(orig.Select(g => g.Name).ToArray());
            gps = made;
            for (int i = 0; i < orig.Length; i++)
            {
                made[i].SetGenericParameterAttributes(orig[i].GenericParameterAttributes);
                var cs = orig[i].GetGenericParameterConstraints().Select(c => Map(c, gps)).ToList();
                var cls = cs.FirstOrDefault(c => !c.IsInterface && !c.IsGenericParameter);
                if (cls != null) made[i].SetBaseTypeConstraint(cls);
                var others = cs.Where(c => c != cls).ToArray();
                if (others.Length > 0) made[i].SetInterfaceConstraints(others);
            }
        }
        var ps = m.GetParameters().Select(p => Map(p.ParameterType, gps)).ToArray();
        var ret = Map(m.ReturnType, gps);
        mb.SetReturnType(ret);
        mb.SetParameters(ps);
        var pars = m.GetParameters();
        for (int i = 0; i < pars.Length; i++) mb.DefineParameter(i + 1, pars[i].Attributes & (ParameterAttributes.In | ParameterAttributes.Out), pars[i].Name);
        return new Signature(mb, ps, ret, gps);
    }

    // t with a generic method's type parameters replaced by gps (by position)
    static Type Map(Type t, Type[] gps)
    {
        if (gps.Length == 0) return t;
        if (t.IsGenericParameter) return t.DeclaringMethod != null ? gps[t.GenericParameterPosition] : t;
        if (t.HasElementType)
        {
            var e = Map(t.GetElementType()!, gps);
            return t.IsByRef ? e.MakeByRefType() : t.IsPointer ? e.MakePointerType()
                 : t.IsSZArray ? e.MakeArrayType() : e.MakeArrayType(t.GetArrayRank());
        }
        if (t.IsGenericType && t.ContainsGenericParameters)
            return t.GetGenericTypeDefinition().MakeGenericType(t.GetGenericArguments().Select(a => Map(a, gps)).ToArray());
        return t;
    }

    // Must a value of t (m's own, unmapped) be boxed? A value type, or a type parameter (a no-op for a reference type).
    static bool Boxed(Type t) => t.IsValueType || t.IsGenericParameter;

    // The virtual members a subclass in another assembly can override: the
    // most derived of each, public or protected, not sealed (generic methods
    // too); no Finalize, no event accessors.
    static IEnumerable<MethodInfo> Virtuals(Type t) =>
        t.GetMethods(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic)
         .Where(m => m.IsVirtual && !m.IsFinal && (m.IsPublic || m.IsFamily || m.IsFamilyOrAssembly))
         .Where(m => !(m.Name == "Finalize" && m.GetParameters().Length == 0))
         .Where(m => !(m.IsSpecialName && (m.Name.StartsWith("add_") || m.Name.StartsWith("remove_") || m.Name.StartsWith("raise_"))) || m.IsAbstract);

    // The Rexx method for a member: its name; a property's getter: the
    // property's name; its setter: the name and "=" (as Rexx sends o~Name = v).
    static string? RexxName(MethodInfo m)
    {
        if (m.IsSpecialName)
        {
            if (m.Name.StartsWith("get_")) return m.Name.Substring(4).ToUpperInvariant();
            if (m.Name.StartsWith("set_")) return m.Name.Substring(4).ToUpperInvariant() + "=";
            if (m.Name.StartsWith("add_") || m.Name.StartsWith("remove_")) return null;
        }
        return m.Name.ToUpperInvariant();
    }

    // object r = Extend.Dispatch(this, slot, new object[] { args... });
    // if (r != Extend.NoPeer) return (R)r;
    // return base.M(args...);    or    throw new NotImplementedException(...)
    // object r = Extend.Dispatch(this, slot, new object[] { args... });
    // if (r != Extend.NoPeer) { (ref / out parameters: their ComRefs' values back) return (R)r; }
    // return base.M(args...);    or    throw new NotImplementedException(...)
    // A parameter by reference goes as a ComRef holding its value (an out
    // parameter's: none); what the Rexx method leaves in its Value goes back.
    // A generic method's override passes its type arguments (typeof(T)...) to DispatchGeneric.
    static void Body(Signature sig, MethodInfo m, int slot, bool callBase, string noPeerMessage)
    {
        var il = sig.Builder.GetILGenerator();
        var pars = m.GetParameters();
        var ps = sig.Params;
        var ret = sig.Ret;
        var r = il.DeclareLocal(typeof(object));
        var refs = new LocalBuilder?[ps.Length];
        for (int i = 0; i < ps.Length; i++)
        {
            if (!ps[i].IsByRef) continue;
            var et = ps[i].GetElementType()!;
            refs[i] = il.DeclareLocal(typeof(ComRef));
            if (pars[i].IsOut && !pars[i].IsIn) il.Emit(OpCodes.Ldnull);
            else
            {
                il.Emit(OpCodes.Ldarg, (short)(i + 1));
                il.Emit(OpCodes.Ldobj, et);
                if (Boxed(pars[i].ParameterType.GetElementType()!)) il.Emit(OpCodes.Box, et);
            }
            il.Emit(OpCodes.Call, newRef);
            il.Emit(OpCodes.Stloc, refs[i]!);
        }
        var fallback = il.DefineLabel();
        il.Emit(OpCodes.Ldarg_0);
        il.Emit(OpCodes.Ldc_I4, slot);
        il.Emit(OpCodes.Ldc_I4, ps.Length);
        il.Emit(OpCodes.Newarr, typeof(object));
        for (int i = 0; i < ps.Length; i++)
        {
            il.Emit(OpCodes.Dup);
            il.Emit(OpCodes.Ldc_I4, i);
            if (refs[i] != null) il.Emit(OpCodes.Ldloc, refs[i]!);
            else
            {
                il.Emit(OpCodes.Ldarg, (short)(i + 1));
                if (Boxed(pars[i].ParameterType)) il.Emit(OpCodes.Box, ps[i]);
            }
            il.Emit(OpCodes.Stelem_Ref);
        }
        if (sig.TypeParams.Length > 0)
        {
            il.Emit(OpCodes.Ldc_I4, sig.TypeParams.Length);
            il.Emit(OpCodes.Newarr, typeof(Type));
            for (int i = 0; i < sig.TypeParams.Length; i++)
            {
                il.Emit(OpCodes.Dup);
                il.Emit(OpCodes.Ldc_I4, i);
                il.Emit(OpCodes.Ldtoken, sig.TypeParams[i]);
                il.Emit(OpCodes.Call, typeFromHandle);
                il.Emit(OpCodes.Stelem_Ref);
            }
            il.Emit(OpCodes.Call, dispatchGeneric);
        }
        else il.Emit(OpCodes.Call, dispatch);
        il.Emit(OpCodes.Stloc, r);
        il.Emit(OpCodes.Ldloc, r);
        il.Emit(OpCodes.Ldsfld, noPeer);
        il.Emit(OpCodes.Beq, fallback);
        for (int i = 0; i < ps.Length; i++)
        {
            if (refs[i] == null) continue;
            var et = ps[i].GetElementType()!;
            il.Emit(OpCodes.Ldarg, (short)(i + 1));
            il.Emit(OpCodes.Ldloc, refs[i]!);
            il.Emit(OpCodes.Ldtoken, et);
            il.Emit(OpCodes.Call, typeFromHandle);
            il.Emit(OpCodes.Call, fromRef);
            il.Emit(OpCodes.Unbox_Any, et);
            il.Emit(OpCodes.Stobj, et);
        }
        if (ret != typeof(void))
        {
            il.Emit(OpCodes.Ldloc, r);
            il.Emit(OpCodes.Unbox_Any, ret);
        }
        il.Emit(OpCodes.Ret);
        il.MarkLabel(fallback);
        if (callBase)
        {
            il.Emit(OpCodes.Ldarg_0);
            for (int i = 0; i < ps.Length; i++) il.Emit(OpCodes.Ldarg, (short)(i + 1));
            il.Emit(OpCodes.Call, Instance(m, sig));        // non-virtual: the base's own
            il.Emit(OpCodes.Ret);
        }
        else
        {
            il.Emit(OpCodes.Ldstr, noPeerMessage);
            il.Emit(OpCodes.Newobj, typeof(NotImplementedException).GetConstructor(new[] { typeof(string) })!);
            il.Emit(OpCodes.Throw);
        }
    }

    // m itself, or, generic, instantiated with sig's type parameters (m<T...>)
    static MethodInfo Instance(MethodInfo m, Signature sig) =>
        sig.TypeParams.Length == 0 ? m : m.MakeGenericMethod(sig.TypeParams);

    static readonly MethodInfo dispatchGeneric = typeof(Extend).GetMethod(nameof(DispatchGeneric))!;
    static readonly MethodInfo newRef = typeof(Extend).GetMethod(nameof(NewRef))!;
    static readonly MethodInfo fromRef = typeof(Extend).GetMethod(nameof(FromRef))!;
    static readonly MethodInfo typeFromHandle = typeof(Type).GetMethod(nameof(Type.GetTypeFromHandle))!;

    /// A parameter by reference, for the Rexx method. Public for the emitted code only.
    [EditorBrowsable(EditorBrowsableState.Never)]
    public static ComRef NewRef(object? value) => new ComRef(value);

    /// What the Rexx method left in a ComRef, as the parameter's type (a Rexx
    /// string converted as any argument: "42" for an int). Public for the emitted code only.
    [EditorBrowsable(EditorBrowsableState.Never)]
    public static object? FromRef(ComRef r, Type t)
    {
        var v = r.Value;
        if (v == null) return t.IsValueType ? Activator.CreateInstance(t) : null;
        if (t.IsInstanceOfType(v)) return v;
        if (v is string s && Conv.TryConvert(new Rec { Tag = 'S', Text = s }, t, out var c) != Conv.Fail) return c;
        if (v is IConvertible && typeof(IConvertible).IsAssignableFrom(t))
            return System.Convert.ChangeType(v, t, System.Globalization.CultureInfo.InvariantCulture);
        throw new InvalidCastException($"a parameter by reference of type {Types.Display(t)} cannot take \"{v}\"");
    }

    static readonly MethodInfo combine = typeof(Extend).GetMethod(nameof(AddHandler))!;
    static readonly MethodInfo removeHandler = typeof(Extend).GetMethod(nameof(RemoveHandler))!;

    // add_Name / remove_Name: Extend.AddHandler(ref this.field, value)
    static MethodBuilder Accessor(TypeBuilder tb, string name, MethodAttributes attrs, Type handlerType, FieldInfo field, MethodInfo helper)
    {
        var mb = tb.DefineMethod(name, attrs, typeof(void), new[] { handlerType });
        var il = mb.GetILGenerator();
        il.Emit(OpCodes.Ldarg_0);
        il.Emit(OpCodes.Ldflda, field);
        il.Emit(OpCodes.Ldarg_1);
        il.Emit(OpCodes.Call, helper);
        il.Emit(OpCodes.Ret);
        return mb;
    }

    /// The bodies of the events' accessors, as C#'s field-like events
    /// (thread-safe). Public for the emitted code only.
    [EditorBrowsable(EditorBrowsableState.Never)]
    public static void AddHandler(ref Delegate? field, Delegate? value)
    {
        Delegate? seen = field, now;
        do { now = seen; seen = Interlocked.CompareExchange(ref field, Delegate.Combine(now, value), now); } while (seen != now);
    }

    [EditorBrowsable(EditorBrowsableState.Never)]
    public static void RemoveHandler(ref Delegate? field, Delegate? value)
    {
        Delegate? seen = field, now;
        do { now = seen; seen = Interlocked.CompareExchange(ref field, Delegate.Remove(now, value), now); } while (seen != now);
    }

    /// self~raise.Name(args): the event's handlers called, in order, with
    /// args converted to its delegate's parameters (none: nothing happens).
    public static void Raise(Rec target, string name, List<Rec> args, Writer w)
    {
        object o;
        Info info;
        lock (gate) { o = Instance(target); types.TryGetValue(o.GetType(), out info!); }
        if (!info.Events.TryGetValue(name, out var fieldName))
            throw new BridgeException($"raise.{name}: {info.RexxClass} has no event {name} of an interface");
        var f = o.GetType().GetField(fieldName, BindingFlags.Instance | BindingFlags.NonPublic)!;
        if (f.GetValue(o) is not Delegate d) { w.Add('V', ""); return; }
        var inv = d.GetType().GetMethod("Invoke")!;
        var (_, conv) = Members.Choose(new[] { inv }, args, $"raise.{name}");
        try { d.DynamicInvoke(conv); }
        catch (TargetInvocationException e) when (e.InnerException != null)
        {
            System.Runtime.ExceptionServices.ExceptionDispatchInfo.Capture(e.InnerException).Throw();
        }
        w.Add('V', "");
    }

    static void Throw(ILGenerator il, string message)
    {
        il.Emit(OpCodes.Ldstr, message);
        il.Emit(OpCodes.Newobj, typeof(NotImplementedException).GetConstructor(new[] { typeof(string) })!);
        il.Emit(OpCodes.Throw);
    }

    // A private method calling the base implementation non-virtually (for
    // base.Name): its name, "<base>" and the member's.
    static string Trampoline(TypeBuilder tb, MethodInfo m)
    {
        var name = "<base>" + m.Name;
        var sig = DefineLike(tb, name, MethodAttributes.Private | MethodAttributes.HideBySig, m);
        var il = sig.Builder.GetILGenerator();
        il.Emit(OpCodes.Ldarg_0);
        for (int i = 0; i < sig.Params.Length; i++) il.Emit(OpCodes.Ldarg, (short)(i + 1));
        il.Emit(OpCodes.Call, Instance(m, sig));
        il.Emit(OpCodes.Ret);
        return name;
    }

    // ------------------------------------------------------ protected members

    const BindingFlags Any = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance |
                             BindingFlags.Static | BindingFlags.FlattenHierarchy;

    static bool Protected(MemberInfo m) => m switch
    {
        MethodBase mb => mb.IsFamily || mb.IsFamilyOrAssembly,
        FieldInfo f => f.IsFamily || f.IsFamilyOrAssembly,
        PropertyInfo p => p.GetAccessors(true).Any(a => a.IsFamily || a.IsFamilyOrAssembly),
        _ => false,
    };

    static bool Reachable(MemberInfo m) => m switch
    {
        MethodBase mb => mb.IsPublic || mb.IsFamily || mb.IsFamilyOrAssembly,
        FieldInfo f => f.IsPublic || f.IsFamily || f.IsFamilyOrAssembly,
        PropertyInfo p => p.GetAccessors(true).Any(a => a.IsPublic || a.IsFamily || a.IsFamilyOrAssembly),
        _ => false,
    };

    // The Rexx names of the base's protected members (methods, properties,
    // fields): Name, and Name= for those that can be set.
    static IEnumerable<string> ProtectedNames(Type t)
    {
        var names = new SortedSet<string>(StringComparer.Ordinal);
        foreach (var m in t.GetMembers(Any).Where(Protected))
        {
            switch (m)
            {
                case MethodInfo mi when !mi.IsSpecialName && mi.Name != "Finalize" && mi.Name != "MemberwiseClone":
                    names.Add(mi.Name.ToUpperInvariant()); break;
                case PropertyInfo p:
                    names.Add(p.Name.ToUpperInvariant());
                    if (p.SetMethod != null) names.Add(p.Name.ToUpperInvariant() + "=");
                    break;
                case FieldInfo f:
                    names.Add(f.Name.ToUpperInvariant());
                    if (!f.IsInitOnly && !f.IsLiteral) names.Add(f.Name.ToUpperInvariant() + "=");
                    break;
            }
        }
        return names;
    }

    static object Instance(Rec r) => Handles.Get(r.Id) is var o && o is not StaticOf && IsExtended(o.GetType()) ? o
        : throw new BridgeException("not an instance of a Rexx class extending a .NET class");

    /// self~Name, self~Name(args), self~Name = v from the object's own
    /// methods: its public and protected members.
    public static void Member(Rec target, string name, List<Rec> args, Writer w)
    {
        object o;
        lock (gate) o = Instance(target);
        var t = o.GetType();
        string display = Types.Display(t.BaseType!);
        bool set = name.EndsWith('=');
        var n = set ? name.Substring(0, name.Length - 1) : name;
        var ms = t.GetMembers(Any).Where(m => m.Name.Equals(n, StringComparison.OrdinalIgnoreCase) && Reachable(m))
                  .Where(m => m is not MethodBase mb || !mb.IsSpecialName).ToList();
        if (ms.Count == 0) throw new NoMemberException(name, $"{display} has no public or protected member \"{n}\"");
        var prop = ms.OfType<PropertyInfo>().FirstOrDefault(p => p.GetIndexParameters().Length == 0);
        var field = ms.OfType<FieldInfo>().FirstOrDefault();
        if (set)
        {
            if (args.Count != 1) throw new BridgeException($"{n} of {display}: one value to set");
            Type to = prop?.PropertyType ?? field?.FieldType ?? throw new BridgeException($"{n} of {display} is not a property or field");
            if (prop != null && (prop.GetSetMethod(true) is not MethodInfo sm || !Reachable(sm)))
                throw new BridgeException($"{n} of {display} cannot be set");
            if (field != null && prop == null && (field.IsInitOnly || field.IsLiteral)) throw new BridgeException($"{n} of {display} is read-only");
            if (Conv.TryConvert(args[0], to, out var v) == Conv.Fail)
                throw new BridgeException($"cannot set {n} ({Types.Display(to)}) to \"{Conv.Describe(args[0])}\"");
            if (prop != null) prop.SetValue(o, v); else field!.SetValue(o, v);
            w.Add('V', "");
            return;
        }
        if (args.Count == 0 && prop != null)
        {
            if (prop.GetGetMethod(true) is not MethodInfo gm || !Reachable(gm)) throw new BridgeException($"{n} of {display} cannot be read");
            Conv.ToRexx(w, prop.GetValue(o));
            return;
        }
        if (args.Count == 0 && field != null) { Conv.ToRexx(w, field.GetValue(field.IsStatic ? null : o)); return; }
        var methods = ms.OfType<MethodInfo>().Where(m => !m.ContainsGenericParameters)
                        .Concat(Members.Instantiate(ms.OfType<MethodInfo>().Where(m => m.IsGenericMethodDefinition), args, null))
                        .Concat(ms.OfType<PropertyInfo>().Where(p => p.GetIndexParameters().Length > 0)
                                  .Select(p => p.GetGetMethod(true)).Where(g => g != null && Reachable(g)).Select(g => g!))
                        .ToList();
        if (methods.Count == 0) throw new BridgeException($"{n} of {display} is not a method: it takes no arguments");
        var (mi, conv) = Members.Choose(methods, args, $"{display}.{n}");
        Answer(w, mi.Invoke(mi.IsStatic ? null : o, conv), mi.ReturnType, args, conv);
    }

    // The result; with .NetRef arguments R, the result and then their new values (as Bridge.Send)
    static void Answer(Writer w, object? result, Type ret, List<Rec> args, object?[] conv)
    {
        if (!args.Any(a => a.Tag == 'R')) { Conv.ToRexx(w, result, ret); return; }
        var inner = new Writer();
        Conv.ToRexx(inner, result, ret);
        for (int i = 0; i < args.Count; i++) if (args[i].Tag == 'R') Conv.ToRexx(inner, conv[i]);
        w.Add('R', inner.ToArray());
    }

    /// self~base.Name(args): the base implementation of an overridden member.
    public static void Base(Rec target, string name, List<Rec> args, Writer w)
    {
        object o;
        Info info;
        lock (gate) { o = Instance(target); types.TryGetValue(o.GetType(), out info!); }
        var t = o.GetType();
        if (!info.Bases.TryGetValue(name, out var tramps))
            throw new BridgeException($"base.{name}: {info.RexxClass} overrides no {name} with a base implementation");
        var ms = tramps.Distinct().SelectMany(tn => t.GetMethods(BindingFlags.Instance | BindingFlags.NonPublic).Where(m => m.Name == tn)).ToList();
        string what = $"base.{name} of {Types.Display(t.BaseType!)}";
        // A generic one: its type arguments after the arguments, as its override got them; or inferred
        var given = new List<MethodInfo>();
        int k = 0;
        foreach (var g in ms.Where(m => m.IsGenericMethodDefinition))
        {
            int n = g.GetGenericArguments().Length;
            if (args.Count < n || !args.Skip(args.Count - n).All(IsType)) continue;
            if (g.GetParameters().Length != args.Count - n) continue;
            try { given.Add(g.MakeGenericMethod(args.Skip(args.Count - n).Select(TypeOf).ToArray())); k = n; }
            catch (ArgumentException) { }                   // constraints
        }
        if (given.Count > 0 && given.All(m => m.GetGenericArguments().Length == k))
        {
            var plain = args.Take(args.Count - k).ToList();
            var (gm, gconv) = Members.Choose(given, plain, what);
            Answer(w, gm.Invoke(o, gconv), gm.ReturnType, plain, gconv);
            return;
        }
        var cands = ms.Where(m => !m.IsGenericMethodDefinition)
                      .Concat(Members.Instantiate(ms.Where(m => m.IsGenericMethodDefinition), args, null)).ToList();
        var (mi, conv) = Members.Choose(cands, args, what);
        Answer(w, mi.Invoke(o, conv), mi.ReturnType, args, conv);
    }

    static bool IsType(Rec r) => r.Tag == 'O' && Handles.Get(r.Id) is StaticOf;
    static Type TypeOf(Rec r) => ((StaticOf)Handles.Get(r.Id)).Type;

    // ------------------------------------------------------------- instances

    /// An instance not constructed yet, with its peer: its handle and display.
    public static void Alloc(Rec type, Rec handler, Writer w)
    {
        var t = Handles.Get(type.Id) is StaticOf so ? so.Type : throw new BridgeException("not a type");
        if (!IsExtended(t)) throw new BridgeException($"{Types.Display(t)} was not made by .net~extend");
        var o = RuntimeHelpers.GetUninitializedObject(t);
        GC.SuppressFinalize(o);                             // until its constructor has run
        var p = new Peer(Callbacks.HandlerOf(handler));
        p.Handle = Handles.Add(o);
        peers.AddOrUpdate(o, p);
        w.Add('S', p.Handle + "\t" + Display(t));
    }

    /// Runs the constructor that fits args on the instance.
    public static void Init(Rec target, List<Rec> args, Writer w)
    {
        object o;
        lock (gate) o = Instance(target);
        var t = o.GetType();
        var (c, conv) = Members.Choose(t.GetConstructors(), args, $"new {Display(t)}");
        c.Invoke(o, conv);
        GC.ReRegisterForFinalize(o);
        w.Add('V', "");
    }

    /// Its construction failed, or its interpreter instance ended: no pair
    /// (its handle goes as any proxy's). Nothing if its object is gone.
    public static void Abandon(Rec target)
    {
        object o;
        try { lock (gate) o = Instance(target); }
        catch (BridgeException) { return; }
        if (peers.TryGetValue(o, out var p)) { Callbacks.Release(p.H.Id); Callbacks.Forget(p.H.Id); }
        peers.Remove(o);
    }

    /// The name Rexx shows: the Rexx class's, and what it extends.
    public static string Display(Type t)
    {
        if (t.IsCollectible && types.TryGetValue(t, out var info)) return info.Shown;
        return Types.Display(t);
    }
}
