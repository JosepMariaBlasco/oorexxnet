' Running Rexx code: a routine from source, its arguments, its result.
Imports Rexx.Net

Module RunRexx
    Sub Run(rexx As RexxInterpreter)
        ' Run: the source of a routine, its arguments; the result is a
        ' RexxObject (a RexxString for a string), or Run(Of T) converts it
        Console.WriteLine(rexx.Run("use arg a, b; return a '+' b '=' a + b", 2, 40))
        Dim product As Integer = rexx.Run(Of Integer)("use arg a, b; return a * b", 6, 7)
        Dim quarter As Double = rexx.Run(Of Double)("return 1 / 4")
        Dim big As Decimal = rexx.Run(Of Decimal)("numeric digits 30; return 2 ** 70")   ' Rexx's arbitrary precision
        Console.WriteLine($"{product} {quarter} {big}")

        ' .NET values as Rexx strings: Boolean as 1 / 0, Nothing as .nil
        Console.WriteLine(rexx.Run("use arg flag, x, none; return flag x (none == .nil)", True, 0.5, Nothing))

        ' a Rexx error is a RexxException, with the condition's details
        Try
            rexx.Run("say 1 / 0")
        Catch e As RexxException
            Console.WriteLine($"{e.ConditionName} {e.Code}: {e.ErrorText}")
        End Try
    End Sub
End Module
