/* excel-existing-ole.rex: Excel objects that already exist, through
   .OLEObject. The same program as excel-existing-net.rex: .OLEObject~
   GetObject gives the workbook a file names (opened by Excel: VBA's
   GetObject(path)); for the Excel the user opened, .OLEObject's NEW takes
   an undocumented third argument, .true, "try GetActiveObject first" (and
   creates a new Excel if none runs: it cannot tell). "auto": as the other. */
auto = arg(1)~strip~caselessEquals("auto")

-- a workbook file, made here first
file = value("TEMP", , "ENVIRONMENT") || "\rexxnet-existing.xlsx"
excel = .OLEObject~new("Excel.Application")
excel~DisplayAlerts = .false
book = excel~Workbooks~Add
book~Worksheets~Item(1)~Range("A1")~Value = "made by Rexx"
book~SaveAs(file)
book~Close
excel~Quit
drop excel book

-- the object the file names: its workbook, opened by Excel
book = .OLEObject~GetObject(file)
say "getObject:" book~Name "A1 =" book~Worksheets~Item(1)~Range("A1")~Value
book~Close(.false)
drop book
call SysFileDelete file

-- the Excel the user opened, if one runs (otherwise a new one: quit it)
running = .OLEObject~new("Excel.Application", , .true)
say "getActiveObject: Excel" running~Version "with" running~Workbooks~Count "workbook(s)"
do b over running~Workbooks
  say "  " b~Name
end
if running~Workbooks~Count = 0 & \running~Visible then running~Quit
exit 0
