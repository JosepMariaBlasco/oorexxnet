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
// NotImplementedException. A virtual member whose peer is gone (.net~detach)
// runs the base implementation again.
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
// Operations (Bridge.Dispatch):
//   extend    S class name, A [S name | O type]..., A [S Rexx method names]
//             -> A [O the new type, A protected member names, A base. names]
//   extAlloc  O type, H peer handler   -> S "id\tdisplay" (not constructed yet)
//   extInit   O object, A args         -> V (its constructor, chosen by the args)
//   extMember O object, S name, A args -> the result ("Name=": a set)
//   extBase   O object, S name, A args -> the result
//   extDetach O object                 -> V
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.CompilerServices;

namespace Rexx.Net;

public static class Extend
{
    /// What Dispatch answers when there is no Rexx peer to call (the
    /// override then runs the base implementation, or throws).
    [EditorBrowsable(EditorBrowsableState.Never)]
    public static readonly object NoPeer = new();

    sealed record Slot(string Name, Type Ret, string What);

    sealed class Info
    {
        public string RexxClass = "", Shown = "";
        public Dictionary<string, List<string>> Bases = new(StringComparer.OrdinalIgnoreCase);   // Rexx name -> trampolines
    }

    static readonly object gate = new();
    static readonly List<Slot> slots = new();
    static readonly Dictionary<Type, Info> types = new();
    static readonly ConditionalWeakTable<object, RexxHandler> peers = new();
    static ModuleBuilder? module;
    static int serial;

    static readonly MethodInfo dispatch = typeof(Extend).GetMethod(nameof(Dispatch))!;
    static readonly FieldInfo noPeer = typeof(Extend).GetField(nameof(NoPeer))!;

    /// Is t a type made by .net~extend?
    public static bool IsExtended(Type t) { lock (gate) return types.ContainsKey(t); }

    /// The peer handler of an instance, if it has a live one.
    internal static RexxHandler? PeerOf(object o) =>
        peers.TryGetValue(o, out var h) && !h.Released ? h : null;

    /// The body of every override. Public for the emitted code only.
    [EditorBrowsable(EditorBrowsableState.Never)]
    public static object? Dispatch(object self, int slot, object?[] args)
    {
        if (!peers.TryGetValue(self, out var h) || h.Released || !Callbacks.Started) return NoPeer;
        Slot s;
        lock (gate) s = slots[slot];
        var all = new object?[args.Length + 1];
        all[0] = s.Name;
        Array.Copy(args, 0, all, 1, args.Length);
        return Callbacks.Call(h, all, s.Ret, s.What);
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
            module ??= AssemblyBuilder.DefineDynamicAssembly(new AssemblyName("Rexx.Net.Extended"), AssemblyBuilderAccess.Run)
                                      .DefineDynamicModule("Rexx.Net.Extended");
            var name = "Rexx.Extended." + Clean(rexxClass) + "_" + (++serial);
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
                var ps = m.GetParameters().Select(p => p.ParameterType).ToArray();
                bool ok = !ps.Any(Unsupported) && !Unsupported(m.ReturnType);
                var attrs = (m.IsPublic ? MethodAttributes.Public : MethodAttributes.Family) |
                            MethodAttributes.Virtual | MethodAttributes.HideBySig | MethodAttributes.ReuseSlot;
                if (m.IsSpecialName) attrs |= MethodAttributes.SpecialName;
                var mb = tb.DefineMethod(m.Name, attrs, m.ReturnType, ps);
                string what = $"{rexxClass}~{rn ?? m.Name} ({Types.Display(baseType)}.{m.Name})";
                MethodInfo? baseCall = m.IsAbstract ? null : m;
                if (mine && ok)
                {
                    Body(mb.GetILGenerator(), NewSlot(rn!, m.ReturnType, what), ps, m.ReturnType, baseCall,
                         $"{Types.Display(baseType)}.{m.Name}: no Rexx peer to call");
                    if (baseCall != null)
                    {
                        var tr = Trampoline(tb, m, ps);
                        if (!info.Bases.TryGetValue(rn!, out var list)) info.Bases[rn!] = list = new();
                        list.Add(tr);
                    }
                }
                else Throw(mb.GetILGenerator(), mine
                    ? $"{what}: ref, out, pointer or span parameters are not supported"
                    : $"{rexxClass} does not define {rn ?? m.Name}, which the abstract {Types.Display(baseType)}.{m.Name} needs");
            }

