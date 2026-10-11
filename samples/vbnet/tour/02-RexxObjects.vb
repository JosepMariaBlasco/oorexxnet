' Rexx objects in VB.NET: a class from a package, its instances through late
' binding (Object, Option Strict Off) or Send, Rexx collections.
Imports Rexx.Net

Module RexxObjects
    Const Source As String = "
::class Account public
::attribute balance get
::method init;     expose balance; use arg balance = 0
::method deposit;  expose balance; use arg n; balance += n; return balance
::method withdraw; expose balance; use arg n
  if n > balance then raise syntax 88.900 array('insufficient funds:' balance)
  balance -= n; return balance
"

    Sub Run(rexx As RexxInterpreter)
        Dim pkg = rexx.LoadPackage("account.cls", Source)
        Dim account As RexxClass = pkg.FindClass("Account")

        ' (New is a VB keyword: a class's New method is [New])
        ' late binding: methods and attributes by name, as in Rexx (names are caseless)
        Dim a As Object = account.[New](100)
        a.Deposit(50)
        Dim balance As Integer = a.Balance
        Console.WriteLine($"balance {balance}")

        ' Send / Send(Of T): the message name as a string
        Dim b As RexxObject = account.[New]()
        b.Send("deposit", 30)
        Console.WriteLine($"another account: {b.Send(Of Integer)("balance")}")
        Try
            b.Send("withdraw", 1000)
        Catch e As RexxException
            Console.WriteLine($"refused: {e.Message}")
        End Try

        ' Rexx collections: the indexer is Rexx's own [], For Each gives the items
        Dim array As RexxObject = rexx.NewArray("Rexx", "ooRexx", "NetRexx")
        Console.WriteLine($"{array.Send("items")} items, the second {array(2)}")
        For Each item In array
            Console.Write($"{item} ")
        Next
        Console.WriteLine()
        Dim dir As RexxObject = rexx.NewDirectory(New Dictionary(Of String, Object) From {{"name", "Rexx"}, {"year", 1979}})
        Console.WriteLine($"{dir("name")} {dir("year")}")                      ' a Directory's indexes: exact
    End Sub
End Module
