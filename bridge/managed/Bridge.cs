// The managed half of the bridge: the native side (rexxnet) sends a request
// (records, Wire.cs) whose first record is the operation, and gets one
// response record back. The handle table, name resolution, overloads and
// conversions live here, where the objects live.
//
// Operations (arguments after the operation's name):
//   send     O target, S name, S exact (1/0), A args   -> the result
//   set      O target, S name, S exact, value          -> V
//   new      O type, A args                            -> O
//   has      O target, S name                          -> S 1/0 (a member by that name?)
//   ns       S prefix, S name                          -> P namespace | O type
//   nsname   S full name                               -> P
//   type     A [S name | O open generic, type args...]  -> O type
//   load     S name or path                            -> S the assembly's full name
//   typeOf   O                                         -> S
//   typeObject O                                       -> O (its System.Type)
//   isInstance O, S name | O type                      -> S 1/0
//   members  O                                         -> A of S
//   count                                              -> S live handles
//   items    O                                         -> A: the items of an IEnumerable (DO OVER)
//   pairs    O                                         -> A [A indexes, A items] (DO WITH INDEX ITEM):
//            IDictionary: keys; arrays and IList: 0-based positions (an
//            array of rank > 1: an Array of positions); else 1..n
//   index    O target, A indices                       -> the element / indexer value: o[i, ...]
//   setIndex O target, value, A indices                -> V: o[i, ...] = value
//   await    O                                         -> the result of a Task / ValueTask (V if none)
//   event    O target, S name, S add|remove, handler    -> V: o~Name += h, o~Name -= h
//   nextEvent S seconds (-1: no limit), S generation (-1: none) -> A [S handler id, A args] | N
//   loopGeneration                                     -> S (for .net~eventLoop)
//   stopLoops                                          -> V (.net~stopEventLoop)
//   releaseHandler S id                                -> V
//   queued                                             -> S calls waiting in the queue
// A send whose member is an event (o~Click) answers e "id\tkind\tdisplay\tname"
// (the target's handle, for a .NetEvent). An exception whose chain holds a
// RexxException from a Rexx callback answers C "conditionId\tmessage":
// rexxnet raises that Rexx condition again. Any other RexxException (Rexx code
// that the .NET code called failed: phase C) is raised again here, on the
// request's thread context, and the answer is K: the condition is pending.
// Each request comes with the calling thread's context: it is pushed as a
// frame (RexxInterpreter.Current), so .NET code called from Rexx calls Rexx
// back on this thread, nested, and receives Rexx objects as RexxObjects (X).
// send's name may give a generic method's type arguments: "Cast<int>".
// A send with .NetRef (R) arguments answers R: its result, then their values.
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;

namespace Rexx.Net;

public static unsafe class Bridge
{
    [UnmanagedCallersOnly]
    public static byte* Request(nint threadContext, byte* req, int len, int* outLen)
    {
        byte[] answer;
        var rexx = RexxInterpreter.ForContext(threadContext);
        rexx.PushFrame(threadContext);
        depth++;
        try { answer = Handle(new ReadOnlySpan<byte>(req, len)); }
        finally { depth--; rexx.PopFrame(threadContext); }
        var p = (byte*)NativeMemory.Alloc((nuint)Math.Max(answer.Length, 1));
        answer.CopyTo(new Span<byte>(p, answer.Length));
        *outLen = answer.Length;
        return p;
    }

    // Rexx -> .NET requests running on this thread: 0 means no Rexx code
    // waits here for .NET (a handler's error is then reported, not thrown).
    [ThreadStatic] static int depth;
    internal static int Depth => depth;

    [UnmanagedCallersOnly]
    public static void Free(byte* p) => NativeMemory.Free(p);

    [UnmanagedCallersOnly]
    public static void Release(int id) => Handles.Release(id);

    /// rexxnet's callback (a Rexx handler's call) and its free.
    [UnmanagedCallersOnly]
    public static void Init(IntPtr callback, IntPtr free) => Callbacks.Init(callback, free);

    /// net.cls's NetObject and NetType classes (global references), from
    /// rexxnet or from a host that loaded net.cls: a .NetObject that reaches
    /// .NET becomes its .NET object again.
    [UnmanagedCallersOnly]
    public static void Classes(nint netObject, nint netType, nint netArray, nint netEnum) =>
        SetClasses(netObject, netType, netArray, netEnum);

