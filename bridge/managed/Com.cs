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
// Every call is made in English (US), as VBA's (see English below), unless
// the object was created with another language (.net~createObject(progID,
// "user"): the user's, as .OLEObject; or a culture name): the objects it
// returns, and its events' COM arguments, then inherit that language.
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
    [System.Runtime.Versioning.SupportedOSPlatformGuard("windows")]
    internal static bool Is(object? o) =>
        o != null && OperatingSystem.IsWindows() && Marshal.IsComObject(o) && o.GetType().FullName == "System.__ComObject";

    const BindingFlags Get = BindingFlags.InvokeMethod | BindingFlags.GetProperty;
    // The locale every call carries (IDispatch::Invoke's LCID): English (US),
    // as VBA's. Excel refuses an LCID it has no language for (the invariant
    // culture's: TYPE_E_INVDATAREAD, "Old format or invalid type library"),
    // and reads Formula and its kin in the caller's language: with English,
    // =SUM(...) on any Windows, as Microsoft's documentation writes them.
    static readonly CultureInfo English = CultureInfo.GetCultureInfo("en-US");

    // The language of the objects created with one (and of the COM objects
    // they return); every other object's is English.
    static readonly System.Runtime.CompilerServices.ConditionalWeakTable<object, CultureInfo> languages = new();

    internal static CultureInfo LanguageOf(object o) => languages.TryGetValue(o, out var c) ? c : English;

    /// A COM object that o returned (or an event of o's source gave) speaks o's language.
    internal static void Inherit(object from, object? to)
    {
        if (to == null || !Is(to) || !languages.TryGetValue(from, out var c)) return;
        languages.TryAdd(to, c);
    }

    /// The language a name gives: "" English (US); "user" the user's (as .OLEObject); else a culture name.
    static CultureInfo Language(string name)
    {
        if (name.Trim().Length == 0) return English;
        if (name.Trim().Equals("user", StringComparison.OrdinalIgnoreCase)) return CultureInfo.CurrentCulture;
        try { return CultureInfo.GetCultureInfo(name.Trim()); }
        catch (CultureNotFoundException) { throw new BridgeException($"\"{name}\" is no language: \"user\" or a culture name (\"es-ES\") is needed"); }
    }
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

    /// .net~createObject(progID [, language]): a new COM object (Excel.Application...)
    internal static object Create(string progId, string language = "")
    {
        if (!OperatingSystem.IsWindows()) throw new BridgeException("COM objects exist on Windows only");
        var culture = Language(language);
        var t = Type.GetTypeFromProgID(progId, false) ?? throw new BridgeException($"no COM class \"{progId}\" is registered");
        var o = Activator.CreateInstance(t) ?? throw new BridgeException($"\"{progId}\" could not be created");
        if (culture != English) languages.AddOrUpdate(o, culture);
        return o;
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

    // A server busy with something else (Excel showing a dialog, or closing)
    // rejects calls: RPC_E_CALL_REJECTED, RPC_E_SERVERCALL_RETRYLATER. As
    // VBA (through its message filter) and .OLEObject do, the call is made
    // again after a pause, longer each time, for up to Busy in all; then the
    // error goes to Rexx.
    const int RPC_E_CALL_REJECTED = unchecked((int)0x80010001);
    const int RPC_E_SERVERCALL_RETRYLATER = unchecked((int)0x8001010A);
    static readonly TimeSpan Busy = TimeSpan.FromSeconds(10);

    static bool Rejected(Exception e)
    {
        for (Exception? x = e; x != null; x = x.InnerException)
            if (x is COMException { HResult: RPC_E_CALL_REJECTED or RPC_E_SERVERCALL_RETRYLATER }) return true;
        return false;
    }

    static object? Invoke(object o, string name, BindingFlags how, object?[] args)
    {
        var until = DateTime.UtcNow + Busy;
        for (int pause = 10; ; pause = Math.Min(pause * 2, 500))
        {
            try { return Call(o, name, how, args); }
            catch (Exception e) when (Rejected(e) && DateTime.UtcNow < until)
            {
                System.Threading.Thread.Sleep(pause);
            }
        }
    }

    static object? Call(object o, string name, BindingFlags how, object?[] args)
    {
        try
        {
            var r = o.GetType().InvokeMember(name, how, null, o, args, LanguageOf(o));
            Inherit(o, r);
            return r;
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
