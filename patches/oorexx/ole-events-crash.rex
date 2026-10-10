/* ole-events-crash.rex MODE: an .OLEObject event method and the interpreter
   crashing (access violation), with ADODB.Recordset (every Windows has it;
   its events come during the call that causes them). Adds two records with
   a WillMove method defined, MODE saying what the method does:
     none   returns nothing
     one    returns 1 (adStatusOK, into the [in, out] adStatus)
     args   uses its arguments, then returns nothing
   Prints "done" if the program gets to its end. Run each mode in its own
   process (a crash ends it):
     for %m in (none one args) do @rexx ole-events-crash.rex %m & echo %m: exit code %errorlevel%  */
parse arg mode .
rs = .WatchedRecordset~new("ADODB.Recordset", "WITHEVENTS")
rs~mode = mode; rs~calls = 0
rs~CursorLocation = 3                                     -- adUseClient
rs~Fields~Append("name", 200, 20)                         -- adVarChar
rs~Open
do name over .array~of("one", "two")
  rs~AddNew
  rs~Fields~Item("name")~Value = name
  rs~Update
end
rs~MoveFirst
say mode": done," rs~calls "WillMove calls"
exit 0

::class WatchedRecordset subclass OLEObject
::attribute mode
::attribute calls
::method willMove                                         -- WillMove(adReason, adStatus*, pRecordset)
  self~calls += 1
  select
    when self~mode == "one" then return 1
    when self~mode == "args" then do
      do i = 1 to arg()
        a = arg(i)
        if a~isA(.OLEObject) then x = a~RecordCount
      end
    end
    otherwise nop
  end
