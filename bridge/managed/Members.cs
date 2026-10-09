// Members by name (notes/netobject-design.md, Name resolution and Overloads).
// Public members only: instance members of an object's runtime type, static
// members of a type (inherited ones included). Caseless, cached per
// (type, static, name). If several spellings match, the one starting in
// uppercase wins (.NET's public convention); still several: an error naming
// them. Overloads: every candidate whose parameters accept the arguments
// (Conv.TryConvert), the lowest total cost wins; a tie is an error naming
// the tied signatures.
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace Rexx.Net;

/// The members of one name: methods (the overloads), a property (several if
/// indexed), a field, an event.
public sealed class MemberSet
{
    public string Name = "";
    public MethodInfo[] Methods = Array.Empty<MethodInfo>();
    public MethodInfo[] Generic = Array.Empty<MethodInfo>();       // generic method definitions
    public PropertyInfo[] Properties = Array.Empty<PropertyInfo>();
    public FieldInfo? Field;
    public EventInfo? Event;
    public bool IsEmpty => Methods.Length == 0 && Generic.Length == 0 && Properties.Length == 0 && Field == null && Event == null;
}

public static class Members
{
    static readonly ConcurrentDictionary<(Type, bool, string, bool), MemberSet?> cache = new();

    /// The members named `name` (caselessly unless exact), or null.
    public static MemberSet? Find(Type t, bool isStatic, string name, bool exact) =>
        cache.GetOrAdd((t, isStatic, exact ? name : name.ToUpperInvariant(), exact), k => Lookup(k.Item1, k.Item2, name, k.Item4));

    static MemberSet? Lookup(Type t, bool isStatic, string name, bool exact)
    {
        var flags = BindingFlags.Public | (isStatic ? BindingFlags.Static | BindingFlags.FlattenHierarchy : BindingFlags.Instance);
        var cmp = exact ? StringComparison.Ordinal : StringComparison.OrdinalIgnoreCase;
        var all = AllMembers(t, flags)
            .Where(m => m.Name.Equals(name, cmp))
            .Where(m => m is not MethodBase mb || !mb.IsSpecialName)       // get_X, add_X, op_X: through their member
            .ToList();
        if (all.Count == 0) return null;
        var names = all.Select(m => m.Name).Distinct(StringComparer.Ordinal).ToList();
        if (names.Count > 1)
        {
            var upper = names.Where(n => char.IsUpper(n[0])).ToList();
            if (upper.Count != 1)
                throw new BridgeException($"\"{name}\" is ambiguous in {Types.Display(t)}: {string.Join(", ", names)}" +
                                          " (use .net~invoke, .net~get or .net~set with the exact name)");
            all = all.Where(m => m.Name == upper[0]).ToList();
        }
        var set = new MemberSet { Name = all[0].Name };
        set.Methods = MostDerived(all.OfType<MethodInfo>().Where(m => !m.ContainsGenericParameters)).ToArray();
        set.Generic = MostDerived(all.OfType<MethodInfo>().Where(m => m.IsGenericMethodDefinition)).ToArray();
        set.Properties = all.OfType<PropertyInfo>().ToArray();
        set.Field = all.OfType<FieldInfo>().FirstOrDefault();
        set.Event = all.OfType<EventInfo>().FirstOrDefault();
        return set;
    }

    // Interfaces' members too, when t is an interface (GetMembers leaves out
    // the members of the interfaces it extends). An object whose runtime type
    // is not public (a compiler-made iterator, an internal implementation)
    // shows what C# could use: the members of its nearest public base class
    // and of its public interfaces (explicit implementations included).
    static IEnumerable<MemberInfo> AllMembers(Type t, BindingFlags flags)
    {
        if (!t.IsVisible && (flags & BindingFlags.Instance) != 0)
        {
            var b = t.BaseType;
            while (b != null && !b.IsVisible) b = b.BaseType;
            IEnumerable<MemberInfo> vs = b?.GetMembers(flags) ?? Array.Empty<MemberInfo>();
            foreach (var i in t.GetInterfaces().Where(i => i.IsVisible)) vs = vs.Concat(i.GetMembers(flags));
            return vs;
        }
        IEnumerable<MemberInfo> ms = t.GetMembers(flags);
        if (t.IsInterface && (flags & BindingFlags.Instance) != 0)
            foreach (var i in t.GetInterfaces()) ms = ms.Concat(i.GetMembers(flags));
        return ms;
    }

    // ---------------------------------------------------------- generic methods