    internal static nint NetObjectClass, NetTypeClass, NetArrayClass, NetEnumClass;
    internal static void SetClasses(nint netObject, nint netType, nint netArray, nint netEnum)
    {
        if (NetObjectClass == 0) { NetTypeClass = netType; NetArrayClass = netArray; NetEnumClass = netEnum; NetObjectClass = netObject; }
    }

    public static byte[] Handle(ReadOnlySpan<byte> request)
    {
        var w = new Writer();
        try
        {
            var r = Wire.Parse(request);
            Dispatch(r[0].Text, r, w);
        }
        catch (Exception e)
        {
            if (Callbacks.RexxCause(e) is RexxException re)       // a Rexx error in a callback: raise it again
            {
                w = new Writer();
                w.Add('C', re.ConditionId + "\t" + re.Message);
                return w.ToArray();
            }
            if (RexxException.Raised(e) is RexxException called && RexxInterpreter.RaiseAgain(called))
            {                                                     // Rexx code called by .NET failed: the same error
                w = new Writer();
                w.Add('K', "");
                return w.ToArray();
            }
            while ((e is TargetInvocationException || e is TypeInitializationException) && e.InnerException != null)
                e = e.InnerException;
            if (e is AggregateException ae && ae.InnerExceptions.Count == 1) e = ae.InnerExceptions[0];
            w = new Writer();
            if (e is NoMemberException nm)
                w.Add('U', Handles.Add(nm.Missing) + "\t" + Types.Display(nm.Missing.GetType()) + "\t" + nm.MessageName);
            else if (e is RexxSyntaxException rx) w.Add('Y', rx.Code + "\t" + string.Join("\t", rx.Substitutions));
            else if (e is BridgeException) w.Add('E', "0\t\t" + e.Message);
            else w.Add('E', Handles.Add(e) + "\t" + Types.Display(e.GetType()) + "\t.NET error: " +
                            e.GetType().FullName + ": " + e.Message);
        }
        return w.ToArray();
    }

    static void Dispatch(string op, List<Rec> r, Writer w)
    {
        switch (op)
        {
            // the mode: "0" caseless, "1" exact, "b" caseless in both scopes (CLR.CLS)
            case "send": Send(r[1], r[2].Text, r[3].Text == "1", r[4].Items, w, r[3].Text == "b"); break;
            case "set": Set(r[1], r[2].Text, r[3].Text == "1", r[4], r[3].Text == "b"); w.Add('V', ""); break;
            case "new": New(TypeOf(r[1]), r[2].Items, w); break;
            case "has": w.Add('S', Has(r[1], r[2].Text) ? "1" : "0"); break;
            case "ns":
            {
                var m = Types.NamespaceMember(r[1].Text, r[2].Text);
                if (m is Type t) Conv.AddObject(w, StaticOf.For(t)); else w.Add('P', (string)m);
                break;
            }
            case "nsname": w.Add('P', Types.NamespaceName(r[1].Text)); break;
            case "type": Conv.AddObject(w, StaticOf.For(MakeType(r[1].Items))); break;
            case "load": w.Add('S', Types.Load(r[1].Text).FullName ?? ""); break;
            case "comCreate": Conv.AddObject(w, Com.Create(r[1].Text)); break;
            case "comRelease": Com.Release(Handles.Get(r[1].Id)); w.Add('V', ""); break;
            case "typeOf": w.Add('S', Types.Display(TypeOf(r[1]))); break;
            case "typeObject": Conv.AddObject(w, TypeOf(r[1])); break;
            case "isInstance":
            {
                var t = r[2].Tag == 'S' ? Types.Parse(r[2].Text) : TypeOf(r[2]);
                var o = Handles.Get(r[1].Id);
                w.Add('S', (o is StaticOf so ? t.IsInstanceOfType(so.Type) : t.IsInstanceOfType(o)) ? "1" : "0");
                break;
            }
            case "members":
            {
                var o = Handles.Get(r[1].Id);
                var (t, st) = o is StaticOf so ? (so.Type, true) : (o.GetType(), false);
                var flags = BindingFlags.Public | (st ? BindingFlags.Static | BindingFlags.FlattenHierarchy : BindingFlags.Instance);
                var names = t.GetMembers(flags).Where(m => m is not MethodBase mb || !mb.IsSpecialName)
                             .Where(m => m is not ConstructorInfo).Select(m => m.Name).Distinct().OrderBy(n => n, StringComparer.Ordinal);
                var a = new Writer();
                foreach (var n in names) a.Add('S', n);
                w.Add('A', a.ToArray());
                break;
            }
            case "count": w.Add('S', Handles.Count.ToString()); break;
            case "retain": Handles.Add(Handles.Get(r[1].Id)); w.Add('V', ""); break;   // one more proxy for it
            case "await": Await(Handles.Get(r[1].Id), w); break;
            case "items": Collections.Items(Handles.Get(r[1].Id), w); break;
            case "pairs": Collections.Pairs(Handles.Get(r[1].Id), w); break;
            case "index": Collections.Index(Handles.Get(r[1].Id), r[2].Items, w); break;
            case "setIndex": Collections.SetIndex(Handles.Get(r[1].Id), r[2], r[3].Items); w.Add('V', ""); break;
            case "box": Box(r[1], r[2], w); break;
            case "enumInfo": EnumInfo(Handles.Get(r[1].Id) as Enum ?? throw new BridgeException("not an enum value"), w); break;
            case "enumEquals": w.Add('S', EnumEquals(Handles.Get(r[1].Id) as Enum ?? throw new BridgeException("not an enum value"), r[2]) ? "1" : "0"); break;
            case "unbox": Unbox(r[1], w); break;
            case "arrayAt": Collections.ArrayAt(ArrayOf(r[1]), r[2].Items, w); break;
            case "arrayPut": Collections.ArrayPut(ArrayOf(r[1]), r[2], int.Parse(r[3].Text), r[4].Items); w.Add('V', ""); break;
            case "arrayDim": Collections.ArrayDimension(ArrayOf(r[1]), r[2].Items, w); break;
            case "arraySize": w.Add('S', ArrayOf(r[1]).LongLength.ToString()); break;
            case "event": Event(r[1], r[2].Text, r[3].Text, r[4]); w.Add('V', ""); break;
            case "nextEvent": Callbacks.NextEvent(double.Parse(r[1].Text, System.Globalization.CultureInfo.InvariantCulture), int.Parse(r[2].Text), w); break;
            case "loopGeneration": w.Add('S', Callbacks.Generation.ToString()); break;
            case "stopLoops": Callbacks.StopLoops(); w.Add('V', ""); break;
            case "releaseHandler": Callbacks.Release(int.Parse(r[1].Text)); w.Add('V', ""); break;
            case "queued": w.Add('S', Callbacks.QueuedCount.ToString()); break;
            default: throw new BridgeException("unknown operation " + op);
        }
    }

