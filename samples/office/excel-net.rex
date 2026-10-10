/* excel-net.rex: Excel in a nutshell, through the .NET bridge.
   The same program as excel-ole.rex: .net~createObject gives a COM object
   reached through IDispatch, like .OLEObject~new, and the rest does not
   change, except what .NET adds: here the file name comes from .NET's
   Path, and the objects are released at the end. "auto": Excel stays
   hidden.                                                                  */
excel = .net~createObject("Excel.Application")
excel~Visible = \arg(1)~strip~caselessEquals("auto")
book = excel~Workbooks~Add
sheet = book~Worksheets~Item(1)                             -- (VBA: Worksheets(1))
sheet~Name = "Fruit"

data = .array~of(.array~of("Fruit", "Kilos", "Price"),  -
                 .array~of("Apples",   12,     1.20),  -
                 .array~of("Pears",     7,     1.85),  -
                 .array~of("Figs",      3,     4.10))
grid = .array~new(data~items, 3)                            -- a 2-D Array: one call fills the range
do r = 1 to data~items
  do c = 1 to 3
    grid[r, c] = data[r][c]
  end
end
sheet~Range("A1:C4")~Value = grid
say "B3:" sheet~Cells~Item(3, 2)~Value                       -- (VBA: Cells(3, 2))
sheet~Range("D1")~Value = "Total"
sheet~Range("D2:D4")~Formula = "=B2*C2"                     -- relative: D3 is =B3*C3...
sheet~Range("C6")~Value = "Sum"
sheet~Range("D6")~Formula = "=SUM(D2:D4)"                   -- English names on any Windows

sheet~Range("A1:D1")~Font~Bold = .true
sheet~Range("C2:D6")~NumberFormat = "0.00"
sheet~Range("A:D")~Columns~AutoFit
say "Total:" sheet~Range("D6")~Value                        -- computed by Excel

file = .net~System~IO~Path~Combine(.net~System~IO~Path~GetTempPath, "excel-sample-net.xlsx")
excel~DisplayAlerts = .false                                 -- overwrite without asking
book~SaveAs(file)
say "Saved" file
book~Close
excel~Quit
.net~releaseObject(excel)                                    -- Excel's process can end now (not at .NET's next collection)

::requires "net.cls"
