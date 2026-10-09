/* check.rex: checks the ooRexx/.NET bridge (Windows binary package).
   rexx check.rex          versions, a StringBuilder, a MessageBox
   rexx check.rex nogui    the same, without opening any window          */
parse version v
say "ooRexx:" v
say ".NET:  " .net~System~Runtime~InteropServices~RuntimeInformation~FrameworkDescription
call frameworks
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
say "Windows Forms: not available"
say "  " condition('O')~message
say "The bridge needs Microsoft.WindowsDesktop.App (above) for Windows Forms:"
say "install the .NET Desktop Runtime, x64, from https://dotnet.microsoft.com/download"
exit 1

/* The .NET frameworks installed where the running one is (the bridge takes
   the newest major version there) */
frameworks: procedure
  signal on syntax name noList
  io = .net~System~IO
  dir = .net~System~Runtime~InteropServices~RuntimeEnvironment~GetRuntimeDirectory
  shared = io~Path~GetFullPath(io~Path~Combine(dir, "..", ".."))
  say ".NET frameworks in" shared":"
  do fw over io~Directory~GetDirectories(shared)
    versions = ""
    do v over io~Directory~GetDirectories(fw)
      versions = versions io~Path~GetFileName(v)
    end
    say "   " io~Path~GetFileName(fw)":" versions~strip
  end
  return
noList:
  return

::requires "net.cls"