    static Array ArrayOf(Rec r) => Handles.Get(r.Id) as Array ?? throw new BridgeException("not a .NET array");

    // The type of a handle: a .NetType's type, or an object's runtime type.
    static Type TypeOf(Rec r)
    {
        var o = Handles.Get(r.Id);
        return o is StaticOf so ? so.Type : o.GetType();
    }

    static Type MakeType(List<Rec> r)
    {
        if (r.Count == 0) throw new BridgeException(".net~type: a type name is needed");
        var t = r[0].Tag == 'S' ? Types.Parse(r[0].Text)
              : Handles.Get(r[0].Id) is Type given ? given              // .net~type(a System.Type object): that type
              : TypeOf(r[0]);
        if (r.Count == 1) return t;
        var args = r.Skip(1).Select(a => a.Tag == 'S' ? Types.Parse(a.Text) : TypeOf(a)).ToArray();
        if (!t.IsGenericTypeDefinition)
            throw new BridgeException($"{Types.Display(t)} is not a generic type, it takes no type arguments");
        if (t.GetGenericArguments().Length != args.Length)
            throw new BridgeException($"{Types.Display(t)} takes {t.GetGenericArguments().Length} type arguments, not {args.Length}");
        return t.MakeGenericType(args);
    }

    // The members of a target: (type, static?, instance).
    static (Type, bool, object?) Target(Rec r)
    {
        var o = Handles.Get(r.Id);
        return o is StaticOf so ? (so.Type, true, null) : (o.GetType(), false, o);
    }

    // A member set; none: 97.1 (message: the message name as Rexx sees it).
    // both: an object's instance and static members together, as CLR.CLS
    // looked members up (Type.GetMethod's default flags).
    static MemberSet Members_(Type t, bool isStatic, string name, bool exact, string? message = null, bool both = false) =>
        (both && !isStatic ? Merge(Members.Find(t, false, name, exact), Members.Find(t, true, name, exact))
                           : Members.Find(t, isStatic, name, exact)) ?? throw new NoMemberException(message ?? name,
            $"{Types.Display(t)} has no public {(isStatic ? "static" : "instance")} member \"{name}\"" +
            (isStatic ? " (for the members of the System.Type object, use .net~typeObject)" : ""));