    /// Generic method definitions made concrete: with the type arguments
    /// given (Name<int>), or inferred from the arguments as C# does, simply:
    /// a .NET object gives its runtime type, a forced value its forced type,
    /// a Rexx string System.String (.net~int32(x) for an int), a Rexx Array
    /// its items' common type (else object); .nil gives nothing. A definition
    /// whose type arguments cannot all be inferred, or whose constraints fail,
    /// is not a candidate.
    public static IEnumerable<MethodInfo> Instantiate(IEnumerable<MethodInfo> defs, List<Rec> args, Type[]? given)
    {
        foreach (var d in defs)
        {
            var gps = d.GetGenericArguments();
            Type[]? targs = given;
            if (targs != null) { if (targs.Length != gps.Length) continue; }
            else
            {
                var map = new Dictionary<Type, Type>();
                var ps = d.GetParameters();
                for (int i = 0; i < ps.Length && i < args.Count; i++)
                {
                    var pt = ps[i].ParameterType;
                    if (i == ps.Length - 1 && pt.IsArray && ps[i].IsDefined(typeof(ParamArrayAttribute), false) &&
                        !(args.Count == ps.Length && args[i].Tag == 'A'))
                    {
                        for (int j = i; j < args.Count; j++) Unify(pt.GetElementType()!, TypeOf(args[j]), map);
                        break;
                    }
                    Unify(pt, TypeOf(args[i]), map);
                }
                if (!gps.All(map.ContainsKey)) continue;
                targs = gps.Select(g => map[g]).ToArray();
            }
            MethodInfo? m = null;
            try { m = d.MakeGenericMethod(targs); } catch (ArgumentException) { }      // constraints
            if (m != null) yield return m;
        }
    }

    // The .NET type an argument stands for, for inference (null: no information).
    static Type? TypeOf(Rec r)
    {
        switch (r.Tag)
        {
            case 'S': return typeof(string);
            case 'O': { var o = Handles.Get(r.Id); return o is StaticOf ? typeof(Type) : o.GetType(); }
            case 'T':
                if (r.Text == "null") return null;
                return r.Text.StartsWith('#') ? ((StaticOf)Handles.Get(int.Parse(r.Text.Substring(1)))).Type : Types.Parse(r.Text);
            case 'R': return r.Inner == null ? null : TypeOf(r.Inner);
            case 'A':
            {
                var ts = r.Items.Select(TypeOf).Where(t => t != null).Distinct().ToList();
                return (ts.Count == 1 ? ts[0]! : typeof(object)).MakeArrayType();
            }
        }
        return null;
    }

    static void Unify(Type p, Type? a, Dictionary<Type, Type> map)
    {
        if (a == null) return;
        if (p.IsByRef) p = p.GetElementType()!;
        if (p.IsGenericParameter)
        {
            if (!map.TryGetValue(p, out var had)) map[p] = a;
            else if (had != a && had.IsAssignableFrom(a)) { }                     // keep the more general
            else if (had != a && a.IsAssignableFrom(had)) map[p] = a;
            return;
        }
        if (!p.ContainsGenericParameters) return;
        if (p.IsArray) { if (a.IsArray) Unify(p.GetElementType()!, a.GetElementType(), map); else Unify(p.GetElementType()!, ElementOf(a, null), map); return; }
        if (p.IsGenericType)
        {
            var def = p.GetGenericTypeDefinition();
            var match = Closed(a, def);
            if (match == null && a.IsArray && def == typeof(IEnumerable<>)) match = typeof(IEnumerable<>).MakeGenericType(a.GetElementType()!);
            if (match == null) return;
            var pa = p.GetGenericArguments(); var aa = match.GetGenericArguments();
            for (int i = 0; i < pa.Length; i++) Unify(pa[i], aa[i], map);
        }
    }

    static Type? ElementOf(Type a, Type? _) => Closed(a, typeof(IEnumerable<>))?.GetGenericArguments()[0];

    // a, one of its base types or one of its interfaces, as a closed `def`.
    static Type? Closed(Type a, Type def)
    {
        for (var b = a; b != null; b = b.BaseType)
            if (b.IsGenericType && b.GetGenericTypeDefinition() == def) return b;
        return a.GetInterfaces().FirstOrDefault(i => i.IsGenericType && i.GetGenericTypeDefinition() == def);
    }

    static readonly ConcurrentDictionary<Type, PropertyInfo[]> indexers = new();

