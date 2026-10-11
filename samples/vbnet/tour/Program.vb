' A tour of .NET running ooRexx, in VB.NET: each file is one topic, a module
' with Run(rexx). Its C# twin is samples/csharp/tour.
'
'   dotnet run                      every topic, in order
'   dotnet run -- sendmessage ...   only those
Imports Rexx.Net

Module Program
    Function Main(args As String()) As Integer
        Dim topics As New List(Of (Name As String, Run As Action(Of RexxInterpreter))) From {
            ("run", AddressOf RunRexx.Run),              ' 01-RunRexx.vb
            ("objects", AddressOf RexxObjects.Run),      ' 02-RexxObjects.vb
            ("sendmessage", AddressOf SendMessages.Run), ' 03-SendMessage.vb
            ("address", AddressOf AddressEnv.Run),       ' 04-Address.vb
            ("output", AddressOf Output.Run),            ' 05-Output.vb
            ("netobjects", AddressOf NetObjects.Run),    ' 06-NetObjects.vb
            ("functions", AddressOf AppFunctions.Run)    ' 07-Functions.vb
        }
        Dim unknown = args.Where(Function(a) Not topics.Any(Function(t) String.Equals(t.Name, a, StringComparison.OrdinalIgnoreCase))).ToList()
        If unknown.Count > 0 Then
            Console.Error.WriteLine($"unknown: {String.Join(" ", unknown)}; the topics: {String.Join(" ", topics.Select(Function(t) t.Name))}")
            Return 2
        End If

        Using rexx = RexxInterpreter.Create()
            Console.WriteLine($"ooRexx {rexx.Version}")
            For Each topic In topics
                If args.Length > 0 AndAlso Not args.Contains(topic.Name, StringComparer.OrdinalIgnoreCase) Then Continue For
                Console.WriteLine($"===== {topic.Name}")
                topic.Run(rexx)
            Next
        End Using
        Return 0
    End Function
End Module
