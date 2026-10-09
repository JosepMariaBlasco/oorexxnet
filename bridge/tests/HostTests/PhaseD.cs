// .NET -> ooRexx, phase D: .net from the start (notes/rexx-from-net-design.md,
// "Phase D: built"). net.cls and CLR.CLS come from inside Rexx.Net (loaded
// under their names), rexxnet gets the managed entry points directly, and
// the built-in packages survive another instance's end.
using System.IO;
using Rexx.Net;

static partial class Program
{
    static void PhaseD(RexxInterpreter rexx)
    {
        // the packages loaded are the built-in ones (their name is not a path)
        Ok("D: net.cls built in",     rexx.Run("return .NetObject~package~name\n::requires 'net.cls'"), "net.cls");
        Ok("D: CLR.CLS built in",     rexx.Run("return .CLR~package~name\n::requires CLR.CLS"), "CLR.CLS");
        // a program file anywhere, its ::requires found without a file
        var dir = Directory.CreateTempSubdirectory("rexxnet-d").FullName;
        try
        {
            var prog = Path.Combine(dir, "d.rex");
            File.WriteAllText(prog, "return .net~System~Math~Max(3, 7) .clr~new('System.Text.StringBuilder', 'ab')~Length\n" +
                                    "::requires \"net.cls\"\n::requires CLR.CLS\n");
            Ok("D: a file's ::requires", rexx.RunFile(prog), "7 2");
        }
        finally { Directory.Delete(dir, true); }
        // another instance, ended: ooRexx collects what nothing refers to
        using (var other = RexxInterpreter.Create())
            Ok("D: in another instance", other.Run("return .clr~new('System.Text.StringBuilder', 'abc')~Length\n::requires CLR.CLS"), "3");
        Ok("D: after it ended",       rexx.Run("return .clr~new('System.Text.StringBuilder', 'abcd')~Length\n::requires CLR.CLS"), "4");
        // RexxOptions.Net = false changes nothing once the packages are there
        using (var off = RexxInterpreter.Create(new RexxOptions { Net = false }))
            Ok("D: Net = false later",  off.Run("return .net~System~Math~Min(3, 7)\n::requires 'net.cls'"), "3");
    }
}