    /// The public indexers of an object's type (the default member: Item, or
    /// what [IndexerName] calls it, e.g. String's Chars), seen as C# sees them.
    public static PropertyInfo[] Indexers(Type t) => indexers.GetOrAdd(t, x =>
    {
        var all = AllMembers(x, BindingFlags.Public | BindingFlags.Instance).OfType<PropertyInfo>()
                  .Where(p => p.GetIndexParameters().Length > 0).ToList();
        var defaults = new HashSet<string>(StringComparer.Ordinal);
        for (var b = x; b != null; b = b.BaseType) Add(b);
        foreach (var i in x.GetInterfaces()) Add(i);
        var chosen = defaults.Count > 0 ? all.Where(p => defaults.Contains(p.Name)).ToList() : all;
        return chosen.ToArray();
        void Add(Type y)
        {
            foreach (var a in y.GetCustomAttributes(typeof(DefaultMemberAttribute), false))
                defaults.Add(((DefaultMemberAttribute)a).MemberName);
        }
    });

    // A method hidden by one of the same signature in a derived class is left out.
    static IEnumerable<MethodInfo> MostDerived(IEnumerable<MethodInfo> ms)
    {
        var list = ms.ToList();
        return list.Where(m => !list.Any(o => o != m && SameSignature(o, m) &&
                                              o.DeclaringType != m.DeclaringType &&
                                              m.DeclaringType!.IsAssignableFrom(o.DeclaringType)));
    }

    static bool SameSignature(MethodBase a, MethodBase b) =>
        a.GetParameters().Select(p => p.ParameterType).SequenceEqual(b.GetParameters().Select(p => p.ParameterType));

    // ---------------------------------------------------------------- overloads

    /// The parameters of a method or constructor, read once (reflection on
    /// ParameterInfo is slow: IsDefined, HasDefaultValue...).
    public sealed class Sig
    {
        public ParameterInfo[] Params = Array.Empty<ParameterInfo>();
        public Type[] Types = Array.Empty<Type>();
        public bool[] IsOut = Array.Empty<bool>();
        public bool[] HasDefault = Array.Empty<bool>();
        public object?[] Defaults = Array.Empty<object?>();
        public bool HasParams;
        public Type? ParamsElement;
    }

    static readonly ConcurrentDictionary<MethodBase, Sig> sigs = new();

    public static Sig SigOf(MethodBase m) => sigs.GetOrAdd(m, x =>
    {
        var ps = x.GetParameters();
        int n = ps.Length;
        var s = new Sig
        {
            Params = ps, Types = ps.Select(p => p.ParameterType).ToArray(),
            IsOut = ps.Select(p => p.IsOut || p.ParameterType.IsByRef).ToArray(),
            HasDefault = ps.Select(p => p.HasDefaultValue).ToArray(),
            Defaults = ps.Select(p => p.HasDefaultValue ? (p.DefaultValue is DBNull ? Type.Missing : p.DefaultValue) : null).ToArray(),
            HasParams = n > 0 && ps[n - 1].IsDefined(typeof(ParamArrayAttribute), false),
        };
        if (s.HasParams) s.ParamsElement = ps[n - 1].ParameterType.GetElementType();
        return s;
    });

    /// The best of `candidates` for the arguments, with the converted
    /// argument array. Throws if none fits or there is a tie.
    public static (T member, object?[] args) Choose<T>(IEnumerable<T> candidates, List<Rec> args, string what)
        where T : MethodBase
    {
        var fits = new List<(T m, int cost, object?[] conv)>();
        foreach (var c in candidates)
        {
            var (cost, conv) = Fit(SigOf(c), args);
            if (cost != Conv.Fail) fits.Add((c, cost, conv!));
        }
        if (fits.Count == 0)
        {
            var sigs = candidates.Select(c => Signature(c.GetParameters())).ToList();
            throw new BridgeException($"no {what} accepts ({string.Join(", ", args.Select(Conv.Describe))})" +
                                      (sigs.Count > 0 ? "; there are: " + string.Join("; ", sigs) : ""));
        }
        int best = int.MaxValue, count = 0, at = -1;
        for (int i = 0; i < fits.Count; i++)
        {
            if (fits[i].cost < best) { best = fits[i].cost; count = 1; at = i; }
            else if (fits[i].cost == best) count++;
        }
        if (count > 1)
        {
            // The same parameters through two interfaces (IList<T> and IList
            // on an object of a non-public type): the same member in effect;
            // take the one with the more specific result.
            var tied = fits.Where(f => f.cost == best).ToList();
            var plain = tied.Where(f => !(f.m is MethodInfo gm && gm.IsGenericMethod)).ToList();
            if (plain.Count == 1 && plain.Count < tied.Count) return (plain[0].m, plain[0].conv);   // C#: non-generic wins
            var first = SigOf(tied[0].m).Types;
            if (tied.All(f => SigOf(f.m).Types.SequenceEqual(first)))
            {
                var pick = tied.FirstOrDefault(f => f.m is MethodInfo mi && mi.ReturnType != typeof(object));
                return pick.m != null ? (pick.m, pick.conv) : (tied[0].m, tied[0].conv);
            }
            throw new BridgeException($"{what} is ambiguous for ({string.Join(", ", args.Select(Conv.Describe))}): " +
                                      string.Join("; ", fits.Where(f => f.cost == best).Select(w => Signature(w.m.GetParameters()))) +
                                      " (force a type, e.g. .net~int64(x))");
        }
        return (fits[at].m, fits[at].conv);
    }

