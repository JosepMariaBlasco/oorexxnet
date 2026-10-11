// COM objects' type information, as .OLEObject's getKnownMethods and
// getKnownEvents give it (notes/netobject-design.md, "COM objects: built"):
// .net~getKnownMethods(o) and .net~getKnownEvents(o) build the same stems
// (m.0; m.i.!NAME, !DOC, !PARAMS.0, !PARAMS.j.!NAME / !TYPE / !FLAGS; for
// methods also !MEMID, !RETTYPE, !INVKIND), from the records made here:
//
//   comMethods O -> A [S|N library, S|N its doc, S|N coclass, S|N its doc, S|N CLSID, S|N ProgID,
//                      A [A [S name, S memid, S rettype, S invkind, S|N doc, A [A [S name, S type, S flags]]]...]], or N
//   (the stem's !LIBNAME, !LIBDOC, !COCLASSNAME, !COCLASSDOC as .OLEObject's; !CLSID and !PROGID the bridge's,
//   for .OLEObject's o~clsid and o~progid)
//   comEvents  O -> A [A [S name, N, N, N, S|N doc, A [...]]...], or N
//
// As .OLEObject: restricted and hidden members, and names that start with
// "_", are left out; types are VARTYPE names ("VT_BSTR", "VT_BYREF VT_I4");
// a parameter's flags "[in]", "[out]", "[in,opt]"... ("" when none).
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using ComTypes = System.Runtime.InteropServices.ComTypes;

namespace Rexx.Net;

[SupportedOSPlatform("windows")]
static class ComInfo
{
    const int FUNCFLAG_FRESTRICTED = 1, FUNCFLAG_FHIDDEN = 0x40;
    const int PARAMFLAG_FIN = 1, PARAMFLAG_FOUT = 2;

    internal static void Methods(object o, Writer w)
    {
        if (!Com.Is(o)) throw new BridgeException("not a COM object");
        ComTypes.ITypeInfo? ti = null;
        try { if (o is IDispatchInfo d && d.GetTypeInfo(0, 0x0409, out var t) == 0) ti = t; }
        catch (Exception e) when (e is COMException or InvalidCastException) { }
        if (ti == null) { w.Add('N', ""); return; }
        var r = new Writer();
        string? libName = null, libDoc = null, ccName = null, ccDoc = null, clsid = null, progId = null;
        try
        {
            ti.GetContainingTypeLib(out var lib, out _);
            lib.GetDocumentation(-1, out libName, out libDoc, out _, out _);
        }
        catch (COMException) { }
        try
        {
            if (o is IProvideClassInfo pci && pci.GetClassInfo(out var ci) == 0 && ci != null)
            {
                ci.GetDocumentation(-1, out ccName, out ccDoc, out _, out _);
                var guid = ComEvents.Attr(ci).guid;
                clsid = guid.ToString("B").ToUpperInvariant();
                if (ProgIDFromCLSID(ref guid, out var p) == 0 && p != 0) { progId = Marshal.PtrToStringUni(p); Marshal.FreeCoTaskMem(p); }
            }
        }
        catch (Exception e) when (e is COMException or InvalidCastException) { }
        foreach (var v in new[] { libName, libDoc, ccName, ccDoc, clsid, progId })
            if (string.IsNullOrEmpty(v)) r.Add('N', ""); else r.Add('S', v);
        var all = new Writer();
        Describe(ti, all, new HashSet<string>(StringComparer.OrdinalIgnoreCase), events: false);
        r.Add('A', all.ToArray());
        w.Add('A', r.ToArray());
    }

    internal static void Events(object o, Writer w)
    {
        if (!Com.Is(o)) throw new BridgeException("not a COM object");
        var sources = ComEvents.Sources(o);
        if (sources.Count == 0) { w.Add('N', ""); return; }
        var all = new Writer();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var (_, ti) in sources) Describe(ti, all, seen, events: true);
        w.Add('A', all.ToArray());
    }

    static void Describe(ComTypes.ITypeInfo ti, Writer all, HashSet<string> seen, bool events)
    {
        int n = ComEvents.Attr(ti).cFuncs;
        for (int i = 0; i < n; i++)
        {
            ti.GetFuncDesc(i, out var p);
            try
            {
                var fd = Marshal.PtrToStructure<ComTypes.FUNCDESC>(p);
                if ((fd.wFuncFlags & (FUNCFLAG_FRESTRICTED | FUNCFLAG_FHIDDEN)) != 0) continue;
                ti.GetDocumentation(fd.memid, out var name, out var doc, out _, out _);
                if (string.IsNullOrEmpty(name) || name.StartsWith('_')) continue;
                if (events && !seen.Add(name)) continue;
                var names = new string[fd.cParams + 1];
                ti.GetNames(fd.memid, names, names.Length, out int got);
                var e = new Writer();
                e.Add('S', name);
                if (events) { e.Add('N', ""); e.Add('N', ""); e.Add('N', ""); }
                else
                {
                    e.Add('S', fd.memid.ToString("x8"));
                    e.Add('S', VtName(fd.elemdescFunc.tdesc.vt));
                    e.Add('S', ((int)fd.invkind).ToString());
                }
                if (string.IsNullOrEmpty(doc)) e.Add('N', ""); else e.Add('S', doc);
                var ps = new Writer();
                int size = Marshal.SizeOf<ComTypes.ELEMDESC>();
                for (int j = 0; j < fd.cParams; j++)
                {
                    var ed = Marshal.PtrToStructure<ComTypes.ELEMDESC>(fd.lprgelemdescParam + j * size);
                    int f = (int)ed.desc.paramdesc.wParamFlags;
                    bool opt = j >= fd.cParams - fd.cParamsOpt;
                    var flags = new List<string>();
                    if ((f & PARAMFLAG_FIN) != 0) flags.Add("in");
                    if ((f & PARAMFLAG_FOUT) != 0) flags.Add("out");
                    if (opt) flags.Add("opt");
                    var pw = new Writer();
                    pw.Add('S', j + 1 < got ? names[j + 1] : "<unnamed>");
                    pw.Add('S', VtName(ed.tdesc.vt));
                    pw.Add('S', flags.Count > 0 ? "[" + string.Join(",", flags) + "]" : "");
                    ps.Add('A', pw.ToArray());
                }
                e.Add('A', ps.ToArray());
                all.Add('A', e.ToArray());
            }
            finally { ti.ReleaseFuncDesc(p); }
        }
    }

    // A VARTYPE's name, as .OLEObject writes it: "VT_BYREF VT_I4"
    [DllImport("ole32.dll")]
    static extern int ProgIDFromCLSID(ref Guid clsid, out nint progId);

    static string VtName(short vt)
    {
        int v = (ushort)vt;
        var s = "";
        if ((v & 0x1000) != 0) s += "VT_VECTOR ";
        if ((v & 0x2000) != 0) s += "VT_ARRAY ";
        if ((v & 0x4000) != 0) s += "VT_BYREF ";
        if ((v & 0x8000) != 0) s += "VT_RESERVED ";
        int t = v & 0x0FFF;
        var name = Enum.IsDefined(typeof(VarEnum), t) ? ((VarEnum)t).ToString() : "VT_" + t;
        return s + name;
    }
}
