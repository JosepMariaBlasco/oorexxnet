// COM events (Windows): connection points, as ooRexx's .OLEObject receives
// them (orexxole events.cpp), with the syntax of .NET events
// (notes/netobject-design.md, "COM events").
//
// o~Name += handler, o~Name -= handler, .net~addHandler(o, "Name", handler),
// o~add_Name(handler): when o is a COM object reached through IDispatch
// (Com.Is) and Name is one of its events. The events are the methods of the
// object's source dispinterfaces, found as .OLEObject finds them: the
// coclass from IProvideClassInfo, or else a search of the type library of
// the object's IDispatch type information for a coclass implementing it;
// its [default, source] interface first, then any other source interface.
//
// One sink per (object, source interface): a managed object exposed to COM
// as an IDispatch that also answers to the source interface's IID
// (ICustomQueryInterface), connected with IConnectionPoint::Advise when its
// first handler comes and disconnected when its last one goes (and by
// .net~releaseObject). Its Invoke calls each handler of the event's DISPID,
// in the order they were added, through Callbacks.Call: synchronous
// handlers on the thread COM calls the sink on, queued ones queued.
//
// Arguments: the event's parameters, in their order (COM gives them in
// reverse), converted as any .NET value (an IDispatch: a COM object). A
// parameter passed by reference (Cancel in Excel's WorkbookBeforeClose, ADO's
// adStatus) arrives as a ComRef: the handler reads ~Value, and sets it
// (ref~Value = .true) to give the event's source a new value, which is
// written back when the handler returns (a queued handler is too late).
//
// A Rexx condition in a synchronous handler, while a Rexx caller waits on
// that thread (the event came during a call, or while .net~nextEvent waits),
// is kept and raised again in that caller when its request ends (the sink
// itself answers S_OK: an event's source cannot do anything with an error).
// With no Rexx caller waiting, Callbacks reports it, as for .NET events.
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Globalization;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using ComTypes = System.Runtime.InteropServices.ComTypes;

namespace Rexx.Net;

/// A parameter of a COM event passed by reference: the handler reads Value
/// and may set it; the new value goes back to the event's source.
public sealed class ComRef
{
    object? value;
    internal bool Changed;
    internal ComRef(object? v) => value = v;
    public object? Value { get => value; set { this.value = value; Changed = true; } }
    public override string ToString() => value is bool b ? (b ? "1" : "0") : Convert.ToString(value, CultureInfo.InvariantCulture) ?? "";
}

