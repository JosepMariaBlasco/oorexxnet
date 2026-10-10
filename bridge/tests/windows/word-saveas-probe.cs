#:property PublishAot=false
#:property BuiltInComInteropSupport=true
// Why does Word's Document.SaveAs2(file, 16) fail through the bridge
// (DISP_E_TYPEMISMATCH) when .OLEObject's succeeds? This probe makes the same
// call several ways and prints what each gives, and what SaveAs2's type
// information says of its parameters.
//
// Windows with Word and the .NET 10 SDK:  dotnet run word-saveas-probe.cs
// Word stays hidden; every file goes to the temporary folder and is deleted.
//
// The bridge calls COM objects with Type.InvokeMember (BindingFlags
// InvokeMethod | GetProperty, en-US), every argument by value: a Rexx number
// as an int. .OLEObject reads the type information and passes a VARIANT* parameter
// by reference. If the by-reference variants succeed and the by-value ones
// fail, Word wants SaveAs2's arguments by reference.
using System;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

const BindingFlags Bridge = BindingFlags.InvokeMethod | BindingFlags.GetProperty;
var english = CultureInfo.GetCultureInfo("en-US");
string dir = Path.GetTempPath();
int n = 0;

Console.WriteLine($".NET {Environment.Version}, {RuntimeInformation.OSDescription}, user culture {CultureInfo.CurrentCulture.Name}");
var type = Type.GetTypeFromProgID("Word.Application") ?? throw new Exception("Word is not installed");
object word = Activator.CreateInstance(type)!;
try
{
    Console.WriteLine($"Word {Get(word, "Version")}, build {Get(word, "Build")}");
    object docs = Get(word, "Documents")!;
    object doc = docs.GetType().InvokeMember("Add", Bridge, null, docs, null, english)!;
    object range = doc.GetType().InvokeMember("Range", Bridge, null, doc, null, english)!;
    range.GetType().InvokeMember("Text", BindingFlags.SetProperty, null, range, new object[] { "SaveAs2 probe" }, english);

    TypeInfo(doc, "SaveAs2");
    TypeInfo(doc, "SaveAs");

    Console.WriteLine();
    Try("bridge: (file, 16) by value, int, en-US", f => Call(doc, "SaveAs2", Bridge, new object[] { f, 16 }, null, english));
    Try("(file, 16) by value, InvokeMethod only", f => Call(doc, "SaveAs2", BindingFlags.InvokeMethod, new object[] { f, 16 }, null, english));
    Try("(file, 16) by value, user culture", f => Call(doc, "SaveAs2", Bridge, new object[] { f, 16 }, null, CultureInfo.CurrentCulture));
    Try("(file, (short) 16) by value", f => Call(doc, "SaveAs2", Bridge, new object[] { f, (short)16 }, null, english));
    Try("(file, 16) both by reference", f => Call(doc, "SaveAs2", Bridge, new object[] { f, 16 }, new[] { true, true }, english));
    Try("(file, 16) file by reference only", f => Call(doc, "SaveAs2", Bridge, new object[] { f, 16 }, new[] { true, false }, english));
    Try("(file, 16) format by reference only", f => Call(doc, "SaveAs2", Bridge, new object[] { f, 16 }, new[] { false, true }, english));
    Try("named FileName, FileFormat, by value", f => doc.GetType().InvokeMember("SaveAs2", Bridge, null, doc,
                                                       new object[] { f, 16 }, null, english, new[] { "FileName", "FileFormat" }));
    Try("(file) alone, by value", f => Call(doc, "SaveAs2", Bridge, new object[] { f }, null, english));
    Try("(file) alone, by reference", f => Call(doc, "SaveAs2", Bridge, new object[] { f }, new[] { true }, english));
    Try("C# dynamic: doc.SaveAs2(file, 16)", f => { dynamic d = doc; d.SaveAs2(f, 16); });
    Try("C# dynamic: doc.SaveAs2(file)", f => { dynamic d = doc; d.SaveAs2(f); });
    Try("SaveAs (not 2), (file, 16) by value", f => Call(doc, "SaveAs", Bridge, new object[] { f, 16 }, null, english));

    doc.GetType().InvokeMember("Close", Bridge, null, doc, new object[] { 0 }, english);   // wdDoNotSaveChanges
}
finally
{
    try { word.GetType().InvokeMember("Quit", Bridge, null, word, new object[] { 0 }, english); }
    catch (Exception e) { Console.WriteLine("Quit: " + e.Message); }
}
return;

