// The managed side of the probe: called from native code (the ooRexx
// extension) through hostfxr's load_assembly_and_get_function_pointer.
using System;
using System.Globalization;
using System.Reflection;
using System.Runtime.InteropServices;

namespace Probe;

public static class Entry
{
    // typeName.method(args...) for a static method, by reflection; the
    // arguments and the result travel as UTF-8 strings (args separated by \t).
    // Returns the length written to outBuf, or -1 (the error text in outBuf).
    [UnmanagedCallersOnly]
    public static int CallStatic(IntPtr typeName, IntPtr method, IntPtr args, IntPtr outBuf, int outLen)
    {
        string result;
        int rc;
        try
        {
            var type = Type.GetType(Marshal.PtrToStringUTF8(typeName)!, throwOnError: true)!;
            var name = Marshal.PtrToStringUTF8(method)!;
            var text = Marshal.PtrToStringUTF8(args) ?? "";
            var words = text.Length == 0 ? Array.Empty<string>() : text.Split('\t');
            object? value = null;
            bool found = false;
            foreach (var m in type.GetMethods(BindingFlags.Public | BindingFlags.Static))
            {
                if (m.Name != name) continue;
                var ps = m.GetParameters();
                if (ps.Length != words.Length) continue;
                try
                {
                    var conv = new object?[ps.Length];
                    for (int i = 0; i < ps.Length; i++)
                        conv[i] = Convert.ChangeType(words[i], ps[i].ParameterType, CultureInfo.InvariantCulture);
                    value = m.Invoke(null, conv);
                    found = true;
                    break;
                }
                catch (FormatException) { }
                catch (InvalidCastException) { }
            }
            if (!found) throw new MissingMethodException(type.FullName, name);
            result = Convert.ToString(value, CultureInfo.InvariantCulture) ?? "";
            rc = 0;
        }
        catch (Exception e)
        {
            var inner = e is TargetInvocationException t && t.InnerException != null ? t.InnerException : e;
            result = inner.GetType().Name + ": " + inner.Message;
            rc = -1;
        }
        var bytes = System.Text.Encoding.UTF8.GetBytes(result);
        int n = Math.Min(bytes.Length, outLen - 1);
        Marshal.Copy(bytes, 0, outBuf, n);
        Marshal.WriteByte(outBuf, n, 0);                 // always terminated
        return rc < 0 ? -1 : n;
    }
}
