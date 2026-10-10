/* ole-events-test.rex: checks .OLEObject's event methods (Windows), with
   ADODB.Recordset: the arguments in their order, and a value returned for
   an out parameter given back to the event's source. Exit status 0 if all
   pass. Before ole-events.diff: the arguments come reversed, and returning
   a value crashes the interpreter (0xC0000005).

   WillMove(adReason, adStatus*, pRecordset): returning 4 (adStatusCancel)
   cancels the move. MoveComplete(adReason, pError, adStatus*, pRecordset):
   returning 5 (adStatusUnwantedEvent) stops further MoveComplete events;
   with four parameters the out parameter's position matters.             */
.local~fails = 0; .local~count = 0
rs = .WatchedRecordset~new("ADODB.Recordset", "WITHEVENTS")
rs~mode = ""; rs~got = ""; rs~completes = 0
rs~CursorLocation = 3                                     -- adUseClient
rs~Fields~Append("name", 200, 20)                         -- adVarChar
rs~Open
do name over .array~of("one", "two", "three")
  rs~AddNew
  rs~Fields~Item("name")~Value = name
  rs~Update
end

rs~mode = "order"
rs~MoveFirst
call ok "WillMove's arguments in order", rs~got, "12 1 OLEObject"

rs~mode = "ok"                                            -- returns 1, adStatusOK
rs~MoveNext
call ok "returning adStatusOK: no crash, moved", rs~Fields~Item("name")~Value, "two"

rs~mode = "cancel"                                        -- returns 4, adStatusCancel
signal on syntax name cancelled
rs~MoveNext
call ok "returning adStatusCancel: cancelled", "moved to" rs~Fields~Item("name")~Value, "an error"
cancelled:
signal off syntax
call ok "returning adStatusCancel: MoveNext fails", condition("C"), "SYNTAX"
call ok "returning adStatusCancel: not moved", rs~Fields~Item("name")~Value, "two"

rs~mode = "unwanted"                                      -- MoveComplete returns 5 once
before = rs~completes
rs~MoveFirst
rs~mode = ""
rs~MoveNext
rs~MoveLast
call ok "MoveComplete's out parameter (3rd of 4): no more MoveComplete", rs~completes - before, 1

if .fails = 0 then say "OLE events: all" .count "tests passed"
else say "OLE events:" .fails "of" .count "tests FAILED"
exit .fails > 0

::class WatchedRecordset subclass OLEObject
::attribute mode
::attribute got
::attribute completes
::method willMove                                         -- WillMove(adReason, adStatus*, pRecordset)
  select
    when self~mode == "order" then do
      w = ""
      do i = 1 to arg()
        if arg(i)~isA(.OLEObject) then w = w "OLEObject"; else w = w arg(i)
      end
      self~got = w~strip
    end
    when self~mode == "ok" then return 1
    when self~mode == "cancel" then return 4
    otherwise nop
  end
::method moveComplete                                     -- MoveComplete(adReason, pError, adStatus*, pRecordset)
  self~completes += 1
  if self~mode == "unwanted" then return 5

::routine ok
  use arg name, got, want
  .local~count += 1
  if got == want then do; say "ok  " name; return; end
  .local~fails += 1
  say "FAIL" name": got ["got"], want ["want"]"
