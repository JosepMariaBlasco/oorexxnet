// Functions and VALUE selectors that the application provides: Rexx calls
// C# code by name, as it calls any function.
using Rexx.Net;

static class Functions
{
    public static void Run(RexxInterpreter rexx)
    {
        var prices = new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase) { ["apples"] = 1.20m, ["pears"] = 2.05m };
        // a typed lambda: its parameters get the arguments, converted by Rexx's rules
        rexx.AddFunction("price", (string item) => prices.TryGetValue(item, out var p) ? p : throw new KeyNotFoundException($"no price for {item}"));
        // params: any number of arguments; a default value: an argument that may be left out
        rexx.AddFunction("total", (params decimal[] amounts) => amounts.Sum());
        rexx.AddFunction("label", (string text, int width = 12) => text.PadRight(width, '.'));
        // the whole call: its name, arguments, and the caller's variables
        rexx.AddFunction("whereAmI", call => $"{call.Name}({call.Arguments.Count} args), fruit = {call["FRUIT"]}");
        // VALUE(name, , "APP") reads the application's settings, VALUE(name, new, "APP") sets them
        var settings = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase) { ["currency"] = "EUR" };
        rexx.AddValueSelector("APP", name => settings.GetValueOrDefault(name), (name, value) => settings[name] = value);

        rexx.Run("""
            currency = value("currency", , "APP")
            do fruit over "apples", "pears"
              say label(fruit) price(fruit) currency
            end
            say label("both", 20) total(price("apples"), price("pears")) currency
            say whereAmI(1, 2)
            signal on syntax
            say price("figs")
            syntax:
              say "error" condition("O")~code":" condition("O")~message
            """);
    }
}
