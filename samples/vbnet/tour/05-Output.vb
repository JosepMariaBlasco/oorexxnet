' Rexx's standard streams to .NET: SAY and LINEOUT into a TextWriter, PULL
' and LINEIN from a TextReader.
Imports System.IO
Imports Rexx.Net

Module Output
    Sub Run(rexx As RexxInterpreter)
        Dim captured As New StringWriter()
        rexx.Output = captured
        rexx.Input = New StringReader("Rexx" & vbLf & "1979" & vbLf)
        rexx.Run("
pull name
year = linein()
say 'Hello,' name'! Since' year'.'
")
        rexx.Output = Nothing                              ' the console again
        rexx.Input = Nothing
        Console.Write($"captured: {captured}")
    End Sub
End Module
