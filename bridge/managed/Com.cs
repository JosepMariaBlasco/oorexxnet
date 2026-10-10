// COM objects (Windows): late binding through IDispatch, as C#'s dynamic and
// ooRexx's .OLEObject do (notes/netobject-design.md, "COM objects: built").
//
// A COM object without a .NET interop type (System.__ComObject: from
// .net~createObject, or returned by another COM object) shows no members to
// reflection: a message is sent to it by name through IDispatch
// (Type.InvokeMember), caselessly, as a method call or a property read
// (DISPATCH_METHOD | DISPATCH_PROPERTYGET: COM servers take either), and
// o~name = v is a property write. o[i] is its default member (DISPID 0).
// Arguments, as .OLEObject sends them: .true and .false as booleans
// (VT_BOOL; the strings "1" and "0" as numbers); a Rexx string that is a Rexx
// number as a number (but as itself where the member's type information
// declares a string: Strings, below): an int (VT_I4) if whole and within 32 bits, else a
// double (VT_R8; COM servers, as VBA, rarely take VT_I8); a Rexx Array as a
// SAFEARRAY of its rank, its items converted the same way (Calc's
// setDataArray keeps a string "7" as text); any other string as a string
// (.net~box("string", "007") forces a string); .nil, and an omitted argument,
// as "not given" (Type.Missing: COM's optional parameters); a .NetRef by
// reference (its value converted the same way; afterwards it holds what the
// COM object left there); .NET objects as themselves. Results as any .NET result (another COM object: a .NetObject).
// Every call is made in English (US), as VBA's (see English below), unless
// the object was created with another language (.net~createObject(progID,
// "user"): the user's, as .OLEObject; or a culture name): the objects it
// returns, and its events' COM arguments, then inherit that language.
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
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

    internal static void Send(object o, string name, List<Rec> args, Writer w)
    {
        var a = Args(args);
        Strings(o, name, INVOKE_FUNC | INVOKE_PROPERTYGET, args, a);
        if (!args.Any(r => r.Tag == 'R')) { Conv.ToRexx(w, Invoke(o, name, Get, a)); return; }
        // .NetRef arguments go by reference (VT_BYREF: an ADO Execute's
        // RecordsAffected, as .OLEObject's .OLEVariant): the answer is R, the
        // result and then each one's new value
        var byRef = new ParameterModifier(a.Length);
        for (int i = 0; i < a.Length; i++) byRef[i] = args[i].Tag == 'R';
        var result = Invoke(o, name, Get, a, new[] { byRef });
        var inner = new Writer();
        Conv.ToRexx(inner, result);
        for (int i = 0; i < a.Length; i++) if (args[i].Tag == 'R') Conv.ToRexx(inner, a[i]);
        w.Add('R', inner.ToArray());
    }

    internal static void Set(object o, string name, Rec value)
    {
        var a = new[] { Arg(value) };
        Strings(o, name, INVOKE_PROPERTYPUT, new List<Rec> { value }, a, last: true);
        Invoke(o, name, BindingFlags.SetProperty, a);
    }

    // ------------------------------------------------- declared string parameters

    // A Rexx number goes as a number (Number, below), but where the member's
    // type information declares a string parameter (BSTR) it goes as the
    // Rexx string itself, as .OLEObject converts arguments to the declared
    // types: Word's Selection.TypeText(2000) refuses an int (most servers
    // convert, Word does not). The declared types are read once per
    // interface and name.
    const int INVOKE_FUNC = 1, INVOKE_PROPERTYGET = 2, INVOKE_PROPERTYPUT = 4;
    const short VT_BSTR = 8;
    static readonly System.Collections.Concurrent.ConcurrentDictionary<(Guid, string, int), short[]?> declared = new();

    // last: the arguments are the last parameters (a property put's value)
    static void Strings(object o, string name, int invkind, List<Rec> recs, object?[] a, bool last = false)
    {
        bool any = false;
        for (int i = 0; i < a.Length && !any; i++) any = Numeric(recs[i], a[i]);
        if (!any || !OperatingSystem.IsWindows()) return;
        var vts = Declared(o, name, invkind);
        if (vts == null) return;
        int shift = last ? vts.Length - a.Length : 0;
        for (int i = 0; i < a.Length; i++)
        {
            int k = i + shift;
            if (k >= 0 && k < vts.Length && vts[k] == VT_BSTR && Numeric(recs[i], a[i])) a[i] = recs[i].Text;
        }
    }

    static bool Numeric(Rec r, object? converted) => r.Tag == 'S' && !r.Logical && converted is int or double;

    // Any failure reading the type information (servers leave parts of it
    // unimplemented: Word's GetIDsOfNames is E_NOTIMPL) means "not known":
    // the arguments go as they are.
    [System.Runtime.Versioning.SupportedOSPlatform("windows")]
    static short[]? Declared(object o, string name, int invkind)
    {
        try
        {
            if (o is not IDispatchInfo d || d.GetTypeInfo(0, 0x0409, out var ti) != 0 || ti == null) return null;
            ti.GetTypeAttr(out var pa);
            System.Runtime.InteropServices.ComTypes.TYPEATTR attr;
            try { attr = Marshal.PtrToStructure<System.Runtime.InteropServices.ComTypes.TYPEATTR>(pa); }
            finally { ti.ReleaseTypeAttr(pa); }
            return declared.GetOrAdd((attr.guid, name.ToUpperInvariant(), invkind), _ => Read(ti, name, invkind, attr.cFuncs));
        }
        catch (Exception) { return null; }
    }

    // The parameters' VARTYPEs of the member of that name and kind (null: none
    // found), its name compared caselessly with each function's (GetNames).
    [System.Runtime.Versioning.SupportedOSPlatform("windows")]
    static short[]? Read(System.Runtime.InteropServices.ComTypes.ITypeInfo ti, string name, int invkind, int funcs)
    {
        try
        {
            int size = Marshal.SizeOf<System.Runtime.InteropServices.ComTypes.ELEMDESC>();
            var names = new string[1];
            for (int f = 0; f < funcs; f++)
            {
                ti.GetFuncDesc(f, out var pf);
                try
                {
                    var fd = Marshal.PtrToStructure<System.Runtime.InteropServices.ComTypes.FUNCDESC>(pf);
                    if (((int)fd.invkind & invkind) == 0) continue;
                    ti.GetNames(fd.memid, names, 1, out int got);
                    if (got < 1 || !string.Equals(names[0], name, StringComparison.OrdinalIgnoreCase)) continue;
                    var vts = new short[fd.cParams];
                    for (int k = 0; k < fd.cParams; k++)
                        vts[k] = Marshal.PtrToStructure<System.Runtime.InteropServices.ComTypes.ELEMDESC>(fd.lprgelemdescParam + k * size).tdesc.vt;
                    return vts;
                }
                finally { ti.ReleaseFuncDesc(pf); }
            }
        }
        catch (Exception) { }
        return null;
    }

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

    static object? Invoke(object o, string name, BindingFlags how, object?[] args, ParameterModifier[]? byRef = null)
    {
        var until = DateTime.UtcNow + Busy;
        for (int pause = 10; ; pause = Math.Min(pause * 2, 500))
        {
            try { return Call(o, name, how, args, byRef); }
            catch (Exception e) when (Rejected(e) && DateTime.UtcNow < until)
            {
                System.Threading.Thread.Sleep(pause);
            }
        }
    }

    static object? Call(object o, string name, BindingFlags how, object?[] args, ParameterModifier[]? byRef)
    {
        try
        {
            var r = o.GetType().InvokeMember(name, how, null, o, args, byRef, LanguageOf(o), null);
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
            case 'R': return r.Inner == null || r.Inner.Tag == 'N' ? null : Arg(r.Inner);   // (by reference: Send)
            case 'S': return r.Logical ? r.Text == "1" : Number(r.Text);
            case 'A': return r.Dims == null ? r.Items.Select(Arg).ToArray() : Grid(r);   // items as arguments too
        }
        if (Conv.TryConvert(r, typeof(object), out var v) == Conv.Fail)
            throw new BridgeException($"\"{Conv.Describe(r)}\" cannot go to a COM object");
        return v;
    }

    /// A multidimensional Rexx Array: object[,...], its items as arguments
    /// (Rexx's order: the first index fastest).
    static Array Grid(Rec r)
    {
        var dims = r.Dims!;
        var arr = Array.CreateInstance(typeof(object), dims);
        var idx = new int[dims.Length];
        for (int k = 0; k < r.Items.Count; k++)
        {
            for (int d = 0, q = k; d < dims.Length; d++) { idx[d] = q % dims[d]; q /= dims[d]; }
            arr.SetValue(Arg(r.Items[k]), idx);
        }
        return arr;
    }

    /// A Rexx number as an int (whole, within 32 bits) or a double; any
    /// other string as itself. Rexx's syntax: blanks around, a sign (blanks
    /// may follow it), digits with at most one '.', an exponent (E, a sign,
    /// digits); "NaN" or "Infinity" are strings.
    internal static object Number(string s)
    {
        var t = s.Trim(' ', '\t');
        if (t.Length == 0 || t.Length > 400) return s;
        int i = 0;
        string sign = "";
        if (t[0] == '+' || t[0] == '-') { sign = t[0] == '-' ? "-" : ""; i = 1; while (i < t.Length && (t[i] == ' ' || t[i] == '\t')) i++; }
        int start = i, digits = 0, dots = 0;
        for (; i < t.Length; i++)
        {
            if (t[i] >= '0' && t[i] <= '9') digits++;
            else if (t[i] == '.') { if (++dots > 1) return s; }
            else break;
        }
        if (digits == 0) return s;
        string mantissa = t.Substring(start, i - start), exponent = "";
        if (i < t.Length)
        {
            if (t[i] != 'e' && t[i] != 'E') return s;
            int e = ++i;
            if (i < t.Length && (t[i] == '+' || t[i] == '-')) i++;
            int ed = i;
            while (i < t.Length && t[i] >= '0' && t[i] <= '9') i++;
            if (i == ed || i != t.Length) return s;
            exponent = "E" + t.Substring(e);
        }
        var n = sign + mantissa + exponent;
        if (decimal.TryParse(n, NumberStyles.Float, CultureInfo.InvariantCulture, out decimal m) &&
            m == decimal.Truncate(m) && m >= int.MinValue && m <= int.MaxValue)
            return (int)m;
        if (double.TryParse(n, NumberStyles.Float, CultureInfo.InvariantCulture, out double d) && double.IsFinite(d))
            return d;
        return s;
    }
}
