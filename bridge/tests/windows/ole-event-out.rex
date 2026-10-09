/* ole-event-out.rex: how ooRexx's .OLEObject passes an event's arguments
   and takes an out parameter back, with ADODB.Recordset (every Windows has
   it; its events come during the call). WillMove(adReason, adStatus*,
   pRecordset): adStatus is [in, out]; the method's return value should go
   there, and adStatusCancel (4) should cancel the move. A diagnostic of
   .OLEObject (not of the bridge: tests/com.rex does the same through it). */
rs = .WatchedRecordset~new("ADODB.Recordset", "WITHEVENTS")
rs~CursorLocation = 3                                     -- adUseClient
rs~Fields~Append("name", 200, 20)                         -- adVarChar
rs~Open
do name over .array~of("one", "two")
  rs~AddNew
  rs~Fields~Item("name")~Value = name
  rs~Update
end
rs~cancel = .false
rs~MoveFirst
rs~cancel = .true
signal on syntax
rs~MoveNext
say "MoveNext was not cancelled: now at" rs~Fields~Item("name")~Value
exit 1
syntax:
  say "MoveNext cancelled (" || condition("O")~code || "): still at" rs~Fields~Item("name")~Value
  exit 0

::class WatchedRecordset subclass OLEObject
::attribute cancel
::method willMove
  say "WillMove got" arg() "arguments:"
  do i = 1 to arg()
    a = arg(i)
    if a~isA(.OLEObject) then say "  arg" i": an OLEObject (RecordCount" a~RecordCount")"
    else say "  arg" i":" a
  end
  if self~cancel then do
    say "  returning 4 (adStatusCancel)"
    return 4
  end
  return 1                                                -- adStatusOK
