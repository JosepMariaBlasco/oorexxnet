/* excel-ole.rex: Excel in a nutshell, with ooRexx's .OLEObject (COM).
   Its twin, excel-net.rex, does the same through the .NET bridge.
   A workbook with a small table, a formula, some formatting; saved as
   excel-sample.xlsx in the temporary folder. "auto": Excel stays hidden.  */
excel = .OLEObject~new("Excel.Application")
excel~Visible = \arg(1)~strip~caselessEquals("auto")
book = excel~Workbooks~Add
sheet = book~Worksheets~Item(1)                             -- (VBA: Worksheets(1))
sheet~Name = "Fruit"

data = .array~of(.array~of("Fruit", "Kilos", "Price"),  -
                 .array~of("Apples",   12,     1.20),  -
                 .array~of("Pears",     7,     1.85),  -
                 .array~of("Figs",      3,     4.10))
do r = 1 to data~items
  do c = 1 to 3
    sheet~Cells~Item(r, c)~Value = data[r][c]                -- (VBA: Cells(r, c))
  end
end
sheet~Range("D1")~Value = "Total"
sheet~Range("D2:D4")~Formula = "=B2*C2"                     -- relative: D3 is =B3*C3...
sheet~Range("C6")~Value = "Sum"
sheet~Range("D6")~Formula = "=SUM(D2:D4)"

sheet~Range("A1:D1")~Font~Bold = .true
sheet~Range("C2:D6")~NumberFormat = "0.00"
sheet~Range("A:D")~Columns~AutoFit
say "Total:" sheet~Range("D6")~Value                        -- computed by Excel

file = value("TEMP", , "ENVIRONMENT") || "\excel-sample.xlsx"
excel~DisplayAlerts = .false                                 -- overwrite without asking
book~SaveAs(file)
say "Saved" file
book~Close
excel~Quit
