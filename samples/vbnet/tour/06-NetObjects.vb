' Both ways in one program: a .NET object to Rexx, which uses it through
' .net (net.cls is built in), and a VB lambda (a Func) that Rexx calls.
Imports System.Text
Imports Rexx.Net

Module NetObjects
    Sub Run(rexx As RexxInterpreter)
        Dim sb As New StringBuilder("ab")
        Dim square As Func(Of Integer, Integer) = Function(n) n * n
        Dim result = rexx.Run("
use arg sb, square
sb~Append('cd')~Append(.net~System~Math~Max(3, 7))
return square~Invoke(12)                 -- a delegate: its Invoke
::requires 'net.cls'
", sb, square)
        Console.WriteLine($"the StringBuilder: {sb}; the delegate gave {result}")
    End Sub
End Module
