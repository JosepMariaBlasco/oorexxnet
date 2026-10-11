// BSF4ooRexx's prefixes on the standard streams (RexxOptions.StreamPrefixes,
// RexxInterpreter.StreamPrefixes). They go to the process's own streams, so
// the tests run this program again as a child (argument "prefixes-child")
// and read what it wrote.
using System;
using System.Diagnostics;
using System.IO;
using Rexx.Net;

static partial class Program
{
    // The child: Rexx code writing and reading through the process's streams.
    static int PrefixesChild()
    {
        using var rexx = RexxInterpreter.Create();
        rexx.Run("say 'one'; call charout , 'a'; call charout , 'b' || '0a'x || 'c'; say 'd'");
        rexx.Run("say 'two' || '0a'x || 'lines'; .output~lineout('three')");
        rexx.Run(".error~lineout('e1'); call lineout 'STDERR', 'e2'");
        rexx.Run("trace r; x = 1; trace off");
        rexx.Run("parse pull a; say 'read' a; parse value .debugInput~linein with b; say 'debug' b");
        rexx.Run(".output~current~prefix = 'mine>'; say 'custom'; .output~current~prefix = .nil; say 'bare'; .output~current~prefix = 'REXXout>'");
        var o = new StringWriter();
        rexx.Output = o;
        rexx.Run("say 'captured'");
        rexx.Output = null;
        Console.Out.Flush();
        Console.WriteLine("NET>" + o.ToString().TrimEnd());
        Console.Out.Flush();
        rexx.StreamPrefixes = false;
        rexx.Run("say 'off'; pull c; say 'read' c");
        rexx.StreamPrefixes = true;
        rexx.Run("say 'on'");
        using (var plain = RexxInterpreter.Create(new RexxOptions { StreamPrefixes = false }))
            plain.Run("say 'plain'");
        return 0;
    }

    static void Prefixes()
    {
        var self = Environment.ProcessPath!;
        var dll = typeof(Program).Assembly.Location;
        var psi = new ProcessStartInfo(self)
        {
            RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true, UseShellExecute = false,
        };
        if (Path.GetFileNameWithoutExtension(self) is "dotnet") psi.ArgumentList.Add(dll);
        psi.ArgumentList.Add("prefixes-child");
        foreach (var v in new[] { "REXXNET_DIR", "LD_LIBRARY_PATH", "REXX_HOME", "PATH" })
            if (Environment.GetEnvironmentVariable(v) is string s) psi.Environment[v] = s;
        using var p = Process.Start(psi)!;
        p.StandardInput.Write("x\ny\nz\n");
        p.StandardInput.Close();
        var errTask = p.StandardError.ReadToEndAsync();
        var outText = p.StandardOutput.ReadToEnd().Replace("\r", "");
        p.WaitForExit();
        var errText = errTask.Result.Replace("\r", "");
        Ok("prefixes: child ran", p.ExitCode, 0);
        Ok("prefixes: .output", outText,
           "REXXout>one\nREXXout>ab\nREXXout>cd\n" +
           "REXXout>two\nREXXout>lines\nREXXout>three\n" +
           "REXXin?>REXXout>read x\nREXXdbgIn?>REXXout>debug y\n" +
           "mine>custom\nbare\n" +
           "NET>captured\n" +
           "off\nread Z\nREXXout>on\nplain\n");
        var errLines = errText.Split('\n', StringSplitOptions.RemoveEmptyEntries);
        Ok("prefixes: .error", errLines.Length >= 2 ? errLines[0] + "|" + errLines[1] : errText, "REXXerr>e1|REXXerr>e2");
        Ok("prefixes: .traceOutput", errLines.Length > 2 && Array.TrueForAll(errLines[2..], l => l.StartsWith("REXXtrc>")) && errText.Contains("*-* x = 1;"), true);
    }
}
