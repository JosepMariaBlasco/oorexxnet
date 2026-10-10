/* ooRexx/.NET bridge: the event thread (.NetEventThread, .GUIMessage: BSF4ooRexx's
   AbstractGUIThread and GUIMessage). Without a user interface the event thread is the Rexx
   thread in .net~nextEvent / .net~eventLoop; on Windows, a Windows Forms window's thread too. */
.local~fails = 0; .local~count = 0
w = .Worker~new

-- no user interface: the messages wait for the thread that serves the queue
call ok "kind: no user interface",          .NetEventThread~kind, "loop"
m = .NetEventThread~runLater(w, "ADD", "I", 2, 3)
call ok "runLater: a GUIMessage, not run yet", m~isA(.GUIMessage) m~completed m~hasResult, "1 0 0"
call ok "its parts",                        (m~target == w) m~messageName m~hasArguments m~arguments~makeString("L", ","), "1 ADD 1 2,3"
.net~nextEvent(5)~dispatch                               -- this thread serves the queue: it runs
call ok "run on the event thread",          m~completed m~hasResult m~result m~hasError, "1 1 5 0"
call ok "isEventThread there",              w~onEventThread, 1

w~log = ""
.NetEventThread~runLater(w, "NOTE", "I", "a")
.NetEventThread~runLater(w, "NOTE", "A", .array~of("b"))
.NetEventThread~runLaterPush(w, "NOTE", "I", "c")         -- first
.NetEventThread~runLater(w, "OTHER")
.NetEventThread~runLaterLatest(w, "NOTE", "I", "d")       -- a and b go; d last
.net~nextEvent(5)~dispatch                               -- one run: the whole queue
call ok "order: Push first; Latest replaces", w~log, "other d"
w~log = ""
.NetEventThread~runLater(w, "NOTE", "I", "x")
.NetEventThread~runLater(w, "NOTE", "I", "y")
.NetEventThread~runLaterLatestPush(w, "NOTE", "I", "z")
.NetEventThread~runLater(w, "NOTE", "I", "q")
.net~nextEvent(5)~dispatch
call ok "LatestPush: replaces, and first",  w~log, "z q"

e = .NetEventThread~runLater(w, "FAIL")
n = .NetEventThread~runLater(w, "NOTHING")
.net~nextEvent(5)~dispatch
call ok "an error: kept in its GUIMessage", e~completed e~hasError e~errorCondition~code e~hasResult, "1 1 42.3 0"
call ok "... and the next one runs",        n~completed n~hasError n~hasResult, "1 0 0"

-- from another thread: the event thread runs it, the other waits for its result
w~startWaiter                                            -- another Rexx thread: runLater, then ~result
call ok "the other thread is not the event thread", w~waiterOnEventThread, 0
.net~nextEvent(5)~dispatch
call SysSleep 0.2
call ok "result waited for, on the other thread", w~waited, 42

signal on syntax name badArgs
x = .NetEventThread~runLater(w, "ADD", "X", 1)
badArgs:
signal off syntax
call ok "a wrong indicator: 93.915",        condition("O")~code, "93.915"

-- event threads as objects: with no user interface, the loop's
d = .NetEventThread~default
call ok "default: the loop's",              d~kind d~id d~makeString, "loop 0 a NetEventThread (the loop)"
call ok "no UI threads",                    .NetEventThread~threads~items, 0
call ok "current: this thread serves the loop", .NetEventThread~current == d, 1
call ok "eventThreadFor a Rexx object: the default", .NetEventThread~eventThreadFor(w) == d, 1
m = d~runLater(w, "ADD", "I", 20, 22)                   -- an instance's runLater
.net~nextEvent(5)~dispatch
call ok "instance runLater",                m~result d~isEventThread, "42 1"

-- Windows: a Windows Forms window's thread is the event thread; two more, each its own
if .rexxInfo~platform~upper~abbrev("WIN") then do
  call windowsForms w
  call twoWindows
end

if .fails = 0 then say "event thread: all" .count "tests passed"
else say "event thread:" .fails "of" .count "tests FAILED"
exit .fails > 0

