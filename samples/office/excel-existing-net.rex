/* excel-existing-net.rex: Excel objects that already exist, through the
   .NET bridge. The same program as excel-existing-ole.rex: .net~getObject
   is .OLEObject~GetObject (a workbook file, opened by Excel: VBA's
   GetObject(path)), and .net~getActiveObject is VBA's GetObject(, class),
   the Excel the user opened. "auto": no running Excel is not an error.     */
auto = arg(1)~strip~caselessEquals("auto")

-- a workbook file, made here first
file = .net~System~IO~Path~Combine(.net~System~IO~Path~GetTempPath, "rexxnet-existing.xlsx")
excel = .net~createObject("Excel.Application")
excel~DisplayAlerts = .false
book = excel~Workbooks~Add
book~Worksheets~Item(1)~Range("A1")~Value = "made by Rexx"
book~SaveAs(file)
book~Close
excel~Quit
.net~releaseObject(excel)

-- the object the file names: its workbook, opened by Excel
book = .net~getObject(file)
say "getObject:" book~Name "A1 =" book~Worksheets~Item(1)~Range("A1")~Value
app = book~Application                                     -- an Excel started for the file
book~Close(.false)                                          -- (not one the user opened) ends now:
say "  (that Excel: window" app~Hwnd"," word("hidden visible", app~Visible + 1)"," -
    word("program's user's", app~UserControl + 1)", with" app~Workbooks~Count "other workbook(s))"
fileExcel = app~Hwnd
quit = app~Workbooks~Count = 0 & \app~UserControl
if quit then app~Quit                                       -- else getActiveObject could find it
.net~releaseObject(book)
.net~releaseObject(app)                                     -- (Excel ends once nothing refers to it)
.net~System~IO~File~Delete(file)

-- the Excel the user opened, if one runs (Office registers itself in the
-- Running Object Table when started by hand, not when started by a program)
signal on syntax name noExcel
do tries = 1 to 20                                          -- the Excel that quit leaves the
  running = .net~getActiveObject("Excel.Application")      -- table only as its process ends
  if \quit | running~Hwnd \== fileExcel | tries = 20 then leave
  .net~releaseObject(running)
  call SysSleep 0.5
end
signal off syntax
say "getActiveObject: Excel" running~Version "with" running~Workbooks~Count "workbook(s)" -
    "(window" running~Hwnd"," word("hidden visible", running~Visible + 1)"," word("program's user's", running~UserControl + 1)")"
do b over running~Workbooks
  say "  " b~Name
end
exit 0

noExcel:
  say "getActiveObject:" condition("O")~message
  exit (\auto)

::requires "net.cls"
