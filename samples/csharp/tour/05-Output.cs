// Rexx's standard streams to .NET: SAY and LINEOUT into a TextWriter, PULL
// and LINEIN from a TextReader.
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
    }
}