windowsForms: procedure
  use arg w
  forms = .net~System~Windows~Forms
  form = forms~Form~new
  form~Text = "before"
  call ok "Windows Forms: kind ui",         .NetEventThread~kind, "ui"
  w~startUpdater(form)                     -- another thread: runLater(form, "TEXT=", ...), then Close
  forms~Application~Run(form)              -- this thread is the window's; returns when it closes
  call ok "Windows Forms: run on its thread", w~formText w~formOnEventThread, "from another thread 1"
  do 100 while w~updates == "UPDATES"      -- (the other thread notes them once Close has run)
    call SysSleep 0.05
  end
  call ok "Windows Forms: the GUIMessages",  w~updates, "1 1"
  return

/* Two more UI threads, each a Rexx thread running a window: messages go to the right one */
twoWindows: procedure
  a = .Window~new; a~start("A")
  b = .Window~new; b~start("B")
  do 200 until a~shown & b~shown                         -- their windows exist
    call SysSleep 0.05
  end
  ea = .NetEventThread~eventThreadFor(a~form)
  eb = .NetEventThread~eventThreadFor(b~form)
  call ok "two UI threads: eventThreadFor a control", (ea~id = a~threadId) (eb~id = b~threadId) (ea~id \= eb~id), "1 1 1"
  call ok "... among the threads",           .NetEventThread~threads~items >= 3, 1
  ma = ea~runLater(a, "SEEN")
  mb = eb~runLater(b, "SEEN")
  call ok "... each message on its thread",  (ma~result = a~threadId) (mb~result = b~threadId), "1 1"
  t = .NetEventThread~runLater(b~form, "TEXT=", "I", "B2")   -- the class method: to the target's thread
  call ok "... the class method too",       eb~runLater(b~form, "TEXT")~result, "B2"
  ca = .NetEventThread~runLater(a~form, "CLOSE")
  cb = .NetEventThread~runLater(b~form, "CLOSE")
  x = ca~result; x = cb~result
  do 100 until a~closed & b~closed
    call SysSleep 0.05
  end
  call ok "... and both closed",             a~closed b~closed, "1 1"
  return

::requires "net.cls"

::class Window                                           -- a window on a Rexx thread of its own
::attribute form
::attribute threadId
::attribute closed
::method init
  self~closed = .false; self~form = .nil
::method start unguarded
  use arg title
  reply                                                  -- the rest on a new thread
  forms = .net~System~Windows~Forms
  f = forms~Form~new
  f~Text = title
  self~threadId = .NetEventThread~current~id             -- this thread is a UI thread now
  self~form = f
  forms~Application~Run(f)                               -- returns when the window closes
  self~closed = .true
::method shown unguarded
  f = self~form
  if f == .nil then return .false
  return f~IsHandleCreated
::method seen unguarded                                  -- run by runLater: on which event thread?
  return .NetEventThread~current~id

::class Worker
::attribute log
::attribute onEventThread
::attribute waited
::attribute formText
::attribute formOnEventThread
::attribute updates
::method init
  self~log = ""; self~waited = .nil; self~updates = "UPDATES"
::method add unguarded
  use arg a, b
  self~onEventThread = .NetEventThread~isEventThread
  return a + b
::method note unguarded
  use arg x
  self~log = (self~log x)~strip
::method other unguarded
  self~log = (self~log "other")~strip
::method fail unguarded
  return 1 / 0
::method nothing unguarded
  return
::method answer unguarded
  return 42
::method startWaiter unguarded
  expose waiterFlag
  reply                                                  -- the rest on a new thread
  waiterFlag = .NetEventThread~isEventThread
  m = .NetEventThread~runLater(self, "ANSWER")
  self~waited = m~result                                 -- waits until the event thread has run it
::method waiterOnEventThread unguarded                   -- (waits until the other thread has looked)
  expose waiterFlag
  do while var("WAITERFLAG") = 0
    call SysSleep 0.05
  end
  return waiterFlag
::method record unguarded                                -- on the window's thread
  use arg form
  self~formText = form~Text
  self~formOnEventThread = .NetEventThread~isEventThread
::method startUpdater unguarded
  use arg form
  reply
  call SysSleep 0.5                                      -- the window is running
  a = .NetEventThread~runLater(form, "TEXT=", "I", "from another thread")
  b = .NetEventThread~runLater(self, "RECORD", "I", form)
  c = .NetEventThread~runLater(form, "CLOSE")
  x = c~result                                           -- waits until the window has run it
  self~updates = a~completed b~completed

::routine ok
  use arg name, got, want
  .local~count += 1
  if got == want then return
  .local~fails += 1
  say "FAIL" name": got ["got"], want ["want"]"
