/* word-net.rex: Word in a nutshell, through the .NET bridge.
   The same program as word-ole.rex, with .net~createObject in place of
   .OLEObject~new; the file name from .NET, the objects released at the end.
   A document with a heading, a paragraph and a table; saved as
   word-sample.docx in the temporary folder. "auto": Word stays hidden.    */
word = .net~createObject("Word.Application")
word~Visible = \arg(1)~strip~caselessEquals("auto")
doc = word~Documents~Add
sel = word~Selection

sel~Style = -2                                              -- wdStyleHeading1 (in any language)
sel~TypeText("ooRexx and Word")
sel~TypeParagraph
sel~Style = -1                                              -- wdStyleNormal
sel~TypeText("This document was written by a Rexx program on" date() "at" time()".")
sel~TypeParagraph

data = .array~of(.array~of("Language", "Year", "Objects"),  -
                 .array~of("Rexx",     "1979", "no"),       -
                 .array~of("ooRexx",   "2004", "yes"))
table = doc~Tables~Add(sel~Range, data~items, 3)
do r = 1 to data~items
  do c = 1 to 3
    table~Cell(r, c)~Range~Text = data[r][c]
  end
end
table~Rows~Item(1)~Range~Font~Bold = .true
table~Borders~Enable = .true

say "Paragraphs:" doc~Paragraphs~Count", words:" doc~Words~Count
file = .net~System~IO~Path~Combine(.net~System~IO~Path~GetTempPath, "word-sample-net.docx")
doc~SaveAs2(file, 16)                                       -- wdFormatDocumentDefault: .docx
say "Saved" file
doc~Close
word~Quit
.net~releaseObject(word)

::requires "net.cls"
