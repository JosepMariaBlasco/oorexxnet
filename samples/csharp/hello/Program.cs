// A .NET application that runs Rexx code (the NuGet package Rexx.Net).
using System.Text;
using Rexx.Net;

using var rexx = RexxInterpreter.Create();
Console.WriteLine($"ooRexx {rexx.Version}, language level {rexx.LanguageLevel}");

// Rexx code, its result converted to a .NET type
Console.WriteLine(rexx.Run<int>("use arg a, b; return a * b", 6, 7));

// a Rexx class, used from C# through dynamic
var pkg = rexx.LoadPackage("account.cls", """
    ::class Account public
    ::attribute balance get
    ::method init;    expose balance; use arg balance = 0
    ::method deposit; expose balance; use arg n; balance += n; return balance
    """);
dynamic account = pkg.FindClass("Account")!.New(100)!;
account.Deposit(50);
Console.WriteLine($"balance: {(int)account.Balance}");

// Rexx's output into a StringWriter; an ADDRESS environment the application provides
var output = new StringWriter();
rexx.Output = output;
rexx.AddCommandEnvironment("APP", cmd => cmd.Command.ToUpperInvariant());
rexx.Run("address app 'shout'; say 'the command gave' rc");
rexx.Output = null;
Console.Write($"captured: {output}");

// a .NET object to Rexx, which uses it through .net (net.cls is built in)
var sb = new StringBuilder("ab");
rexx.Run("""
    use arg sb
    sb~Append("cd")~Append(.net~System~Math~Max(3, 7))
    ::requires "net.cls"
    """, sb);
Console.WriteLine($"the StringBuilder now: {sb}");