    static MemberSet? Merge(MemberSet? a, MemberSet? b) => a == null ? b : b == null ? a : new MemberSet
    {
        Name = a.Name,
        Methods = a.Methods.Concat(b.Methods).ToArray(),
        Generic = a.Generic.Concat(b.Generic).ToArray(),
        Properties = a.Properties.Concat(b.Properties).ToArray(),
        Field = a.Field ?? b.Field,
        Event = a.Event ?? b.Event,
    };

    static void Send(Rec target, string name, bool exact, List<Rec> args, Writer w, bool both = false)
    {
        var (t, isStatic, inst) = Target(target);
        if (!isStatic && Com.Is(inst)) { Com.Send(inst!, name, args, w); return; }   // COM: IDispatch (Com.cs)
        Type[]? given = null;                               // Name<T1, T2>: a generic method's type arguments
        int lt = name.IndexOf('<');
        if (lt > 0 && name.EndsWith('>'))
        {
            given = Types.ParseList(name.Substring(lt + 1, name.Length - lt - 2));
            name = name.Substring(0, lt);
        }
        if (t.ContainsGenericParameters && isStatic)
            throw new BridgeException($"{Types.Display(t)} is an open generic type: give its type arguments, " +
                                      "e.g. .net~type(\"System.Collections.Generic.List<int>\")");
        if (given == null && args.Count == 1 && Accessor(t, isStatic, name, exact) is (string op, string ev))
        {                                                   // o~add_Click(h), o~remove_Click(h): .NET's accessors
            Event(target, ev, op, args[0], exact);
            w.Add('V', "");
            return;
        }
        var set = Members_(t, isStatic, name, exact, given != null ? name + "<" + string.Join(", ", given.Select(Types.Display)) + ">" : null, both);
        if (args.Count == 0 && given == null)
        {
            var p = set.Properties.FirstOrDefault(x => x.GetIndexParameters().Length == 0);
            if (p != null)
            {
                if (p.GetMethod == null || !p.GetMethod.IsPublic) throw new BridgeException($"{set.Name} of {Types.Display(t)} cannot be read");
                Conv.ToRexx(w, p.GetValue(inst));
                return;
            }
            if (set.Field != null) { Conv.ToRexx(w, set.Field.GetValue(inst)); return; }
            if (set.Event != null && set.Methods.Length == 0)
            {                                               // a .NetEvent: o~Click += handler
                var owner = Handles.Get(target.Id);
                int id = Handles.Add(owner);
                w.Add('e', $"{id}\t{(owner is StaticOf ? "t" : "o")}\t{Types.Display(t)}\t{set.Name}");
                return;
            }
        }
        var candidates = given != null ? Members.Instantiate(set.Generic, args, given).ToList()
            : set.Methods.Cast<MethodInfo>()
                .Concat(set.Properties.Where(x => x.GetIndexParameters().Length > 0 && x.GetMethod != null && x.GetMethod.IsPublic)
                                      .Select(x => x.GetMethod!))
                .Concat(Members.Instantiate(set.Generic, args, null))
                .ToList();
        if (candidates.Count == 0)
            throw new BridgeException(given != null
                ? $"{set.Name} of {Types.Display(t)} has no generic form taking {given.Length} type argument{(given.Length == 1 ? "" : "s")}"
                : set.Generic.Length > 0
                ? $"cannot infer the type arguments of {set.Name} of {Types.Display(t)}: give them, e.g. .net~invoke(o, \"{set.Name}<int>\", ...)"
                : $"{set.Name} of {Types.Display(t)} is not a method: it takes no arguments");
        var (m, conv) = Members.Choose(candidates, args, $"{Types.Display(t)}.{set.Name}");
        var result = m.Invoke(inst, conv);
        if (!args.Any(a => a.Tag == 'R')) { Conv.ToRexx(w, result, m.ReturnType); return; }
        var inner = new Writer();                           // the result, then each .NetRef's new value
        Conv.ToRexx(inner, result, m.ReturnType);
        for (int i = 0; i < args.Count; i++) if (args[i].Tag == 'R') Conv.ToRexx(inner, conv[i]);
        w.Add('R', inner.ToArray());
    }

