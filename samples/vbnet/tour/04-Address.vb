' An ADDRESS environment that the application provides: Rexx's commands go
' to VB code, which answers RC.
Imports Rexx.Net

Module AddressEnv
    Sub Run(rexx As RexxInterpreter)
        Dim stock As New Dictionary(Of String, Integer) From {{"apples", 12}, {"pears", 0}}
        rexx.AddCommandEnvironment("STOCK",
            Function(command As RexxCommand) As Object
                Dim words = command.Command.Split(" "c, StringSplitOptions.RemoveEmptyEntries)
                If words.Length = 2 AndAlso words(0) = "COUNT" Then
                    Dim n As Integer
                    Return If(stock.TryGetValue(words(1).ToLowerInvariant(), n), n, -1)
                End If
                Return -2
            End Function)
        rexx.Run("
address stock
do fruit over 'apples', 'pears', 'figs'
  'COUNT' fruit
  say fruit':' rc
end
")
    End Sub
End Module