            // The interfaces' members: explicit implementations.
            foreach (var i in closure)
                foreach (var m in i.GetMethods(BindingFlags.Instance | BindingFlags.Public))
                {
                    var rn = RexxName(m);
                    bool evt = m.IsSpecialName && (m.Name.StartsWith("add_") || m.Name.StartsWith("remove_"));
                    bool mine = rn != null && rexxNames.Contains(rn) && !evt;
                    if (!mine && !m.IsAbstract) continue;           // a default implementation: kept
                    var ps = m.GetParameters().Select(p => p.ParameterType).ToArray();
                    bool ok = !ps.Any(Unsupported) && !Unsupported(m.ReturnType);
                    var mb = tb.DefineMethod(i.FullName + "." + m.Name,
                        MethodAttributes.Private | MethodAttributes.Virtual | MethodAttributes.Final |
                        MethodAttributes.HideBySig | MethodAttributes.NewSlot, m.ReturnType, ps);
                    tb.DefineMethodOverride(mb, m);
                    string what = $"{rexxClass}~{rn ?? m.Name} ({Types.Display(i)}.{m.Name})";
                    if (mine && ok)
                        Body(mb.GetILGenerator(), NewSlot(rn!, m.ReturnType, what), ps, m.ReturnType, null,
                             $"{Types.Display(i)}.{m.Name}: no Rexx peer to call");
                    else Throw(mb.GetILGenerator(), evt ? $"{Types.Display(i)}.{m.Name}: events of an interface are not supported yet"
                        : mine ? $"{what}: ref, out, pointer or span parameters are not supported"
                        : $"{rexxClass} does not define {rn ?? m.Name}, which {Types.Display(i)} needs");
                }

