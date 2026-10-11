// Rexx objects in C#: a class from a package, its instances through
// dynamic or Send, Rexx collections, a Rexx object kept by .NET.
using Rexx.Net;

static class RexxObjects
{
    const string Source = """
        ::class Account public
        ::attribute balance get
        ::method init;     expose balance; use arg balance = 0
        ::method deposit;  expose balance; use arg n; balance += n; return balance
        ::method withdraw; expose balance; use arg n
          if n > balance then raise syntax 88.900 array("insufficient funds:" balance)
          balance -= n; return balance
        """;

    public static void Run(RexxInterpreter rexx)
    {
        var package = rexx.LoadPackage("account.cls", Source);
        RexxClass account = package.FindClass("Account")!;

        // dynamic: methods and attributes by name, as in Rexx (names are caseless)
        dynamic a = account.New(100)!;
        a.Deposit(50);
        int balance = a.Balance;
        Console.WriteLine($"balance {balance}");

        // Send / Send<T>: the message name as a string
        RexxObject b = account.New()!;
        b.Send("deposit", 30);
        Console.WriteLine($"another account: {b.Send<int>("balance")}");
        try { b.Send("withdraw", 1000); }
        catch (RexxException e) { Console.WriteLine($"refused: {e.Message}"); }

        // Rexx collections: [] is Rexx's own, foreach gives the items
        RexxObject array = rexx.NewArray("Rexx", "ooRexx", "NetRexx");
        Console.WriteLine($"{array.Send("items")} items, the second {array[2]}");
        foreach (var item in array) Console.Write($"{item} ");
        Console.WriteLine();
        RexxObject dir = rexx.NewDirectory(new Dictionary<string, object?> { ["name"] = "Rexx", ["year"] = 1979 });
        Console.WriteLine($"{dir["name"]} {dir["year"]}");                     // a Directory's indexes: exact
    }
}