    // The cost of calling with these parameters, and the converted arguments
    // (optional parameters filled in, a params array expanded if need be).
    static (int, object?[]?) Fit(Sig s, List<Rec> args)
    {
        var ps = s.Types;
        int n = ps.Length;
        bool hasParams = s.HasParams;
        // Normal form.
        if (args.Count <= n)
        {
            var conv = new object?[n];
            int cost = 0;
            bool ok = true;
            for (int i = 0; i < n && ok; i++)
            {
                if (i < args.Count)
                {
                    int c = s.IsOut[i] ? ByRef(s.Params[i], args[i], out conv[i])
                          : args[i].Tag == 'R' ? Conv.Fail
                          : Conv.TryConvert(args[i], ps[i], out conv[i]);
                    if (c == Conv.Fail) ok = false; else cost += c;
                }
                else if (s.HasDefault[i]) conv[i] = s.Defaults[i];
                else if (hasParams && i == n - 1) conv[i] = Array.CreateInstance(s.ParamsElement!, 0);
                else ok = false;
            }
            if (ok) return (cost, conv);
        }
        // Expanded params form.
        if (hasParams && args.Count >= n - 1)
        {
            var conv = new object?[n];
            int cost = 1;
            for (int i = 0; i < n - 1; i++)
            {
                if (s.IsOut[i]) return (Conv.Fail, null);
                int c = Conv.TryConvert(args[i], ps[i], out conv[i]);
                if (c == Conv.Fail) return (Conv.Fail, null);
                cost += c;
            }
            var et = s.ParamsElement!;
            var rest = Array.CreateInstance(et, args.Count - (n - 1));
            for (int i = n - 1; i < args.Count; i++)
            {
                int c = Conv.TryConvert(args[i], et, out var v);
                if (c == Conv.Fail) return (Conv.Fail, null);
                cost += c;
                rest.SetValue(v, i - (n - 1));
            }
            conv[n - 1] = rest;
            return (cost, conv);
        }
        return (Conv.Fail, null);
    }

    // A ref / out / in parameter. ref and out take a .NetRef ('R'): out
    // ignores its value; ref converts it (.nil to a value type: its default).
    // An in parameter (readonly ref) also takes a plain value, as C# does.
    static int ByRef(ParameterInfo p, Rec a, out object? value)
    {
        var et = p.ParameterType.IsByRef ? p.ParameterType.GetElementType()! : p.ParameterType;
        value = null;
        if (a.Tag != 'R') return p.IsIn ? Conv.TryConvert(a, et, out value) : Conv.Fail;
        if (p.IsOut && !p.IsIn) { value = et.IsValueType ? Activator.CreateInstance(et) : null; return 0; }
        if (a.Inner!.Tag == 'N' && et.IsValueType && Nullable.GetUnderlyingType(et) == null)
        { value = Activator.CreateInstance(et); return 0; }
        return Conv.TryConvert(a.Inner, et, out value);
    }

    public static string Signature(ParameterInfo[] ps) =>
        "(" + string.Join(", ", ps.Select(p => (p.IsDefined(typeof(ParamArrayAttribute), false) ? "params " : "") +
                                              (p.ParameterType.IsByRef ? (p.IsOut ? "out " : p.IsIn ? "in " : "ref ") : "") +
                                              Types.Display(p.ParameterType.IsByRef ? p.ParameterType.GetElementType()! : p.ParameterType))) + ")";
}