    // Waits for a Task or ValueTask (blocking this thread, as C#'s .Result:
    // never on a thread whose SynchronizationContext the task needs).
    static void Await(object o, Writer w)
    {
        if (o is not System.Threading.Tasks.Task task)
        {
            var at = o.GetType().GetMethod("AsTask", Type.EmptyTypes);           // ValueTask, ValueTask<T>
            if (o.GetType().FullName?.StartsWith("System.Threading.Tasks.ValueTask") != true || at == null)
                throw new BridgeException($"{Types.Display(o is StaticOf so ? so.Type : o.GetType())} is not a Task: nothing to await");
            task = (System.Threading.Tasks.Task)at.Invoke(o, null)!;
        }
        task.GetAwaiter().GetResult();                      // its exception, unwrapped, if it failed
        var rt = task.GetType();
        while (rt != null && !(rt.IsGenericType && rt.GetGenericTypeDefinition() == typeof(System.Threading.Tasks.Task<>))) rt = rt.BaseType;
        if (rt == null || !rt.GetGenericArguments()[0].IsVisible) { w.Add('V', ""); return; }   // Task, or Task<VoidTaskResult>
        Conv.ToRexx(w, rt.GetProperty("Result")!.GetValue(task));
    }

    static void Set(Rec target, string name, bool exact, Rec value, bool both = false)
    {
        var (t, isStatic, inst) = Target(target);
        if (!isStatic && Com.Is(inst)) { Com.Set(inst!, name, value); return; }
        var set = Members_(t, isStatic, name, exact, name + "=", both);
        var p = set.Properties.FirstOrDefault(x => x.GetIndexParameters().Length == 0);
        Type to;
        if (p != null)
        {
            if (p.SetMethod == null || !p.SetMethod.IsPublic) throw new BridgeException($"{set.Name} of {Types.Display(t)} cannot be set");
            to = p.PropertyType;
        }
        else if (set.Field != null)
        {
            if (set.Field.IsInitOnly || set.Field.IsLiteral) throw new BridgeException($"{set.Name} of {Types.Display(t)} is read-only");
            to = set.Field.FieldType;
        }
        else if (set.Event != null) throw new BridgeException($"{set.Name} of {Types.Display(t)} is an event: use o~{set.Name} += handler, o~{set.Name} -= handler");
        else throw new BridgeException($"{set.Name} of {Types.Display(t)} is not a property or field");
        if (Conv.TryConvert(value, to, out var v) == Conv.Fail)
            throw new BridgeException($"cannot set {set.Name} ({Types.Display(to)}) to \"{Conv.Describe(value)}\"");
        if (p != null) p.SetValue(inst, v); else set.Field!.SetValue(inst, v);
    }

    static void New(Type t, List<Rec> args, Writer w)
    {
        if (t.ContainsGenericParameters)
            throw new BridgeException($"{Types.Display(t)} is an open generic type: give its type arguments, " +
                                      "e.g. .net~type(\"System.Collections.Generic.List<int>\")");
        if (t.IsAbstract) throw new BridgeException($"{Types.Display(t)} is {(t.IsInterface ? "an interface" : "abstract")}: it cannot be created");
        object? o;
        var ctors = t.GetConstructors();
        if (args.Count == 0 && t.IsValueType && !ctors.Any(c => c.GetParameters().Length == 0))
            o = Activator.CreateInstance(t);
        else
        {
            var (c, conv) = Members.Choose(ctors, args, $"new {Types.Display(t)}");
            o = c.Invoke(conv);
        }
        Conv.ToRexx(w, o);                  // new String('a', 3) is a Rexx string
    }

    // o~Name += value, o~Name -= value: value converted to the event's
    // delegate type (a .NetHandler gives its cached delegate of that type).
    static void Event(Rec target, string name, string op, Rec value, bool exact = false)
    {
        var (t, isStatic, inst) = Target(target);
        var set = Members_(t, isStatic, name, exact);
        var ev = set.Event ?? throw new BridgeException($"{set.Name} of {Types.Display(t)} is not an event");
        var ht = ev.EventHandlerType!;
        if (Conv.TryConvert(value, ht, out var d) == Conv.Fail || d is not Delegate del)
            throw new BridgeException($"cannot use {Conv.Describe(value)} as a {Types.Display(ht)} for the event {set.Name}");
        if (op == "add") ev.AddEventHandler(inst, del); else ev.RemoveEventHandler(inst, del);
    }

