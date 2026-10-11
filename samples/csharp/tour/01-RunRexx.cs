// Running Rexx code: a routine from source, its arguments, its result.
using Rexx.Net;

static class RunRexx
{
    public static void Run(RexxInterpreter rexx)
    {
        // Run: the source of a routine, its arguments; the result is a
        // RexxObject (a RexxString for a string), or Run<T> converts it
        Console.WriteLine(rexx.Run("use arg a, b; return a '+' b '=' a + b", 2, 40));
        int product = rexx.Run<int>("use arg a, b; return a * b", 6, 7);
        double quarter = rexx.Run<double>("return 1 / 4");
        decimal big = rexx.Run<decimal>("numeric digits 30; return 2 ** 70");   // Rexx's arbitrary precision
        Console.WriteLine($"{product} {quarter} {big}");

        // .NET values as Rexx strings: bool as 1 / 0, null as .nil
        Console.WriteLine(rexx.Run("use arg flag, x, none; return flag x (none == .nil)", true, 0.5, null));

        // a Rexx error is a RexxException, with the condition's details
        try { rexx.Run("say 1 / 0"); }
        catch (RexxException e) { Console.WriteLine($"{e.ConditionName} {e.Code}: {e.ErrorText}"); }
    }
}
