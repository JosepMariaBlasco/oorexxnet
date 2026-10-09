/* check.rex: checks the ooRexx/.NET bridge (Windows binary package).
   rexx check.rex          versions, a StringBuilder, a MessageBox
   rexx check.rex nogui    the same, without opening any window          */
parse version v
say "ooRexx:" v
say ".NET:  " .net~System~Runtime~InteropServices~RuntimeInformation~FrameworkDescription
sb = .net~System~Text~StringBuilder~new("Hello")
sb~Append(", ")~Append("world")
say "StringBuilder:" sb~ToString sb~Length

signal on syntax name noForms
f = .net~System~Windows~Forms~Form~new
f~Text = "check.rex"
f~Dispose
signal off syntax
say "Windows Forms: ok"
if arg(1)~strip~caselessEquals("nogui") then exit 0
.net~System~Windows~Forms~MessageBox~Show("ooRexx/.NET works.", "check.rex")
say "MessageBox: ok"
exit 0

noForms:
say "Windows Forms: not available (the .NET Desktop Runtime is not installed?)"
say "  " condition('O')~message
exit 1

::requires "net.cls"
