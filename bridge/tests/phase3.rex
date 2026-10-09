/* ooRexx/.NET bridge, phase 3 (callbacks and events): tests. Run by
   tests/run.sh after phase2.rex, with TestLib's path. */
parse arg testlib
.local~fails = 0; .local~count = 0
x = .net~load(testlib)
t = .Tester~new
dl = .net~RexxNetTests~Delegates
.local~dl = dl; .local~t = t
.local~mainThread = .net~System~Environment~CurrentManagedThreadId

-- delegates of any type, synchronous
call ok "Func<int, int, int>",  dl~Apply(.net~handler(t, "ADD"), 3, 4), 7
call ok "Func<string>",         dl~Text(.net~handler(t, "HELLO")), "hello from Rexx"
p = .net~handler(t, "ISLONG")
call ok "Predicate<string>",    dl~Check(p, "abcdef") dl~Check(p, "ab"), "1 0"
l = .net~type("System.Collections.Generic.List<int>")~new
do x over .array~of(5, 3, 9, 1); l~Add(x); end
l~Sort(.net~handler(t, "DESC"))
call ok "Comparison<T> (re-entrant)", join(l), "9 5 3 1"
call ok "guarded, nested on the same thread", t~sortSelf, "1 3 5 9"
call ok "Func<int, int> (LINQ-like)", dl~Sum(l, .net~handler(t, "DOUBLE")), 36
call ok "Linq Where",           join(.net~System~Linq~Enumerable~Where(l, .net~handler(t, "ISBIG"))), "9 5"
call ok "void before a value",  dl~Kind(.net~handler(t, "SEVEN")), "Action"
call ok "forced Func<int>",     dl~Kind(.net~as(.net~handler(t, "SEVEN"), "System.Func<int>")), "Func<int>:7"
n = t~bumps
call ok "Delegate parameter (Action)", dl~RunDelegate(.net~handler(t, "BUMP")) t~bumps - n, "The NIL object 1"
.net~System~Threading~Tasks~Task~Run(.net~handler(t, "BUMP"))~await
call ok "Task.Run(Action)~await", t~bumps - n, 2
n = t~bumps
.net~System~Threading~Tasks~Task~Delay(10)~ContinueWith(.net~handler(t, "BUMP"))~await
call ok "task~ContinueWith(handler)", t~bumps - n, 1
call ok "Task.Run(Func<int>)~await", .net~System~Threading~Tasks~Task~Run(.net~as(.net~handler(t, "SEVEN"), "System.Func<int>"))~await, 7
call err "ref parameter",       ".dl~WithRef(.net~handler(.t, 'ADD'))", "ref, out, pointer or span parameters"
call err "not a delegate",      ".dl~Check(.net~handler(.t, 'ADD'), .net~handler(.t, 'ADD'))", "accepts"
call err "unknown option",      "x = .net~handler(.t, 'ADD', 'bogus')", "unknown option bogus"

-- events: += and -=, the same delegate each time
b = .net~RexxNetTests~Button~new
h = .net~handler(t, "CLICKED")
b~Click += h
b~Click += h
call ok "two subscriptions",    b~ClickSubscribers, 2
b~Click -= h
call ok "-= removes one",       b~ClickSubscribers, 1
b~PerformClick
call ok "event handler ran",    t~clicks, 1
call ok "sender is the object", t~lastSender == b, 1
call ok "EventArgs",            .net~typeOf(t~lastArgs), "System.EventArgs"
b~ValueChanged += .net~handler(t, "VALUE")
b~SetValue(42)
call ok "EventHandler<T>",      t~lastValue, 42
b~Closing += .net~handler(t, "CLOSING")
t~allowClose = 0
call ok "e~Cancel = 1",         b~Close, 0
t~allowClose = 1
call ok "e~Cancel left",        b~Close, 1
btype = .net~RexxNetTests~Button
btype~Shared += .net~handler(t, "ONSHARED")
btype~RaiseShared
call ok "static event",         t~shared, 1
call ok "a NetEvent",           b~Click~makeString, "a NetEvent (Click of a NetObject (RexxNetTests.Button #" || b~netId || "))"
.local~b = b; .local~h = h
call err "= on an event",       ".b~Click = 5", "is an event: use o~Click += handler"
call err "another object's event", ".b~Click = .net~RexxNetTests~Button~new~Click", "an event changes only with += and -="
call err "event with arguments", "x = .b~Click(1)", "is not a method"
call err "+= a string",         ".b~Click += 'x'", "cannot use x as a System.EventHandler"
call err "a ref event",         ".b~WithRef += .net~handler(.t, 'ADD')", "ref, out, pointer or span parameters"
b~Click -= h
call ok "-= the last one",      b~ClickSubscribers, 0
-- addHandler / removeHandler, and .NET's accessor names
.net~addHandler(b, "Click", h)
call ok ".net~addHandler",      b~ClickSubscribers, 1
.net~removeHandler(b, "click", h)
call ok ".net~removeHandler",   b~ClickSubscribers, 0
b~add_Click(h); b~add_Click(h)
call ok "o~add_Click(h)",       b~ClickSubscribers, 2
b~remove_Click(h)
call ok "o~remove_Click(h)",    b~ClickSubscribers, 1
.net~invoke(b, "remove_Click", h)
call ok ".net~invoke(o, 'remove_Click', h)", b~ClickSubscribers, 0
btype~add_Shared(.net~handler(t, "ONSHARED"))
btype~RaiseShared
call ok "static: t~add_Shared(h)", t~shared, 3
call ok "a method named add_X wins", b~add_Thing(1), "method"
call err "addHandler: not an event", ".net~addHandler(.b, 'ClickSubscribers', .h)", "is not an event"
call ok ".net~events(o)",       .net~events(b)~makeString("L", " "), "Click ValueChanged Closing WithRef Thing"
call ok ".net~events(type)",    .net~events(btype)~makeString("L", " "), "Shared"
call err "add_X: not an event",  ".b~add_Nothing(.h)", 'does not understand message "ADD_NOTHING"'

