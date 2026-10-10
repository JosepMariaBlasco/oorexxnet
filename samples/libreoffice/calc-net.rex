/* calc-net.rex: LibreOffice Calc in a nutshell, through the .NET bridge.
   The same program as calc-ole.rex, with .net~createObject in place of
   .OLEObject~new; the file's URL from .NET's Uri, the objects released at
   the end. Saved as calc-sample-net.ods in the temporary folder.
   "auto": LibreOffice stays hidden.                                        */
auto = arg(1)~strip~caselessEquals("auto")
sm = .net~createObject("com.sun.star.ServiceManager")
desktop = sm~createInstance("com.sun.star.frame.Desktop")
doc = desktop~loadComponentFromURL("private:factory/scalc", "_blank", 0, -
                                   .array~of(property(sm, "Hidden", auto)))
sheet = doc~getSheets~getByIndex(0)                         -- from 0, as UNO counts
sheet~setName("Fruit")

data = .array~of(.array~of("Fruit", "Kilos", "Price"),  -
                 .array~of("Apples",   12,     1.20),  -
                 .array~of("Pears",     7,     1.85),  -
                 .array~of("Figs",      3,     4.10))
sheet~getCellRangeByName("A1:C4")~setDataArray(data)       -- rows of values: one call
b3 = sheet~getCellByPosition(1, 2)~getValue                -- (column, row), from 0
say "B3:" b3                                                -- a number, not the text "7"
sheet~getCellRangeByName("D1")~setString("Total")
do r = 2 to 4
  sheet~getCellRangeByName("D"r)~setFormula("=B"r"*C"r)
end
sheet~getCellRangeByName("C6")~setString("Sum")
sheet~getCellRangeByName("D6")~setFormula("=SUM(D2:D4)")  -- the API's formulas: English names

sheet~getCellRangeByName("A1:D1")~setPropertyValue("CharWeight", 150)   -- com.sun.star.awt.FontWeight.BOLD
do c = 0 to 3
  sheet~getColumns~getByIndex(c)~setPropertyValue("OptimalWidth", .true)
end
say "Total:" sheet~getCellRangeByName("D6")~getValue        -- computed by Calc

file = .net~System~IO~Path~Combine(.net~System~IO~Path~GetTempPath, "calc-sample-net.ods")
doc~storeAsURL(.net~System~Uri~new(file)~AbsoluteUri, .array~of(property(sm, "Overwrite", .true)))
say "Saved" file
doc~close(.true)
if \desktop~getComponents~createEnumeration~hasMoreElements then desktop~terminate   -- not if you have documents open
.net~releaseObject(sm)
exit b3 \= 7                                                -- (for check-samples.rex)

::routine property                                           -- a com.sun.star.beans.PropertyValue
  use arg sm, name, value
  p = sm~Bridge_GetStruct("com.sun.star.beans.PropertyValue")
  p~Name = name
  p~Value = value
  return p

::requires "net.cls"