    // add_Name / remove_Name, when Name is an event and no member has the
    // accessor's own name: ("add" or "remove", the event's name).
    static (string, string)? Accessor(Type t, bool isStatic, string name, bool exact)
    {
        var cmp = exact ? StringComparison.Ordinal : StringComparison.OrdinalIgnoreCase;
        string op = name.StartsWith("add_", cmp) ? "add" : name.StartsWith("remove_", cmp) ? "remove" : "";
        if (op == "") return null;
        var ev = name.Substring(op.Length + 1);
        if (ev.Length == 0 || Members.Find(t, isStatic, name, exact) != null) return null;
        return Members.Find(t, isStatic, ev, exact)?.Event != null ? (op, ev) : null;
    }

    // ----------------------------------------------------------- box / unbox

    // CLR.CLS's type indicators (clr.box), and its long names, which may be
    // shortened down to their capitals ("STring", "BOolean", "CHAR"acter).
    static readonly (string Name, int Min, Type Type)[] clrNames =
    {
        ("Boolean", 2, typeof(bool)), ("Byte", 2, typeof(byte)), ("Character", 4, typeof(char)),
        ("Decimal", 2, typeof(decimal)), ("Double", 2, typeof(double)), ("Int16", 5, typeof(short)),
        ("UInt16", 6, typeof(ushort)), ("Int32", 5, typeof(int)), ("UInt32", 6, typeof(uint)),
        ("Int64", 5, typeof(long)), ("UInt64", 6, typeof(ulong)), ("SByte", 2, typeof(sbyte)),
        ("Single", 2, typeof(float)), ("String", 2, typeof(string)),
    };

    static Type BoxType(Rec r)
    {
        if (r.Tag != 'S') return TypeOf(r);
        var n = r.Text.Trim();
        foreach (var (name, min, type) in clrNames)
            if (n.Length >= min && n.Length <= name.Length && name.StartsWith(n, StringComparison.OrdinalIgnoreCase)) return type;
        return Types.Parse(n);
    }

    // .net~box(type, value): a .NET object holding value as that type, by
    // reference (a .NetObject, where a Rexx string would go as the type of
    // the parameter it meets).
    static void Box(Rec type, Rec value, Writer w)
    {
        var t = BoxType(type);
        if (t.ContainsGenericParameters || t == typeof(void))
            throw new BridgeException($".net~box: cannot make a {Types.Display(t)}");
        if (Conv.TryConvert(value, t, out var v) == Conv.Fail)
            throw new BridgeException($".net~box: \"{Conv.Describe(value)}\" cannot be a {Types.Display(t)}");
        if (v == null) { w.Add('N', ""); return; }
        Conv.AddObject(w, v);
    }

    // .net~unbox(o): the Rexx value of a boxed primitive, string or enum;
    // nothing (o itself, says net.cls) for any other object.
    static void Unbox(Rec r, Writer w)
    {
        var o = r.Tag == 'O' ? Handles.Get(r.Id) : null;
        if (o is string || o is Enum || (o != null && (o.GetType().IsPrimitive || o is decimal))) Conv.ToRexx(w, o);
        else w.Add('V', "");
    }

    // ----------------------------------------------------------------- enums

    // An enum value's name ("Monday", "Bold, Italic"; the number when it has
    // none) and its number (the underlying value).
    static void EnumInfo(Enum e, Writer w)
    {
        var a = new Writer();
        a.Add('S', e.ToString());
        a.Add('S', EnumNumber(e));
        w.Add('A', a.ToArray());
    }

    internal static string EnumNumber(object e) =>
        System.Convert.ToString(System.Convert.ChangeType(e, Enum.GetUnderlyingType(e.GetType())), Inv)!;

    static readonly System.Globalization.CultureInfo Inv = System.Globalization.CultureInfo.InvariantCulture;

    // e = other: another enum value of the same type and number, or a string
    // that names it as .NET reads one (caseless; "Italic, Bold" for flags in
    // any order; or its number).
    static bool EnumEquals(Enum e, Rec other)
    {
        if (other.Tag == 'O') return Handles.Get(other.Id) is Enum o && o.GetType() == e.GetType() && o.Equals(e);
        if (other.Tag != 'S') return false;
        return Enum.TryParse(e.GetType(), other.Text.Trim(), true, out var v) && e.Equals(v);
    }

    static bool Has(Rec target, string name)
    {
        var (t, isStatic, _) = Target(target);
        try { return Members.Find(t, isStatic, name, false) != null; }
        catch (BridgeException) { return true; }                    // ambiguous: it has
    }
}
