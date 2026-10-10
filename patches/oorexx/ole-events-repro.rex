/* ole-events-repro.rex: .OLEObject event methods get their arguments in
   reverse order (Windows; uses ADODB.Recordset, which every Windows has and
   which raises its events synchronously, during the call that causes them).

   ADO's RecordsetEvents declares
       WillMove([in] EventReasonEnum adReason,
                [in, out] EventStatusEnum* adStatus,
                [in] _Recordset* pRecordset)
   so for MoveFirst the method should get 12 (adRsnMoveFirst), 1
   (adStatusOK), the Recordset. (The method returns nothing: returning a
   value for adStatus crashes the interpreter, see ole-events-crash.rex.) */
rs = .WatchedRecordset~new("ADODB.Recordset", "WITHEVENTS")
rs~watch = .false
rs~CursorLocation = 3                                     -- adUseClient
rs~Fields~Append("name", 200, 20)                         -- adVarChar
rs~Open
do name over .array~of("one", "two")
  rs~AddNew
  rs~Fields~Item("name")~Value = name
  rs~Update
end
rs~watch = .true
rs~MoveFirst

::class WatchedRecordset subclass OLEObject
::attribute watch
::method willMove
  if \self~watch then return
  say "WillMove got" arg() "arguments (expected: 12, 1, an OLEObject):"
  do i = 1 to arg()
    a = arg(i)
    if a~isA(.OLEObject) then say "  arg" i": an OLEObject"
    else say "  arg" i":" a
  end
