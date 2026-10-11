' Rexx's standard streams to .NET: SAY and LINEOUT into a TextWriter, PULL
' and LINEIN from a TextReader. On the console, Rexx's lines carry
' BSF4ooRexx's prefixes ("REXXout>", "REXXerr>", "REXXtrc>"; the prompt
' "REXXin?>"), so that they stand out in the application's output.
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
        rexx.Run("say 'on the console'")                   ' REXXout>on the console
        rexx.StreamPrefixes = False                        ' (or RexxOptions.StreamPrefixes)
        rexx.Run("say 'no prefix'")
        rexx.StreamPrefixes = True
    End Sub
End Module
