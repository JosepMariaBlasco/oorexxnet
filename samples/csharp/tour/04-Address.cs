// An ADDRESS environment that the application provides: Rexx's commands go
// to C# code, which answers RC; it also gets ooRexx's .CommandContext of the
// code that sent the command (caller: its variables, its WITH redirection).
using Rexx.Net;

static class Address
{
    public static void Run(RexxInterpreter rexx)
    {
        var stock = new Dictionary<string, int> { ["apples"] = 12, ["pears"] = 0 };
        rexx.AddCommandEnvironment("STOCK", (command, caller) =>
        {
            var words = command.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            return words is ["COUNT", var item] ? stock.GetValueOrDefault(item.ToLowerInvariant(), -1) : -2;
        });
        rexx.Run("""
            address stock
            do fruit over "apples", "pears", "figs"
              "COUNT" fruit
              say fruit":" rc
            end
            """);
    }
}
