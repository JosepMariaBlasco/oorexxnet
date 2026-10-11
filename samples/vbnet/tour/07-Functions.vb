' Functions and VALUE selectors that the application provides: Rexx calls
' VB code by name, as it calls any function.
Imports Rexx.Net

Module AppFunctions
    Sub Run(rexx As RexxInterpreter)
        Dim prices As New Dictionary(Of String, Decimal)(StringComparer.OrdinalIgnoreCase) From {{"apples", 1.20D}, {"pears", 2.05D}}
        ' a typed lambda: its parameters get the arguments, converted by Rexx's rules
        rexx.AddFunction("price",
            Function(item As String) As Decimal
                Dim p As Decimal
                If prices.TryGetValue(item, p) Then Return p
                Throw New KeyNotFoundException($"no price for {item}")
            End Function)
        ' a method with a ParamArray: any number of arguments; Optional: one that may be left out
        rexx.AddFunction("total", New Func(Of Decimal(), Decimal)(AddressOf Total))
        rexx.AddFunction("label", New Func(Of String, Integer, String)(AddressOf Label))
        ' the whole call: its name, arguments, and the caller's variables
        rexx.AddFunction("whereAmI",
            Function(fcall As RexxFunctionCall) As Object
                Return $"{fcall.Name}({fcall.Arguments.Count} args), fruit = {fcall("FRUIT")}"
            End Function)
        ' VALUE(name, , "APP") reads the application's settings, VALUE(name, new, "APP") sets them
        Dim settings As New Dictionary(Of String, Object)(StringComparer.OrdinalIgnoreCase) From {{"currency", "EUR"}}
        rexx.AddValueSelector("APP",
            Function(name As String) If(settings.ContainsKey(name), settings(name), Nothing),
            Sub(name As String, value As Object) settings(name) = value)

        rexx.Run("
currency = value('currency', , 'APP')
do fruit over 'apples', 'pears'
  say label(fruit) price(fruit) currency
end
say label('both', 20) total(price('apples'), price('pears')) currency
say whereAmI(1, 2)
signal on syntax
say price('figs')
syntax:
  say 'error' condition('O')~code':' condition('O')~message
")
    End Sub

    Function Total(ParamArray amounts As Decimal()) As Decimal
        Return amounts.Sum()
    End Function

    Function Label(text As String, Optional width As Integer = 12) As String
        Return text.PadRight(width, "."c)
    End Function
End Module