-- other threads
c0 = t~clicks
b~Click += h
call ok "event from another thread (caller waits)", b~ClickFromOtherThread(3), "3 True"
call ok "... handled",          t~clicks - c0, 3
call ok "... on another thread", t~otherThread, 1
b2 = .net~RexxNetTests~Button~new
b2~ValueChanged += .net~handler(t, "COUNTVALUE")
b2~StartValues(5, 20)
t0 = time("E")
do while t~valueCount < 5 & time("E") - t0 < 10
  x = 0; do i = 1 to 5000; x = x + i; end       -- busy Rexx code meanwhile
end
call ok "events while Rexx runs", t~valueCount, 5
n = t~bumps
call ok "4 threads at once",    dl~Parallel(.net~handler(t, "BUMP"), 4) (t~bumps - n), "4 4"

-- errors in handlers
parse value dl~Catch(.net~handler(t, "FAIL")) with type "|" code "|" line "|" msg "|" inner
call ok "a RexxException in .NET", type code msg, "RexxException 98.900 a Rexx error in a handler."
call ok "... its line",         line, t~failLine
parse value dl~Catch(.net~handler(t, "THROWS")) with type "|" code "|" line "|" msg "|" inner
call ok "round trip: InnerException", type code inner, "RexxException 98.900 FileNotFoundException"
call err "raised again in Rexx", ".dl~Run(.net~handler(.t, 'FAIL'))", "a Rexx error in a handler"
call err "... through a wrapper", ".dl~Wrap(.net~handler(.t, 'FAIL'))", "a Rexx error in a handler"
call ok "... as it was (41.1)", code(".dl~Run(.net~handler(.t, 'ARITH'))"), "41.1"
call ok "... the .NET exception kept", code(".dl~Run(.net~handler(.t, 'THROWS'))", 2), "System.IO.FileNotFoundException"
call err "returned nothing",    "x = .dl~Apply(.net~handler(.t, 'NOTHING'), 1, 2)", "returned nothing; its delegate needs a System.Int32"
call err "returned the wrong thing", "x = .dl~Apply(.net~handler(.t, 'HELLO'), 1, 2)", "needs a System.Int32"

-- an error in a handler no Rexx code waits on (a background thread): reported, the program goes on
saved = .error
.local~error = .Collector~new
b6 = .net~RexxNetTests~Button~new
b6~ValueChanged += .net~handler(t, "FAILON2")
b6~StartValues(3, 10)
t0 = time("E")
do while t~failCount < 3 & time("E") - t0 < 10; call SysSleep 0.01; end
report = .error~text
.local~error = saved
call ok "no Rexx caller: the events go on", t~failCount, 3
call ok "... reported as Rexx does", report~pos("Error 98.900:  boom 2") > 0, 1
call ok "... with its traceback", report~pos('raise syntax 98.900 array("boom"') > 0, 1
call ok "... and what happened", report~pos("the program goes on") > 0, 1

-- queued
q = .net~handler(t, "ONQUEUED", "queued")
call ok "options",              q~options, "queued"
call ok "a NetHandler",         q~makeString, "a NetHandler (a TESTER~ONQUEUED, queued)"
b3 = .net~RexxNetTests~Button~new
b3~ValueChanged += q
b3~SetValue(1); b3~SetValue(2)
call ok "queued, not run",      .net~queuedCalls t~queued, "2 "
ev = .net~nextEvent(0)
call ok "a NetCall",            ev~message ev~arguments~items, "ONQUEUED 2"
ev~dispatch
call ok "dispatched",           t~queued, "1"
.net~nextEvent~dispatch
call ok "in order",             t~queued, "1 2"
call ok "nothing left",         .net~nextEvent(0.1), .nil
call ok "queued Func: default", dl~Apply(.net~handler(t, "ADD", "queued"), 1, 2), 0
call ok "... its call waits",   .net~nextEvent(0)~dispatch, 3
lq = .net~handler(t, "ONQUEUED", "latest")
call ok "latest implies queued", lq~options, "latest queued"
b4 = .net~RexxNetTests~Button~new
b4~ValueChanged += lq
b4~SetValue(3); b4~SetValue(4); b4~SetValue(5)
call ok "latest keeps one",     .net~queuedCalls, 1
.net~nextEvent~dispatch
call ok "the newest",           t~queued, "1 2 5"
b5 = .net~RexxNetTests~Button~new
b5~ValueChanged += .net~handler(t, "LOOPVALUE", "queued")
b5~StartValues(3, 10)
.net~eventLoop                                     -- LOOPVALUE stops it at 3
call ok "eventLoop until stopEventLoop", t~loopValues, "1 2 3"

