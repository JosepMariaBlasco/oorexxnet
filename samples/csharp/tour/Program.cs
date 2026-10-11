// A tour of .NET running ooRexx, in C#: each file is one topic, a static
// class with Run(rexx). Its VB.NET twin is samples/vbnet/tour.
//
//   dotnet run                      every topic, in order
//   dotnet run -- sendmessage ...   only those
using Rexx.Net;

var topics = new (string Name, Action<RexxInterpreter> Run)[]
{
    ("run",         RunRexx.Run),          // 01-RunRexx.cs
    ("objects",     RexxObjects.Run),      // 02-RexxObjects.cs
    ("sendmessage", SendMessages.Run),     // 03-SendMessage.cs
    ("address",     Address.Run),          // 04-Address.cs
    ("output",      Output.Run),           // 05-Output.cs
    ("netobjects",  NetObjects.Run),       // 06-NetObjects.cs
};
var unknown = args.Where(a => !topics.Any(t => t.Name.Equals(a, StringComparison.OrdinalIgnoreCase))).ToList();
if (unknown.Count > 0)
{
    Console.Error.WriteLine($"unknown: {string.Join(" ", unknown)}; the topics: {string.Join(" ", topics.Select(t => t.Name))}");
    return 2;
}

using var rexx = RexxInterpreter.Create();
Console.WriteLine($"ooRexx {rexx.Version}");
foreach (var (name, run) in topics)
{
    if (args.Length > 0 && !args.Contains(name, StringComparer.OrdinalIgnoreCase)) continue;
    Console.WriteLine($"===== {name}");
    run(rexx);
}
return 0;
