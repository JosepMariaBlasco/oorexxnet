/* excel-events-ole.rex: Excel's events, with ooRexx's .OLEObject.
   Its twin, excel-events-net.rex, does the same through the .NET bridge.
   An .OLEObject created "WITHEVENTS" calls its own methods named after
   Excel's Application events: SheetChange (cells changed) and
   WorkbookBeforeClose, whose Cancel parameter, passed by reference, takes
   the method's return value: the first attempt to close the workbook is
   refused. With "auto", Excel stays hidden and the program ends by itself;
   without it, Excel stays open for you: change some cells, see the events,
   close the workbook to end.                                               */
auto = arg(1)~strip~caselessEquals("auto")
excel = .WatchedExcel~new("Excel.Application", "WITHEVENTS")
excel~Visible = \auto
excel~refuse = .false; excel~closed = .false; excel~changes = 0

book = excel~Workbooks~Add
sheet = book~Worksheets~Item(1)
sheet~Range("A1")~Value = "Hello"                            -- each change is an event,
sheet~Range("A2:B3")~Value = 42                              -- handled during the call

excel~refuse = .true
book~Close(.false)                                           -- to be refused by the handler (Cancel)
open = excel~Workbooks~Count
say "Workbooks open after the refused Close:" open
if open = 0 then                                             -- (on ooRexx 5.x, see the README)
  say "  .OLEObject did not give Cancel back to Excel: the workbook closed"
else if \auto then do
  say "Change some cells in Excel; close the workbook to end."
  do until excel~closed
    call SysSleep 1                    -- Excel's events come while this thread sleeps
  end
end
else book~Close(.false)
say "Workbooks open now:" excel~Workbooks~Count
ok = excel~changes >= 2 & excel~closed
excel~Quit
exit \ok                                                     -- (for check-samples.rex)

::class WatchedExcel subclass OLEObject
::attribute refuse
::attribute closed
::attribute changes
::method sheetChange                                         -- SheetChange(Sh, Target)
  use arg sheet, range
  self~changes += 1
  say "Changed:" sheet~Name"!"range~Address(.false, .false)
::method workbookBeforeClose                                 -- WorkbookBeforeClose(Wb, Cancel)
  use arg book, cancel
  if self~refuse then do
    say "Not closing" book~Name "yet"
    self~refuse = .false
    return .true                                             -- goes to Cancel, the out parameter
  end
  say "Closing" book~Name
  self~closed = .true
  return .false