            created = tb.CreateType()!;
            types[created] = info;
        }

        var all = new Writer();
        Conv.AddObject(all, StaticOf.For(created));
        var prot = new Writer();
        foreach (var n in ProtectedNames(baseType)) prot.Add('S', n);
        all.Add('A', prot.ToArray());
        var bases = new Writer();
        foreach (var n in info.Bases.Keys) bases.Add('S', n);
        all.Add('A', bases.ToArray());
        w.Add('A', all.ToArray());
    }

    static string Clean(string s) => new string(s.Select(c => char.IsLetterOrDigit(c) ? c : '_').ToArray());

    static bool Unsupported(Type t) => t.IsByRef || t.IsPointer || t.IsByRefLike || t.IsGenericParameter;

    static int NewSlot(string name, Type ret, string what)
    {
        slots.Add(new Slot(name, ret, what));
        return slots.Count - 1;
    }

    // The virtual members a subclass in another assembly can override: the
    // most derived of each, public or protected, not sealed; no generic
    // methods, no Finalize, no event accessors.
    static IEnumerable<MethodInfo> Virtuals(Type t) =>
        t.GetMethods(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic)
         .Where(m => m.IsVirtual && !m.IsFinal && (m.IsPublic || m.IsFamily || m.IsFamilyOrAssembly))
         .Where(m => !m.IsGenericMethodDefinition && !(m.Name == "Finalize" && m.GetParameters().Length == 0))
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
    static void Body(ILGenerator il, int slot, Type[] ps, Type ret, MethodInfo? baseCall, string noPeerMessage)
    {
        var r = il.DeclareLocal(typeof(object));
        var fallback = il.DefineLabel();
        il.Emit(OpCodes.Ldarg_0);
        il.Emit(OpCodes.Ldc_I4, slot);
        il.Emit(OpCodes.Ldc_I4, ps.Length);
        il.Emit(OpCodes.Newarr, typeof(object));
        for (int i = 0; i < ps.Length; i++)
        {
            il.Emit(OpCodes.Dup);
            il.Emit(OpCodes.Ldc_I4, i);
            il.Emit(OpCodes.Ldarg, (short)(i + 1));
            if (ps[i].IsValueType) il.Emit(OpCodes.Box, ps[i]);
            il.Emit(OpCodes.Stelem_Ref);
        }
        il.Emit(OpCodes.Call, dispatch);
        il.Emit(OpCodes.Stloc, r);
        il.Emit(OpCodes.Ldloc, r);
        il.Emit(OpCodes.Ldsfld, noPeer);
        il.Emit(OpCodes.Beq, fallback);
        if (ret != typeof(void))
        {
            il.Emit(OpCodes.Ldloc, r);
            il.Emit(OpCodes.Unbox_Any, ret);
        }
        il.Emit(OpCodes.Ret);
        il.MarkLabel(fallback);
        if (baseCall != null)
        {
            il.Emit(OpCodes.Ldarg_0);
            for (int i = 0; i < ps.Length; i++) il.Emit(OpCodes.Ldarg, (short)(i + 1));
            il.Emit(OpCodes.Call, baseCall);                // non-virtual: the base's own
            il.Emit(OpCodes.Ret);
        }
        else
        {
            il.Emit(OpCodes.Ldstr, noPeerMessage);
            il.Emit(OpCodes.Newobj, typeof(NotImplementedException).GetConstructor(new[] { typeof(string) })!);
            il.Emit(OpCodes.Throw);
        }
    }

    static void Throw(ILGenerator il, string message)
    {
        il.Emit(OpCodes.Ldstr, message);
        il.Emit(OpCodes.Newobj, typeof(NotImplementedException).GetConstructor(new[] { typeof(string) })!);
        il.Emit(OpCodes.Throw);
    }

    // A private method calling the base implementation non-virtually (for
    // base.Name): its name, "<base>" and the member's.
    static string Trampoline(TypeBuilder tb, MethodInfo m, Type[] ps)
    {
        var name = "<base>" + m.Name;
        var mb = tb.DefineMethod(name, MethodAttributes.Private | MethodAttributes.HideBySig, m.ReturnType, ps);
        var il = mb.GetILGenerator();
        il.Emit(OpCodes.Ldarg_0);
        for (int i = 0; i < ps.Length; i++) il.Emit(OpCodes.Ldarg, (short)(i + 1));
        il.Emit(OpCodes.Call, m);
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

    static object Instance(Rec r) => Handles.Get(r.Id) is var o && o is not StaticOf && types.ContainsKey(o.GetType()) ? o
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
                        .Concat(ms.OfType<PropertyInfo>().Where(p => p.GetIndexParameters().Length > 0)
                                  .Select(p => p.GetGetMethod(true)).Where(g => g != null && Reachable(g)).Select(g => g!))
                        .ToList();
        if (methods.Count == 0) throw new BridgeException($"{n} of {display} is not a method: it takes no arguments");
        var (mi, conv) = Members.Choose(methods, args, $"{display}.{n}");
        Conv.ToRexx(w, mi.Invoke(mi.IsStatic ? null : o, conv), mi.ReturnType);
    }

    /// self~base.Name(args): the base implementation of an overridden member.
    public static void Base(Rec target, string name, List<Rec> args, Writer w)
    {
        object o;
        Info info;
        lock (gate) { o = Instance(target); info = types[o.GetType()]; }
        var t = o.GetType();
        if (!info.Bases.TryGetValue(name, out var tramps))
            throw new BridgeException($"base.{name}: {info.RexxClass} overrides no {name} with a base implementation");
        var ms = tramps.Distinct().SelectMany(tn => t.GetMethods(BindingFlags.Instance | BindingFlags.NonPublic).Where(m => m.Name == tn)).ToList();
        var (mi, conv) = Members.Choose(ms, args, $"base.{name} of {Types.Display(t.BaseType!)}");
        Conv.ToRexx(w, mi.Invoke(o, conv), mi.ReturnType);
    }

    // ------------------------------------------------------------- instances

    /// An instance not constructed yet, with its peer: its handle and display.
    public static void Alloc(Rec type, Rec handler, Writer w)
    {
        var t = Handles.Get(type.Id) is StaticOf so ? so.Type : throw new BridgeException("not a type");
        lock (gate) if (!types.ContainsKey(t)) throw new BridgeException($"{Types.Display(t)} was not made by .net~extend");
        var o = RuntimeHelpers.GetUninitializedObject(t);
        GC.SuppressFinalize(o);                             // until its constructor has run
        peers.AddOrUpdate(o, Callbacks.HandlerOf(handler));
        w.Add('S', Handles.Add(o) + "\t" + Display(t));
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

    public static void Detach(Rec target)
    {
        lock (gate) peers.Remove(Instance(target));
    }

    /// The name Rexx shows: the Rexx class's, and what it extends.
    public static string Display(Type t)
    {
        Info? info;
        lock (gate) types.TryGetValue(t, out info);
        return info?.Shown ?? Types.Display(t);
    }
}