/// IDispatch, as a sink implements it (the parameters raw: Invoke reads
/// the VARIANTs itself). Public for COM only.
[ComImport, Guid("00020400-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
[EditorBrowsable(EditorBrowsableState.Never)]
public interface IComEventDispatch
{
    [PreserveSig] int GetTypeInfoCount(out uint count);
    [PreserveSig] int GetTypeInfo(uint index, int lcid, out IntPtr info);
    [PreserveSig] int GetIDsOfNames(ref Guid riid, IntPtr names, uint count, int lcid, IntPtr ids);
    [PreserveSig] int Invoke(int dispId, ref Guid riid, int lcid, ushort flags, IntPtr dispParams,
                             IntPtr result, IntPtr excepInfo, IntPtr argErr);
}

[ComImport, Guid("B196B283-BAB4-101A-B69C-00AA00341D07"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IProvideClassInfo
{
    [PreserveSig] int GetClassInfo(out ComTypes.ITypeInfo? info);
}

/// IDispatch, as a client calls it: only GetTypeInfo is needed here.
[ComImport, Guid("00020400-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IDispatchInfo
{
    [PreserveSig] int GetTypeInfoCount(out uint count);
    [PreserveSig] int GetTypeInfo(uint index, int lcid, out ComTypes.ITypeInfo? info);
}

/// The sink of one source interface of one COM object. Public for COM only.
[ComVisible(true), ClassInterface(ClassInterfaceType.None)]
[EditorBrowsable(EditorBrowsableState.Never), SupportedOSPlatform("windows")]
public sealed class ComEventSink : IComEventDispatch, ICustomQueryInterface
{
    static readonly Guid IID_IDispatch = new("00020400-0000-0000-C000-000000000046");
    internal readonly Guid Iid;
    internal ComTypes.IConnectionPoint? Point;
    internal int Cookie;
    readonly Dictionary<int, List<RexxHandler>> handlers = new();

    internal ComEventSink(Guid iid) => Iid = iid;

    internal int Count { get { lock (handlers) return handlers.Values.Sum(l => l.Count); } }

    internal void Add(int dispId, RexxHandler h)
    {
        lock (handlers)
        {
            if (!handlers.TryGetValue(dispId, out var l)) handlers[dispId] = l = new List<RexxHandler>();
            l.Add(h);
        }
    }

    /// Removes one entry of the handler (the last added); false if it had none.
    internal bool Remove(int dispId, RexxHandler h)
    {
        lock (handlers)
        {
            if (!handlers.TryGetValue(dispId, out var l)) return false;
            int i = l.FindLastIndex(x => x.Id == h.Id);
            if (i < 0) return false;
            l.RemoveAt(i);
            return true;
        }
    }

    public CustomQueryInterfaceResult GetInterface(ref Guid iid, out IntPtr ppv)
    {
        ppv = IntPtr.Zero;
        if (iid != Iid && iid != IID_IDispatch) return CustomQueryInterfaceResult.NotHandled;
        ppv = Marshal.GetComInterfaceForObject(this, typeof(IComEventDispatch), CustomQueryInterfaceMode.Ignore);
        return CustomQueryInterfaceResult.Handled;
    }

    const int E_NOTIMPL = unchecked((int)0x80004001);
    public int GetTypeInfoCount(out uint count) { count = 0; return 0; }
    public int GetTypeInfo(uint index, int lcid, out IntPtr info) { info = IntPtr.Zero; return E_NOTIMPL; }
    public int GetIDsOfNames(ref Guid riid, IntPtr names, uint count, int lcid, IntPtr ids) => E_NOTIMPL;

    public int Invoke(int dispId, ref Guid riid, int lcid, ushort flags, IntPtr dispParams,
                      IntPtr result, IntPtr excepInfo, IntPtr argErr)
    {
        RexxHandler[] hs;
        lock (handlers)
        {
            if (!handlers.TryGetValue(dispId, out var l) || l.Count == 0) return 0;
            hs = l.ToArray();
        }
        try
        {
            var (args, slots) = ComEvents.Arguments(dispParams);
            object? r = null;
            foreach (var h in hs)
            {
                try { r = Callbacks.Call(h, args, typeof(object)); }
                catch (Exception e) { ComEvents.Pend(e); return 0; }   // for the Rexx caller waiting on this thread
            }
            for (int i = 0; i < args.Length; i++)
                if (args[i] is ComRef cr && cr.Changed) ComEvents.WriteBack(slots[i], cr.Value);
            if (result != IntPtr.Zero && r != null) Marshal.GetNativeVariantForObject(r, result);
        }
        catch (Exception e) { ComEvents.Pend(e); }
        return 0;
    }
}

static class ComEvents
{
    /// An event: its source interface, DISPID and name as the type library gives it.
    internal sealed record Info(Guid Iid, int DispId, string Name);

    sealed class State
    {
        public Dictionary<string, Info>? Events;            // caseless; first source interface first
        public List<string> Names = new();
        public readonly Dictionary<Guid, ComEventSink> Sinks = new();
    }

    static readonly ConditionalWeakTable<object, State> states = new();

    [SupportedOSPlatform("windows")]
    static State StateOf(object o)
    {
        lock (states)
        {
            if (!states.TryGetValue(o, out var s)) { s = new State(); states.Add(o, s); }
            if (s.Events == null) Load(o, s);
            return s;
        }
    }

    /// The event called name (caselessly) of a COM object, or null.
    [SupportedOSPlatform("windows")]
    internal static Info? Find(object o, string name) =>
        StateOf(o).Events!.TryGetValue(name, out var e) ? e : null;

    /// The names of a COM object's events, as its type library gives them.
    [SupportedOSPlatform("windows")]
    internal static IEnumerable<string> Names(object o) => StateOf(o).Names;

    /// o~Name += h (op "add"), o~Name -= h (op "remove").
    [SupportedOSPlatform("windows")]
    internal static void Change(object o, string name, string op, RexxHandler h)
    {
        var ev = Find(o, name) ?? throw new NoMemberException(name, $"the COM object has no event {name}");
        var s = StateOf(o);
        lock (states)
        {
            s.Sinks.TryGetValue(ev.Iid, out var sink);
            if (op == "add")
            {
                if (sink == null)
                {
                    sink = new ComEventSink(ev.Iid);
                    var cpc = o as ComTypes.IConnectionPointContainer
                              ?? throw new BridgeException("the COM object gives no events (it is no IConnectionPointContainer)");
                    var iid = ev.Iid;
                    cpc.FindConnectionPoint(ref iid, out var point);
                    if (point == null) throw new BridgeException($"the COM object gives no events of {name}'s interface");
                    point.Advise(sink, out int cookie);
                    sink.Point = point;
                    sink.Cookie = cookie;
                    s.Sinks[ev.Iid] = sink;
                }
                sink.Add(ev.DispId, h);
            }
            else if (sink != null && sink.Remove(ev.DispId, h) && sink.Count == 0)
            {
                s.Sinks.Remove(ev.Iid);
                Unadvise(sink);
            }
        }
    }

    /// Disconnects every sink of a COM object (.net~releaseObject).
    [SupportedOSPlatform("windows")]
    internal static void Disconnect(object o)
    {
        lock (states)
        {
            if (!states.TryGetValue(o, out var s)) return;
            foreach (var sink in s.Sinks.Values) Unadvise(sink);
            s.Sinks.Clear();
        }
    }

    [SupportedOSPlatform("windows")]
    static void Unadvise(ComEventSink sink)
    {
        try { sink.Point?.Unadvise(sink.Cookie); } catch (COMException) { }   // the server may be gone
        sink.Point = null;
    }

    // ------------------------------------------------------ type information

    const int TKIND_DISPATCH = 4, TKIND_COCLASS = 5;
    const int IMPLTYPEFLAG_FDEFAULT = 1, IMPLTYPEFLAG_FSOURCE = 2;
    const int FUNCFLAG_FRESTRICTED = 1;
    const short TYPEFLAG_FDUAL = 0x40;

    [SupportedOSPlatform("windows")]
    static void Load(object o, State s)
    {
        s.Events = new Dictionary<string, Info>(StringComparer.OrdinalIgnoreCase);
        foreach (var (iid, ti) in Sources(o))
            foreach (var (dispId, name) in Methods(ti))
                if (s.Events.TryAdd(name, new Info(iid, dispId, name))) s.Names.Add(name);
    }

    /// The source dispinterfaces of a COM object: (IID, type information).
    [SupportedOSPlatform("windows")]
    static List<(Guid, ComTypes.ITypeInfo)> Sources(object o)
    {
        var list = new List<(Guid, ComTypes.ITypeInfo)>();
        try
        {
            if (o is IProvideClassInfo pci && pci.GetClassInfo(out var ci) == 0 && ci != null && Attr(ci).typekind == ComTypes.TYPEKIND.TKIND_COCLASS)
                AddSources(ci, list);
        }
        catch (Exception e) when (e is COMException || e is InvalidCastException) { }
        if (list.Count > 0) return list;

        // no IProvideClassInfo (or a wrong one: Outlook's gives an interface's
        // information): the coclass in the type library that implements the
        // object's interface, preferably as its default
        ComTypes.ITypeInfo? self = null;
        try
        {
            if (o is IDispatchInfo d && d.GetTypeInfo(0, 0, out var t) == 0) self = t;
        }
        catch (Exception e) when (e is COMException || e is InvalidCastException) { }
        if (self == null) return list;
        var guid = Attr(self).guid;
        self.GetContainingTypeLib(out var lib, out _);
        ComTypes.ITypeInfo? found = null;
        for (int i = 0, n = lib.GetTypeInfoCount(); i < n; i++)
        {
            lib.GetTypeInfoType(i, out var kind);
            if (kind != ComTypes.TYPEKIND.TKIND_COCLASS) continue;
            lib.GetTypeInfo(i, out var cc);
            int how = Implements(cc, guid);
            if (how == 2) { found = cc; break; }            // as its default interface
            if (how == 1 && found == null) found = cc;
        }
        if (found != null) AddSources(found, list);
        return list;
    }

    /// 2: the coclass implements the interface as its default, 1: not as its default, 0: not at all.
    static int Implements(ComTypes.ITypeInfo coclass, Guid iid)
    {
        int best = 0;
        for (int i = 0, n = Attr(coclass).cImplTypes; i < n; i++)
        {
            coclass.GetImplTypeFlags(i, out var flags);
            if (((int)flags & IMPLTYPEFLAG_FSOURCE) != 0) continue;
            coclass.GetRefTypeOfImplType(i, out int href);
            coclass.GetRefTypeInfo(href, out var ti);
            if (Attr(ti).guid != iid) continue;
            if (((int)flags & IMPLTYPEFLAG_FDEFAULT) != 0) return 2;
            best = 1;
        }
        return best;
    }

    static void AddSources(ComTypes.ITypeInfo coclass, List<(Guid, ComTypes.ITypeInfo)> list)
    {
        for (int i = 0, n = Attr(coclass).cImplTypes; i < n; i++)
        {
            coclass.GetImplTypeFlags(i, out var flags);
            if (((int)flags & IMPLTYPEFLAG_FSOURCE) == 0) continue;
            coclass.GetRefTypeOfImplType(i, out int href);
            coclass.GetRefTypeInfo(href, out var ti);
            var a = Attr(ti);
            if ((int)a.typekind != TKIND_DISPATCH)
            {                                               // a dual interface: its dispinterface side
                if (((short)a.wTypeFlags & TYPEFLAG_FDUAL) == 0) continue;   // a vtable interface: not for an IDispatch sink
                ti.GetRefTypeOfImplType(-1, out int hd);
                ti.GetRefTypeInfo(hd, out ti);
                a = Attr(ti);
            }
            var item = (a.guid, ti);
            if (((int)flags & IMPLTYPEFLAG_FDEFAULT) != 0) list.Insert(0, item); else list.Add(item);
        }
    }

    /// The methods of a dispinterface: (DISPID, name).
    static IEnumerable<(int, string)> Methods(ComTypes.ITypeInfo ti)
    {
        var result = new List<(int, string)>();
        for (int i = 0, n = Attr(ti).cFuncs; i < n; i++)
        {
            ti.GetFuncDesc(i, out var p);
            var fd = Marshal.PtrToStructure<ComTypes.FUNCDESC>(p);
            ti.ReleaseFuncDesc(p);
            if ((fd.wFuncFlags & FUNCFLAG_FRESTRICTED) != 0) continue;   // IUnknown's and IDispatch's own
            var names = new string[1];
            ti.GetNames(fd.memid, names, 1, out int got);
            if (got > 0) result.Add((fd.memid, names[0]));
        }
        return result;
    }

    static ComTypes.TYPEATTR Attr(ComTypes.ITypeInfo ti)
    {
        ti.GetTypeAttr(out var p);
        try { return Marshal.PtrToStructure<ComTypes.TYPEATTR>(p); }
        finally { ti.ReleaseTypeAttr(p); }
    }

    // ------------------------------------------------------------ arguments

    const ushort VT_I2 = 2, VT_I4 = 3, VT_R4 = 4, VT_R8 = 5, VT_CY = 6, VT_DATE = 7, VT_BSTR = 8,
                 VT_ERROR = 10, VT_BOOL = 11, VT_VARIANT = 12, VT_I1 = 16, VT_UI1 = 17, VT_UI2 = 18,
                 VT_UI4 = 19, VT_I8 = 20, VT_UI8 = 21, VT_INT = 22, VT_UINT = 23, VT_BYREF = 0x4000;

    static int VariantSize => IntPtr.Size == 8 ? 24 : 16;

    /// An Invoke's arguments, in the event's order, and the VARIANT of each
    /// (where a ComRef's new value goes).
    [SupportedOSPlatform("windows")]
    internal static (object?[], IntPtr[]) Arguments(IntPtr dispParams)
    {
        var dp = Marshal.PtrToStructure<ComTypes.DISPPARAMS>(dispParams);
        int n = dp.cArgs, named = dp.cNamedArgs;
        var slots = new IntPtr[n];
        var used = new bool[n];
        for (int i = 0; i < named; i++)                     // named arguments first, at their DISPIDs (positions)
        {
            int pos = Marshal.ReadInt32(dp.rgdispidNamedArgs, i * 4);
            if (pos >= 0 && pos < n && !used[pos]) { slots[pos] = dp.rgvarg + i * VariantSize; used[pos] = true; }
        }
        for (int i = named, pos = 0; i < n; i++)            // then the positional ones, given in reverse
        {
            while (pos < n && used[pos]) pos++;
            if (pos == n) break;
            slots[pos] = dp.rgvarg + (n - 1 - (i - named)) * VariantSize;
            used[pos++] = true;
        }
        var args = new object?[n];
        for (int i = 0; i < n; i++)
        {
            if (slots[i] == IntPtr.Zero) { args[i] = null; continue; }
            ushort vt = (ushort)Marshal.ReadInt16(slots[i]);
            object? v;
            try
            {
                v = vt == (VT_BYREF | VT_VARIANT) ? Marshal.GetObjectForNativeVariant(Marshal.ReadIntPtr(slots[i], 8))
                                                  : Marshal.GetObjectForNativeVariant(slots[i]);
            }
            catch (Exception e) when (e is ArgumentException || e is NotSupportedException || e is InvalidOleVariantTypeException || e is COMException)
            {
                v = null;                                   // a VARIANT .NET cannot convert (VT_RECORD...)
            }
            if (v == DBNull.Value || v is System.Reflection.Missing) v = null;
            args[i] = (vt & VT_BYREF) != 0 ? new ComRef(v) : v;
        }
        return (args, slots);
    }

    [DllImport("oleaut32.dll")] static extern int VariantClear(IntPtr v);

    /// A ComRef's new value into the VARIANT of a parameter passed by reference.
    [SupportedOSPlatform("windows")]
    internal static void WriteBack(IntPtr slot, object? value)
    {
        ushort vt = (ushort)Marshal.ReadInt16(slot);
        if ((vt & VT_BYREF) == 0) return;
        var p = Marshal.ReadIntPtr(slot, 8);
        if (p == IntPtr.Zero) return;
        switch (vt & ~VT_BYREF)
        {
            case VT_VARIANT:
                VariantClear(p);
                Marshal.GetNativeVariantForObject(ToCom(value), p);
                break;
            case VT_BOOL: Marshal.WriteInt16(p, Truth(value) ? (short)-1 : (short)0); break;
            case VT_I1: case VT_UI1: Marshal.WriteByte(p, unchecked((byte)Whole(value))); break;
            case VT_I2: case VT_UI2: Marshal.WriteInt16(p, unchecked((short)Whole(value))); break;
            case VT_I4: case VT_UI4: case VT_INT: case VT_UINT: case VT_ERROR:
                Marshal.WriteInt32(p, unchecked((int)Whole(value))); break;
            case VT_I8: case VT_UI8: Marshal.WriteInt64(p, Whole(value)); break;
            case VT_R4: Marshal.WriteInt32(p, BitConverter.SingleToInt32Bits((float)Real(value))); break;
            case VT_R8: Marshal.WriteInt64(p, BitConverter.DoubleToInt64Bits(Real(value))); break;
            case VT_DATE:
                Marshal.WriteInt64(p, BitConverter.DoubleToInt64Bits(value is DateTime dt ? dt.ToOADate() : Real(value))); break;
            case VT_CY: Marshal.WriteInt64(p, decimal.ToOACurrency(value is decimal m ? m : (decimal)Real(value))); break;
            case VT_BSTR:
            {
                var old = Marshal.ReadIntPtr(p);
                Marshal.WriteIntPtr(p, Marshal.StringToBSTR(Text(value)));
                if (old != IntPtr.Zero) Marshal.FreeBSTR(old);
                break;
            }
            default:
                throw new BridgeException($"a COM event parameter of VARTYPE {vt & ~VT_BYREF} passed by reference cannot be changed");
        }
    }

    static object? ToCom(object? v) => v is string s ? Com.Number(s) : v;

    static string Text(object? v) => v is bool b ? (b ? "1" : "0") : Convert.ToString(v, CultureInfo.InvariantCulture) ?? "";

    static bool Truth(object? v) => v switch
    {
        null => false,
        bool b => b,
        string s => s.Trim() switch
        {
            "1" => true, "0" or "" => false,
            var t when t.Equals("true", StringComparison.OrdinalIgnoreCase) => true,
            var t when t.Equals("false", StringComparison.OrdinalIgnoreCase) => false,
            var t => Real(t) != 0,
        },
        _ => Real(v) != 0,
    };

    static long Whole(object? v) => v switch
    {
        null => 0,
        bool b => b ? 1 : 0,
        Enum e => Convert.ToInt64(e, CultureInfo.InvariantCulture),
        string s when long.TryParse(s.Trim(), NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out var l) => l,
        _ => (long)Real(v),
    };

    static double Real(object? v) => v switch
    {
        null => 0,
        bool b => b ? 1 : 0,
        string s => double.TryParse(s.Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out var d) ? d
                    : throw new BridgeException($"\"{s}\" is not a number"),
        _ => Convert.ToDouble(v, CultureInfo.InvariantCulture),
    };

    // ------------------------------------------------- errors in a handler

    // A Rexx condition (or any failure) in a sink's handler while a Rexx
    // caller waits on this thread: raised again when the caller's request
    // ends (Bridge.Handle); the first one wins.
    [ThreadStatic] static Exception? pending;

    internal static void Pend(Exception e)
    {
        if (Bridge.Depth == 0) return;                      // nobody to give it to (Callbacks has reported a Rexx error)
        pending ??= e;
        Callbacks.Wake();                                   // a .net~nextEvent waiting on this thread returns
    }

    internal static bool HasPending => pending != null;

    internal static Exception? TakePending()
    {
        var e = pending;
        pending = null;
        return e;
    }
}
