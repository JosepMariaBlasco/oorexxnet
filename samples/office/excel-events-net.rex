/* excel-events-net.rex: Excel's events, through the .NET bridge.
   Its twin, excel-events-ole.rex, does the same with .OLEObject. A Rexx
   object handles two events of Excel's Application: SheetChange (cells
   changed) and WorkbookBeforeClose, whose Cancel parameter, passed by
   reference, refuses the first attempt to close the workbook. With "auto",
   Excel stays hidden and the program ends by itself; without it, Excel stays
   open for you: change some cells, see the events, close the workbook to end. */
auto = arg(1)~strip~caselessEquals("auto")
excel = .net~createObject("Excel.Application")
excel~Visible = \auto
watcher = .Watcher~new
excel~SheetChange += .net~handler(watcher, "SHEETCHANGE")             -- as .NET events
excel~WorkbookBeforeClose += .net~handler(watcher, "WORKBOOKBEFORECLOSE")

book = excel~Workbooks~Add
sheet = book~Worksheets~Item(1)
sheet~Range("A1")~Value = "Hello"                            -- each change is an event,
sheet~Range("A2:B3")~Value = 42                              -- handled during the call

watcher~refuse = .true
book~Close(.false)                                           -- refused by the handler (Cancel)
open = excel~Workbooks~Count
say "Workbooks open after the refused Close:" open
if \auto then do
  say "Change some cells in Excel; close the workbook to end."
  do until watcher~closed
    .net~nextEvent(1)                  -- Excel's events come while this thread waits in .NET
  end
end
else book~Close(.false)
say "Workbooks open now:" excel~Workbooks~Count
excel~Quit
.net~releaseObject(excel)                                    -- disconnects the handlers too
exit \(watcher~changes >= 2 & open = 1 & watcher~closed)     -- (for check-samples.rex)

::requires "net.cls"

::class Watcher
::attribute refuse
::attribute closed
::attribute changes
::method init
  self~refuse = .false; self~closed = .false; self~changes = 0
::method sheetChange                                         -- SheetChange(Sh, Target)
  use arg sheet, range
  self~changes += 1
  say "Changed:" sheet~Name"!"range~Address(.false, .false)
::method workbookBeforeClose                                 -- WorkbookBeforeClose(Wb, Cancel)
  use arg book, cancel                                       -- cancel: by reference, a Rexx.Net.ComRef
  if self~refuse then do
    say "Not closing" book~Name "yet"
    cancel~Value = .true                                     -- Excel sees it when the method returns
    self~refuse = .false
  end
  else do
    say "Closing" book~Name
    self~closed = .true
  end
