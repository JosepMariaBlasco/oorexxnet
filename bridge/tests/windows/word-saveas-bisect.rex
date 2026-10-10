/* word-saveas-bisect.rex: samples/office/word-net.rex step by step, with
   Document~SaveAs2(file, 16) through the bridge after each step, to find
   the step after which it fails with DISP_E_TYPEMISMATCH (C# making the same
   call succeeds: word-saveas-probe.cs). Word stays hidden; the files go to
   the temporary folder and are deleted; Word quits at the end, whatever
   happens. Windows with Word; the bridge's folder on the PATH (or current).
   REXXNET_APARTMENT=MTA runs it in the MTA instead of an STA.             */
apartment = value("REXXNET_APARTMENT", , "ENVIRONMENT")~strip~upper
if apartment \== "MTA" then apartment = "STA"
say "apartment:" apartment
word = .net~createObject("Word.Application")
word~Visible = .false
signal on syntax name finish
.local~tmp = value("TEMP", , "ENVIRONMENT")
.local~n = 0

doc = word~Documents~Add
call try doc, "an empty document"
call try doc, "an empty document, the file name from .NET", -
     .net~System~IO~Path~Combine(.net~System~IO~Path~GetTempPath, "word-bisect-net.docx")
call try doc, "an empty document, the format as .net~box('int', 16)", , .net~box("int", 16)

sel = word~Selection
sel~Style = -2
call try doc, "after sel~Style = -2"
sel~TypeText("ooRexx and Word")
sel~TypeParagraph
call try doc, "after the heading"
sel~Style = -1
sel~TypeText("This document was written by a Rexx program on" date() "at" time()".")
sel~TypeParagraph
call try doc, "after the paragraph"

data = .array~of(.array~of("Language", "Year", "Objects"),  -
                 .array~of("Rexx",     "1979", "no"),       -
                 .array~of("ooRexx",   "2004", "yes"))
table = doc~Tables~Add(sel~Range, data~items, 3)
call try doc, "after Tables~Add"
do r = 1 to data~items
  do c = 1 to 3
    table~Cell(r, c)~Range~Text = data[r][c]
  end
end
call try doc, "after filling the table"
table~Rows~Item(1)~Range~Font~Bold = .true
table~Borders~Enable = .true
call try doc, "after Bold and Borders"
say "Paragraphs:" doc~Paragraphs~Count", words:" doc~Words~Count
call try doc, "after Paragraphs~Count and Words~Count"

finish:
if condition() == "SYNTAX" then say "stopped:" condition("O")~message
doc~Close(0)                                                -- wdDoNotSaveChanges
word~Quit
.net~releaseObject(word)
exit

/* SaveAs2(file, format) to a new file in the temporary folder; says ok or
   the error, and deletes the file.                                         */
::routine try
  use arg doc, what, file = (.tmp"\word-bisect-" || .n + 1 || ".docx"), format = 16
  .local~n = .n + 1
  signal on syntax
  doc~SaveAs2(file, format)
  ok = .stream~new(file)~query("exists") \== ""
  if ok then say right(.n, 2) "ok  " what
  else say right(.n, 2) "ok  " what "(but no file)"
  call SysFileDelete file
  return
syntax:
  say right(.n, 2) "FAIL" what":" condition("O")~message

::requires "net.cls"
