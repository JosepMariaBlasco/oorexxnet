// COM objects (Windows): late binding through IDispatch, as C#'s dynamic and
// ooRexx's .OLEObject do (notes/netobject-design.md, "COM objects: built").
//
// A COM object without a .NET interop type (System.__ComObject: from
// .net~createObject, or returned by another COM object) shows no members to
// reflection: a message is sent to it by name through IDispatch
// (Type.InvokeMember), caselessly, as a method call or a property read
// (DISPATCH_METHOD | DISPATCH_PROPERTYGET: COM servers take either), and
// o~name = v is a property write. o[i] is its default member (DISPID 0).
// Arguments: a Rexx string that is a Rexx number goes as a number (int,
// long or double), as .OLEObject sends it; any other string as a string
// (.net~box("string", "007") forces a string); .nil, and an omitted argument,
// as "not given" (Type.Missing: COM's optional parameters); .NET objects as
// themselves. Results as any .NET result (another COM object: a .NetObject).
// Every call is made in English (US): see English below.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Reflection;
using System.Runtime.InteropServices;

namespace Rexx.Net;

static class Com
{
    /// A COM object to reach through IDispatch: one with no interop type
    /// (objects of interop assemblies' types go through reflection).
    internal static bool Is(object? o) =>
        o != null && OperatingSystem.IsWindows() && Marshal.IsComObject(o) && o.GetType().FullName == "System.__ComObject";

    const BindingFlags Get = BindingFlags.InvokeMethod | BindingFlags.GetProperty;
    // The locale every call carries (IDispatch::Invoke's LCID): English (US),
    // as VBA's. Excel refuses an LCID it has no language for (the invariant
    // culture's: TYPE_E_INVDATAREAD, "Old format or invalid type library"),
    // and reads Formula and its kin in the caller's language: with English,
    // =SUM(...) on any Windows, as Microsoft's documentation writes them.
    static readonly CultureInfo English = CultureInfo.GetCultureInfo("en-US");
    const int DISP_E_UNKNOWNNAME = unchecked((int)0x80020006);
    const int DISP_E_MEMBERNOTFOUND = unchecked((int)0x80020003);

    internal static void Send(object o, string name, List<Rec> args, Writer w) =>
        Conv.ToRexx(w, Invoke(o, name, Get, Args(args)));

    internal static void Set(object o, string name, Rec value) =>
        Invoke(o, name, BindingFlags.SetProperty, new[] { Arg(value) });

    /// o[i...]: the default member (DISPID 0), read
    internal static void Index(object o, List<Rec> idx, Writer w) =>
        Conv.ToRexx(w, Invoke(o, "[DISPID=0]", Get, Args(idx)));

    /// o[i...] = v: the default member, written
    internal static void SetIndex(object o, Rec value, List<Rec> idx)
    {
        var a = Args(idx);
        Array.Resize(ref a, a.Length + 1);
        a[^1] = Arg(value);
        Invoke(o, "[DISPID=0]", BindingFlags.SetProperty, a);
    }

    /// .net~createObject(progID): a new COM object (Excel.Application...)
    internal static object Create(string progId)
    {
        if (!OperatingSystem.IsWindows()) throw new BridgeException("COM objects exist on Windows only");
        var t = Type.GetTypeFromProgID(progId, false) ?? throw new BridgeException($"no COM class \"{progId}\" is registered");
        return Activator.CreateInstance(t) ?? throw new BridgeException($"\"{progId}\" could not be created");
    }

    /// .net~releaseObject(o): releases a COM object now (its server, Excel
    /// say, can end once every object it handed out is released), instead
    /// of when .NET's garbage collector finalizes it. The proxy stays, unusable.
    internal static void Release(object o)
    {
        if (!OperatingSystem.IsWindows() || !Marshal.IsComObject(o)) throw new BridgeException("not a COM object");
        ComEvents.Disconnect(o);                            // its event sinks first
        Marshal.FinalReleaseComObject(o);
    }

    static object? Invoke(object o, string name, BindingFlags how, object?[] args)
    {
        try
        {
            return o.GetType().InvokeMember(name, how, null, o, args, English);
        }
        catch (Exception e) when (e is MissingMemberException ||
                                  e is COMException { HResult: DISP_E_UNKNOWNNAME or DISP_E_MEMBERNOTFOUND })
        {
            throw new NoMemberException(how == BindingFlags.SetProperty ? name + "=" : name,
                                        $"the COM object has no member {name}{(how == BindingFlags.SetProperty ? " to set" : "")}");
        }
    }

    static object?[] Args(List<Rec> args)
    {
        var a = new object?[args.Count];
        for (int i = 0; i < a.Length; i++) a[i] = Arg(args[i]);
        return a;
    }

    static object? Arg(Rec r)
    {
        switch (r.Tag)
        {
            case 'N': return Type.Missing;
            case 'S': return Number(r.Text);
        }
        if (Conv.TryConvert(r, typeof(object), out var v) == Conv.Fail)
            throw new BridgeException($"\"{Conv.Describe(r)}\" cannot go to a COM object");
        return v;
    }

    /// A Rexx number as an int, a long or a double; any other string as itself.
    internal static object Number(string s)
    {
        var t = s.Trim();
        if (t.Length == 0 || t.Length > 40) return s;
        if (long.TryParse(t, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out long l))
            return l >= int.MinValue && l <= int.MaxValue ? (int)l : l;
        // a Rexx number: digits with at most one '.', an optional exponent
        if (double.TryParse(t, NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint | NumberStyles.AllowExponent,
                            CultureInfo.InvariantCulture, out double d))
            return d;
        return s;
    }
}
