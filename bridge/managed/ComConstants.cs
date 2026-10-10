// The constants of a COM object's type library, as .OLEObject's getConstant
// gives them (notes/netobject-design.md, "COM constants").
//
// .net~getConstant(o, name): the value of the constant called name
// (caselessly), or .nil; .net~getConstant(o): all of them (a StringTable).
// The constants are those of the type library holding the object's
// IDispatch type information: the members of its enums (xlHAlignRight,
// olFolderInbox, ForReading...) and the constants of its modules. Read once
// per type library and remembered.
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using ComTypes = System.Runtime.InteropServices.ComTypes;

namespace Rexx.Net;

[SupportedOSPlatform("windows")]
static class ComConstants
{
    static readonly object gate = new();
    static readonly Dictionary<(Guid, short, short, int), Dictionary<string, object?>> libraries = new();

    /// The constants of o's type library, by name (caseless; in the library's order).
    internal static Dictionary<string, object?> Of(object o)
    {
        if (!Com.Is(o)) throw new BridgeException(".net~getConstant: not a COM object reached through IDispatch");
        ComTypes.ITypeInfo? info = null;
        try
        {
            if (o is IDispatchInfo d && d.GetTypeInfo(0, 0x0409, out var t) == 0) info = t;
        }
        catch (Exception e) when (e is COMException || e is InvalidCastException) { }
        if (info == null) throw new BridgeException(".net~getConstant: the COM object gives no type information");
        info.GetContainingTypeLib(out var lib, out _);
        lib.GetLibAttr(out var pa);
        ComTypes.TYPELIBATTR la;
        try { la = Marshal.PtrToStructure<ComTypes.TYPELIBATTR>(pa); }
        finally { lib.ReleaseTLibAttr(pa); }
        var key = (la.guid, la.wMajorVerNum, la.wMinorVerNum, la.lcid);
        lock (gate)
        {
            if (libraries.TryGetValue(key, out var known)) return known;
            var all = Read(lib);
            libraries[key] = all;
            return all;
        }
    }

    static Dictionary<string, object?> Read(ComTypes.ITypeLib lib)
    {
        var all = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
        for (int i = 0, n = lib.GetTypeInfoCount(); i < n; i++)
        {
            lib.GetTypeInfoType(i, out var kind);
            if (kind != ComTypes.TYPEKIND.TKIND_ENUM && kind != ComTypes.TYPEKIND.TKIND_MODULE) continue;
            lib.GetTypeInfo(i, out var ti);
            ti.GetTypeAttr(out var pt);
            int vars;
            try { vars = Marshal.PtrToStructure<ComTypes.TYPEATTR>(pt).cVars; }
            finally { ti.ReleaseTypeAttr(pt); }
            for (int v = 0; v < vars; v++)
            {
                ti.GetVarDesc(v, out var pv);
                try
                {
                    var vd = Marshal.PtrToStructure<ComTypes.VARDESC>(pv);
                    if (vd.varkind != ComTypes.VARKIND.VAR_CONST) continue;
                    var names = new string[1];
                    ti.GetNames(vd.memid, names, 1, out int got);
                    if (got < 1 || string.IsNullOrEmpty(names[0])) continue;
                    object? value = Marshal.GetObjectForNativeVariant(vd.desc.lpvarValue);
                    all.TryAdd(names[0], value);            // the first of a name wins
                }
                finally { ti.ReleaseVarDesc(pv); }
            }
        }
        return all;
    }

    /// One constant (V: none of that name), or all of them as A [A names, A values].
    internal static void Get(object o, string? name, Writer w)
    {
        var all = Of(o);
        if (name != null)
        {
            if (all.TryGetValue(name.Trim(), out var value)) Conv.ToRexx(w, value);
            else w.Add('N', "");
            return;
        }
        var names = new Writer();
        var values = new Writer();
        foreach (var (n, v) in all) { names.Add('S', n); Conv.ToRexx(values, v); }
        var pair = new Writer();
        pair.Add('A', names.ToArray());
        pair.Add('A', values.ToArray());
        w.Add('A', pair.ToArray());
    }
}
