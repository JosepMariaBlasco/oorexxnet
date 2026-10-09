/* ooRexx/.NET bridge: COM objects through IDispatch (managed/Com.cs):
   tests, on Windows (elsewhere they are skipped). Run by tests/run.ps1, with
   COM servers every Windows has: Scripting.Dictionary,
   Scripting.FileSystemObject, WScript.Shell; and COM events
   (managed/ComEvents.cs) with ADODB.Recordset, whose events come
   synchronously, during the call that causes them. */
.local~fails = 0; .local~count = 0
if \.rexxInfo~platform~upper~abbrev("WIN") then do
  say "COM objects: skipped (Windows only)"
  exit 0
end

-- creation, methods, properties, results
d = .net~createObject("Scripting.Dictionary")
call ok "createObject: a .NetObject",      d~isA(.NetObject), 1
d~Add("a", 1)
d~Add("b", "two")
call ok "a method; a property read",       d~Count, 2
call ok "a method with an argument",       d~Item("b"), "two"
call ok "names are caseless",              d~ITEM("b") d~item("b"), "two two"
call ok "a Boolean result",                d~Exists("a") d~Exists("zz"), "1 0"
call ok "Rexx numbers go as numbers",      d~Item("a") + 1, 2
d~Add("z", .net~box("string", "007"))
call ok "... and a boxed string as a string", d~Item("z"), "007"
d~Add("n", "007")
call ok "... unboxed, 007 is a number",    d~Item("n"), 7
keys = d~Keys
call ok "an array result: a Rexx Array",   keys~items keys[1], "4 a"

-- the default member: o[i], o[i] = v
call ok "o[key]: the default member",      d["b"], "two"
d["c"] = 3
call ok "o[key] = v",                      d~Count d["c"], "5 3"
e = .net~createObject("Scripting.Dictionary")              -- (CompareMode: only while empty)
e~CompareMode = 1
call ok "a property set",                  e~CompareMode, 1

-- another server; COM objects returned by COM objects; enumeration
fso = .net~createObject("Scripting.FileSystemObject")
temp = fso~GetSpecialFolder(2)                            -- TemporaryFolder: a COM object
call ok "a COM object from a COM object",  temp~isA(.NetObject) fso~FolderExists(temp~Path), "1 1"
file = temp~Path || "\" || fso~GetTempName
ts = fso~OpenTextFile(file, , .true)                       -- iomode omitted (optional), create
ts~Close
call ok "an omitted argument (optional)",  fso~FileExists(file), 1
ts = fso~OpenTextFile(file, 8)                            -- ForAppending
ts~WriteLine("hello")
ts~Close
ts = fso~OpenTextFile(file)
text = ts~ReadAll
ts~Close
call ok "a file written through COM",      text~strip("T", "0a"x)~strip("T", "0d"x), "hello"
fso~DeleteFile(file)
call ok "... and deleted",                 fso~FileExists(file), 0
n = 0
do drive over fso~Drives
  n += 1
end
call ok "DO OVER a COM collection",        n > 0 & n = fso~Drives~Count, 1

-- errors
signal on syntax name unknown
x = fso~NoSuchMember
call ok "an unknown member", "no error", "97.1"
unknown:
call ok "an unknown member: 97.1",         condition("O")~code, "97.1"
signal on syntax name failing
x = fso~GetFile("Z:\no\such\file.txt")
call ok "a failing call", "no error", "98.900"
failing:
call ok "a failing call: 98.900",          condition("O")~code, "98.900"
signal off syntax

sh = .net~createObject("WScript.Shell")
call ok "WScript.Shell",                   sh~ExpandEnvironmentStrings("%SystemRoot%")~upper~pos("WINDOWS") > 0, 1
.net~releaseObject(sh)
signal on syntax name released
x = sh~ExpandEnvironmentStrings("%SystemRoot%")
call ok "a released object", "usable", "98.900"
released:
call ok "releaseObject: unusable after",   condition("O")~code, "98.900"
signal on syntax name noClass
x = .net~createObject("No.Such.ProgID")
noClass:
call ok "an unknown ProgID: 98.900",       condition("O")~code, "98.900"

-- events: ADODB.Recordset (a disconnected one, in memory)
rs = .net~createObject("ADODB.Recordset")
rs~CursorLocation = 3                                     -- adUseClient
rs~Fields~Append("name", 200, 20)                         -- adVarChar
rs~Open
do name over .array~of("one", "two", "three")
  rs~AddNew
  rs~Fields~Item("name")~Value = name
  rs~Update
