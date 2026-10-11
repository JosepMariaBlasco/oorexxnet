// An ADDRESS environment that the application provides: Rexx's commands go
// to C# code, which answers RC.
using Rexx.Net;

static class Address
{
    public static void Run(RexxInterpreter rexx)
    {
        var stock = new Dictionary<string, int> { ["apples"] = 12, ["pears"] = 0 };
        rexx.AddCommandEnvironment("STOCK", command =>
        {
            var words = command.Command.Split(' ', StringSplitOptions.RemoveEmptyEntries);
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
