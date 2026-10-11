// Rexx's standard streams to .NET: SAY and LINEOUT into a TextWriter, PULL
// and LINEIN from a TextReader. On the console, Rexx's lines carry
// BSF4ooRexx's prefixes ("REXXout>", "REXXerr>", "REXXtrc>"; the prompt
// "REXXin?>"), so that they stand out in the application's output.
using Rexx.Net;

static class Output
{
    public static void Run(RexxInterpreter rexx)
    {
        var captured = new StringWriter();
        rexx.Output = captured;
        rexx.Input = new StringReader("Rexx\n1979\n");
        rexx.Run("""
            pull name
            year = linein()
            say "Hello," name"! Since" year"."
            """);
        rexx.Output = null;                                 // the console again
        rexx.Input = null;
        Console.Write($"captured: {captured}");
        rexx.Run("say 'on the console'");                  // REXXout>on the console
        rexx.StreamPrefixes = false;                        // (or RexxOptions.StreamPrefixes)
        rexx.Run("say 'no prefix'");
        rexx.StreamPrefixes = true;
    }
}