object? Get(object o, string name) => o.GetType().InvokeMember(name, Bridge, null, o, null, english);

object? Call(object o, string name, BindingFlags how, object[] args, bool[]? byRef, CultureInfo culture)
{
    ParameterModifier[]? mods = null;
    if (byRef != null)
    {
        var m = new ParameterModifier(args.Length);
        for (int i = 0; i < byRef.Length; i++) m[i] = byRef[i];
        mods = new[] { m };
    }
    return o.GetType().InvokeMember(name, how, null, o, args, mods, culture, null);
}

void Try(string what, Action<string> call)
{
    string file = Path.Combine(dir, $"saveas-probe-{++n}.docx");
    File.Delete(file);
    string result;
    try
    {
        call(file);
        result = File.Exists(file) ? $"OK, {new FileInfo(file).Length} bytes" : "no error, but no file";
    }
    catch (Exception e)
    {
        while (e is TargetInvocationException { InnerException: not null }) e = e.InnerException!;
        result = $"{e.GetType().Name} 0x{e.HResult:X8}: {e.Message.Trim()}";
    }
    Console.WriteLine($"{n,2}. {what}\n    {result}");
}

void TypeInfo(object o, string name)
{
    try
    {
        var disp = (IDispatchInfo)o;
        Marshal.ThrowExceptionForHR(disp.GetTypeInfo(0, 0x409, out var ti));
        ti.GetDocumentation(-1, out var tname, out _, out _, out _);
        ti.GetTypeAttr(out IntPtr pa);
        var ta = Marshal.PtrToStructure<TYPEATTR>(pa);
        ti.ReleaseTypeAttr(pa);
        for (int i = 0; i < ta.cFuncs; i++)
        {
            ti.GetFuncDesc(i, out IntPtr pf);
            var fd = Marshal.PtrToStructure<FUNCDESC>(pf);
            var names = new string[fd.cParams + 1];
            ti.GetNames(fd.memid, names, names.Length, out int got);
            if (string.Equals(names[0], name, StringComparison.OrdinalIgnoreCase))
            {
                Console.WriteLine($"\n{tname}.{names[0]}: DISPID {fd.memid}, {fd.funckind}, {fd.invkind}, " +
                                  $"{fd.cParams} parameters ({fd.cParamsOpt} optional)");
                int size = Marshal.SizeOf<ELEMDESC>();
                for (int p = 0; p < fd.cParams; p++)
                {
                    var ed = Marshal.PtrToStructure<ELEMDESC>(fd.lprgelemdescParam + p * size);
                    Console.WriteLine($"  {p + 1,2}. {(p + 1 < got ? names[p + 1] : "?"),-24} {Vt(ed.tdesc)}  {ed.desc.paramdesc.wParamFlags}");
                }
            }
            ti.ReleaseFuncDesc(pf);
        }
    }
    catch (Exception e) { Console.WriteLine($"type information for {name}: {e.Message}"); }
}

static string Vt(TYPEDESC t)
{
    var vt = (VarEnum)t.vt;
    if (vt == VarEnum.VT_PTR) return "VT_PTR to " + Vt(Marshal.PtrToStructure<TYPEDESC>(t.lpValue));
    return vt.ToString();
}

[ComImport, Guid("00020400-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IDispatchInfo
{
    [PreserveSig] int GetTypeInfoCount(out uint count);
    [PreserveSig] int GetTypeInfo(uint index, int lcid, out ITypeInfo info);
}
