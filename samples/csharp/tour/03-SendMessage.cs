// Messages by name, as in BSF4ooRexx's RexxProxy (Java) and the Python
// bridge: SendMessage(name, args), SendMessage0 ... SendMessage5, and
// SendMessageScope, where the method search starts at a class (Rexx's
// o~name:scope). The name is any string: one held in a variable, or one
// that is no C# name ("[]=", "||").
using Rexx.Net;

static class SendMessages
{
    public static void Run(RexxInterpreter rexx)
    {
        var package = rexx.LoadPackage("shapes.cls", """
            ::class Shape public
            ::method describe; return "a shape"
            ::class Square public subclass Shape
            ::method describe; return "a square"
            ::method area;     use arg side; return side * side
            ::class Circle public subclass Shape
            ::method describe; return "a circle"
            ::method area;     use arg r; return 3.14159 * r * r
            """);
        RexxClass square = package.FindClass("Square")!, circle = package.FindClass("Circle")!;
        RexxObject s = square.New()!;

        string message = "describe";                                   // a name in a variable
        Console.WriteLine($"{s.SendMessage(message)} {s.SendMessage1("area", 3)} " +
                          $"{circle.New()!.SendMessage("area", new object?[] { 1 })}");   // args as an array
        Console.WriteLine(s.SendMessageScope("describe", square.SuperClass!));   // Shape's describe

        RexxObject d = rexx.Run("return .directory~new")!;
        d.SendMessage2("[]=", "ooRexx", "lang");                       // d["lang"] = "ooRexx"
        Console.WriteLine($"{d.SendMessage1("[]", "lang")} {d.SendMessage0("items")}");
    }
}