-- release
h~release
c0 = t~clicks
b~PerformClick
call ok "released: not called", t~clicks - c0, 0
b~ValueChanged += q
q~release
b~SetValue(9)
call ok "released: not queued", .net~queuedCalls, 0
call ok "released Func: default", dl~Apply(.net~handler(t, "ADD")~~release, 1, 2), 0
call ok "released, still subscribed", b~ClickSubscribers, 1
b~Click -= h                                       -- a released handler still goes (for -=)
call ok "released: -= finds it", b~ClickSubscribers, 0

if .fails = 0 then say "phase 3: all" .count "tests passed"
else say "phase 3:" .fails "of" .count "tests FAILED"
exit .fails > 0

::requires "net.cls"

::class Tester
::attribute clicks
::attribute lastSender
::attribute lastArgs
::attribute lastValue
::attribute allowClose
::attribute shared
::attribute bumps
::attribute valueCount
::attribute otherThread
::attribute queued
::attribute loopValues
::attribute failLine
::attribute failCount
::method init
  expose clicks bumps valueCount shared queued loopValues allowClose failCount
  clicks = 0; bumps = 0; valueCount = 0; shared = 0; queued = ""; loopValues = ""; allowClose = 1
  failCount = 0
::method add;      use arg a, b; return a + b
::method hello;    return "hello from Rexx"
::method isLong;   use arg s; return length(s) > 3
::method desc;     use arg a, b; return sign(b - a)
::method asc;      use arg a, b; return sign(a - b)
::method double;   use arg x; return 2 * x
::method isBig;    use arg x; return x > 4
::method seven;    return 7
::method nothing;  return
::method bump unguarded
  expose bumps
  guard on
  bumps += 1
::method sortSelf                                 -- guarded: its handler (ASC) nests on this thread
  l = .net~type("System.Collections.Generic.List<int>")~new
  do x over .array~of(5, 3, 9, 1); l~Add(x); end
  l~Sort(.net~handler(self, "ASC"))
  return join(l)
::method clicked
  expose clicks lastSender lastArgs otherThread
  use arg lastSender, lastArgs
  clicks += 1
  otherThread = .net~System~Environment~CurrentManagedThreadId \= .mainThread
::method value
  expose lastValue
  use arg sender, e
  lastValue = e~Value
::method countValue unguarded
  expose valueCount
  guard on
  valueCount += 1
::method closing
  expose allowClose
  use arg sender, e
  if \allowClose then e~Cancel = 1
::method onShared
  expose shared
  shared += 1
::method fail
  expose failLine
  failLine = .context~line + 1
  raise syntax 98.900 array("a Rexx error in a handler")
::method failOn2 unguarded
  expose failCount
  use arg sender, e
  failCount += 1
  if e~Value = 2 then raise syntax 98.900 array("boom" e~Value)
::method throws
  .local~dl~Throw("nope")
::method arith
  return 1 + "a"
::method onQueued
  expose queued
  use arg sender, e
  queued = (queued e~Value)~strip
::method loopValue
  expose loopValues
  use arg sender, e
  loopValues = (loopValues e~Value)~strip
  if e~Value = 3 then .net~stopEventLoop

::class Collector                 -- stands for .error: collects its lines
::attribute text
::method init
  expose text
  text = ""
::method lineout
  expose text
  use arg line
  text = text || line || "0a"x
  return 0

::routine join
  use arg coll
  s = ""
  do x over coll; s = s x; end
  return s~strip

::routine ok
  use arg name, got, want
  .local~count += 1
  if got == want then return
  .local~fails += 1
  say "FAIL" name": got ["got"], want ["want"]"

::routine code                    -- the code's error: its code, or (item 2) the type of additional[2]
  use arg code, item = 1
  signal on syntax
  interpret code
  return "no error"
syntax:
  c = condition("O")
  if item = 1 then return c~code
  return .net~typeOf(c~additional[2])

::routine err                     -- the code must raise an error whose message contains fragment
  use arg name, code, fragment
  .local~count += 1
  signal on syntax
  interpret code
  .local~fails += 1
  say "FAIL" name": no error"
  return
syntax:
  msg = condition("O")~message
  if msg~pos(fragment) > 0 then return
  .local~fails += 1
  say "FAIL" name": message ["msg"], want ["fragment"]"
