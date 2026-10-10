/* writer-ole.rex: LibreOffice Writer in a nutshell, with ooRexx's .OLEObject.
   Its twin, writer-net.rex, does the same through the .NET bridge. On
   Windows, LibreOffice's automation bridge (com.sun.star.ServiceManager)
   gives its UNO API to any COM client. A document with a heading, a
   paragraph and a table; saved as writer-sample.odt in the temporary
   folder. "auto": LibreOffice stays hidden.                               */
auto = arg(1)~strip~caselessEquals("auto")
sm = .OLEObject~new("com.sun.star.ServiceManager")
desktop = sm~createInstance("com.sun.star.frame.Desktop")
doc = desktop~loadComponentFromURL("private:factory/swriter", "_blank", 0, -
                                   .array~of(property(sm, "Hidden", auto)))
text = doc~getText
cursor = text~createTextCursor

cursor~setPropertyValue("ParaStyleName", "Heading 1")       -- style names: the API's, in English
text~insertString(cursor, "ooRexx and LibreOffice", .false)
text~insertControlCharacter(cursor, 0, .false)              -- PARAGRAPH_BREAK
cursor~setPropertyValue("ParaStyleName", "Standard")
text~insertString(cursor, "This document was written by a Rexx program on" date() "at" time()".", .false)
text~insertControlCharacter(cursor, 0, .false)

data = .array~of(.array~of("Language", "Year", "Objects"),  -
                 .array~of("Rexx",     "1979", "no"),       -
                 .array~of("ooRexx",   "2004", "yes"))
table = doc~createInstance("com.sun.star.text.TextTable")
table~initialize(data~items, 3)
text~insertTextContent(cursor, table, .false)
do r = 1 to data~items
  do c = 1 to 3
    table~getCellByName(substr("ABC", c, 1) || r)~setString(data[r][c])
  end
end
table~getCellRangeByName("A1:C1")~setPropertyValue("CharWeight", 150)   -- com.sun.star.awt.FontWeight.BOLD

say "Characters:" text~getString~length
file = value("TEMP", , "ENVIRONMENT") || "\writer-sample.odt"
doc~storeAsURL("file:///" || changestr("\", file, "/"), .array~of(property(sm, "Overwrite", .true)))
say "Saved" file
doc~close(.true)
if \desktop~getComponents~createEnumeration~hasMoreElements then desktop~terminate   -- not if you have documents open

::routine property                                           -- a com.sun.star.beans.PropertyValue
  use arg sm, name, value
  p = sm~Bridge_GetStruct("com.sun.star.beans.PropertyValue")
  p~Name = name
  p~Value = value
  return p
