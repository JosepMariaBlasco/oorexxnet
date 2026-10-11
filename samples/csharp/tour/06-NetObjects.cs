// Both ways in one program: a .NET object to Rexx, which uses it through
// .net (net.cls is built in), and a C# delegate that Rexx calls.
using System.Text;
using Rexx.Net;

static class NetObjects
{
    public static void Run(RexxInterpreter rexx)
    {
        var sb = new StringBuilder("ab");
        Func<int, int> square = n => n * n;
        var result = rexx.Run("""
            use arg sb, square
            sb~Append("cd")~Append(.net~System~Math~Max(3, 7))
            return square~Invoke(12)                 -- a delegate: its Invoke
            ::requires "net.cls"
            """, sb, square);
        Console.WriteLine($"the StringBuilder: {sb}; the delegate gave {result}");
    }
}