end
names = .net~events(rs)
call ok ".net~events(o): a COM object's",  names~hasItem("WillMove") names~hasItem("MoveComplete"), "1 1"
ev = .AdoEvents~new
h = .net~handler(ev, "WILLMOVE")
call ok "o~Event: a NetEvent",             rs~WillMove~makeString~abbrev("a NetEvent (WillMove of"), 1
rs~WillMove += h
rs~MoveFirst
call ok "o~Event += h: called during the call", ev~moves, 1
call ok "... with the event's parameters", ev~reason ev~rs~RecordCount, "12 3"   -- adRsnMoveFirst
call ok "a parameter by reference: a ComRef", .net~typeOf(ev~status) datatype(ev~status~Value, "W"), "Rexx.Net.ComRef 1"
rs~MoveNext
call ok "... and again",                   ev~moves ev~reason rs~Fields~Item("name")~Value, "2 13 two"
ev~cancel = .true                                         -- the handler sets adStatus to adStatusCancel
signal on syntax name cancelled
rs~MoveNext
call ok "ref~Value = x: the event's source sees it", "not cancelled", "98.900"
cancelled:
signal off syntax
call ok "ref~Value = x: the move is cancelled", condition("O")~code ev~moves rs~Fields~Item("name")~Value, "98.900 3 two"
ev~cancel = .false
rs~WillMove -= h
rs~MoveLast
call ok "o~Event -= h: not called",        ev~moves rs~Fields~Item("name")~Value, "3 three"
h2 = .net~handler(ev, "MOVECOMPLETE")
rs~add_MoveComplete(h2)
rs~MoveFirst
call ok "o~add_Event(h)",                  ev~completes (ev~error == .nil), "1 1"
rs~remove_MoveComplete(h2)
.net~addHandler(rs, "movecomplete", h2)                   -- caseless
rs~MoveNext
call ok ".net~addHandler(o, name, h)",     ev~completes, 2
.net~removeHandler(rs, "MoveComplete", h2)
rs~MoveNext
call ok ".net~removeHandler(o, name, h)",  ev~completes, 2
rs~WillMove += h; rs~WillMove += h                        -- twice: called twice
rs~MovePrevious
call ok "a handler added twice",           ev~moves, 5
rs~WillMove -= h; rs~WillMove -= h
q = .net~handler(ev, "WILLMOVE", "queued")
rs~WillMove += q
rs~MoveFirst
call ok "a queued handler: not yet",       ev~moves, 5
.net~nextEvent(5)~dispatch
call ok "... until dispatched",            ev~moves ev~reason, "6 12"
rs~WillMove -= q
bad = .net~handler(ev, "FAILING")
rs~WillMove += bad
signal on syntax name failed
rs~MoveLast
call ok "an error in a handler", "no error", "42.3"
failed:
signal off syntax
call ok "an error in a handler: raised in the caller", condition("O")~code, "42.3"
rs~WillMove -= bad
signal on syntax name noEvent
.net~addHandler(rs, "NoSuchEvent", h)
noEvent:
signal off syntax
call ok "not an event: 97.1",              condition("O")~code, "97.1"
signal on syntax name notHandler
rs~WillMove += "x"
notHandler:
signal off syntax
call ok "+= a string: 98.900",             condition("O")~code, "98.900"
rs~WillMove += h
.net~releaseObject(rs)                                    -- disconnects its sinks too
call ok "releaseObject with handlers",     ev~moves, 6

if .fails = 0 then say "COM objects: all" .count "tests passed"
else say "COM objects:" .fails "of" .count "tests FAILED"
exit .fails > 0

::requires "net.cls"

::class AdoEvents                                         -- ADO's RecordsetEvents (some of them)
::attribute moves
::attribute completes
::attribute reason
::attribute status
::attribute error
::attribute rs
::attribute cancel
::method init
  self~moves = 0; self~completes = 0; self~cancel = .false
::method willMove                                         -- WillMove(adReason, adStatus*, pRecordset)
  use arg reason, status, rs
  self~moves += 1
  self~reason = reason; self~status = status; self~rs = rs
  if self~cancel then status~Value = 4                    -- adStatusCancel
::method moveComplete                                     -- MoveComplete(adReason, pError, adStatus*, pRecordset)
  use arg reason, error
  self~completes += 1; self~error = error
::method failing
  return 1 / 0

::routine ok
  use arg name, got, want
  .local~count += 1
  if got == want then return
  .local~fails += 1
  say "FAIL" name": got ["got"], want ["want"]"
