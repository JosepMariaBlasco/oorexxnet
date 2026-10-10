/* ole-events-repro.rex: .OLEObject event methods get their arguments in
   reverse order, and an out parameter is not given back (Windows; uses
   ADODB.Recordset, which every Windows has and which raises its events
   synchronously, during the call that causes them).

   ADO's RecordsetEvents declares
       WillMove([in] EventReasonEnum adReason,
                [in, out] EventStatusEnum* adStatus,
                [in] _Recordset* pRecordset)
   so the method should get (adReason, adStatus, pRecordset): for MoveFirst,
   adReason is 12 (adRsnMoveFirst), adStatus 1 (adStatusOK). Returning 4
   (adStatusCancel) should cancel the move: MoveNext then fails with an
   "operation cancelled" error and the record does not change.            */
parse version v; say v
rs = .WatchedRecordset~new("ADODB.Recordset", "WITHEVENTS")
rs~watch = .false; rs~cancel = .false
say "0. Created; adding two records"
rs~CursorLocation = 3                                     -- adUseClient
rs~Fields~Append("name", 200, 20)                         -- adVarChar
rs~Open
do name over .array~of("one", "two")
  rs~AddNew
  rs~Fields~Item("name")~Value = name
  rs~Update
end

say "1. The order of the arguments (MoveFirst)"
rs~watch = .true
rs~MoveFirst
rs~watch = .false

say "2. An out parameter (adStatus = 4 cancels MoveNext)"
rs~cancel = .true
signal on syntax
rs~MoveNext
say "   not cancelled: the record is now" rs~Fields~Item("name")~Value "(expected: still one)"
exit 1
syntax:
  say "   cancelled as expected:" condition("O")~message
  exit 0

::class WatchedRecordset subclass OLEObject
::attribute watch
::attribute cancel
::method willMove
  if self~watch then do
    say "   WillMove got" arg() "arguments (expected: 12, 1, an OLEObject):"
    do i = 1 to arg()
      a = arg(i)
      if a~isA(.OLEObject) then say "     arg" i": an OLEObject"
      else say "     arg" i":" a
    end
  end
  if self~cancel then return 4                            -- adStatusCancel, into adStatus
  return 1                                                -- adStatusOK
