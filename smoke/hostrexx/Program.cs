// .NET -> ooRexx: runs a Rexx program from a C# string through the classic
// API (RexxStart in librexx), passes it an argument and gets its result.
using System;
using System.Runtime.InteropServices;
using System.Text;

static class Rexx
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RXSTRING { public nuint strlength; public IntPtr strptr; }

    [DllImport("rexx", CallingConvention = CallingConvention.Cdecl)]
    public static extern int RexxStart(nuint argc, RXSTRING[] argv, string name, RXSTRING[] instore,
        string? envname, int calltype, IntPtr exits, out short rc, ref RXSTRING result);

    [DllImport("rexx", CallingConvention = CallingConvention.Cdecl)]
    public static extern int RexxFreeMemory(IntPtr p);

    const int RXFUNCTION = 2;

    static RXSTRING Str(string s)
    {
        var b = Encoding.UTF8.GetBytes(s);
        var p = Marshal.AllocHGlobal(b.Length + 1);
        Marshal.Copy(b, 0, p, b.Length); Marshal.WriteByte(p, b.Length, 0);
        return new RXSTRING { strlength = (nuint)b.Length, strptr = p };
    }

    // runs source as a function with one argument; returns its result
    public static string Call(string source, string arg)
    {
        var instore = new[] { Str(source), new RXSTRING() };   // [1]: no image
        var argv = new[] { Str(arg) };
        var result = new RXSTRING();
        int code = RexxStart(1, argv, "fromdotnet.rex", instore, null, RXFUNCTION, IntPtr.Zero, out short rc, ref result);
        if (code != 0) throw new InvalidOperationException($"RexxStart returned {code} (a Rexx error: {-code})");
        string value = result.strptr == IntPtr.Zero ? "" : Marshal.PtrToStringUTF8(result.strptr, (int)result.strlength);
        if (result.strptr != IntPtr.Zero) RexxFreeMemory(result.strptr);
        return value;
    }
}

static class Program
{
    static int Main()
    {
        var program = "parse arg n\n" +
                      "say 'Rexx says: hello from' .context~package~name 'with' n\n" +
                      "return reverse(n) n**2 .array~of(1, 2, 3)~items\n";
        Console.WriteLine("C# got back: " + Rexx.Call(program, "12"));
        try { Rexx.Call("say 1 +", "x"); }
        catch (InvalidOperationException e) { Console.WriteLine("C# caught: " + e.Message); }
        return 0;
    }
}
