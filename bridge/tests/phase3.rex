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
do
  b6 = .net~RexxNetTests~Button~new
  b6~ValueChanged += .net~handler(t, "FAILON2")
  b6~StartValues(3, 10)
  t0 = time("E")
  do while t~failCount < 3 & time("E") - t0 < 10; call SysSleep 0.01; end
  report = .error~text
finally                                -- .error back however this ends (an error here is then seen)
  .local~error = saved
end
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

-- command environments from Rexx: ooRexx's own (.CommandHandler, r13288), with
-- a .NetCommandHandler for a .NET handler; the family's rules
-- (oorexx-bridges, topics/command-handlers.md)
call reg "CALC", dl~Calc
address calc "2+3"; call ok "command: RC", rc, 5
address calc "nothing"; call ok "no result: RC 0", rc, 0
do
  address calc "minus"; call ok "RC -3 raises nothing", rc, -3
catch error, failure
  call ok "RC -3 raises nothing", condition("C"), "nothing"
end
call ok "a .NET error: SYNTAX 98.900", code('address calc "throw"'), "98.900"
call ok "... the exception, additional[2]", code('address calc "throw"', 2), "System.FormatException"
call ok "a Rexx error: itself", code('address calc "divide"'), "42.3"
o = .array~new; address calc "lines" with output using (o)
call ok "WITH OUTPUT (caller~output)", o~makeString("l", ","), "one,two"
call ok "WITHOUT it: caller~output is SYNTAX 98.900, as ooRexx's", code('address calc "lines"'), "98.900"
do
  address calc "error"
  call ok "caller~raiseError: ERROR", "none", "ERROR"
catch error
  call ok "... its rc", condition("C") rc, "ERROR 5"
end
trace off
do
  address calc "failure"
  call ok "caller~raise FAILURE: FAILURE", "none", "FAILURE"
catch failure
  call ok "... rc, description, additional", condition("C") rc condition("D") condition("A"), "FAILURE -3 it could not run the additional"
finally
  trace normal
end
v = "issuer's"; drop nope; drop gone; gone = "x"
address calc "vars"; call ok "the variables: [], hasVar, a name with no value, environment", rc, "issuer's True False NOPE CALC"
o = .array~new; address calc "set" with output using (o)
call ok "... []=, setVar, dropVar", v w.1 symbol("GONE") rc, "set by .NET 42 LIT 1"
call reg "UP", dl~Upper
address up "abc"; call ok ".NET Func handler", rc, "ABC"
call reg "LEN", dl~Length
address len "abcd"; call ok ".NET delegate of another type", rc, 4
call reg "ECHO", dl~Echo
o = .array~new; address echo "hi" with output using (o)
call ok ".NET Action handler", rc o[1], "0 echo hi"
-- as any .CommandHandler: stacked, uncovered
call ok "a .NetCommandHandler is a .CommandHandler", .NetCommandHandler~new(dl~Upper)~isA(.CommandHandler), 1
call ok "the first: covers nothing", .CommandHandler~register("STACK", .NetCommandHandler~new(dl~Upper)) == .nil, 1
covered = .CommandHandler~register("STACK", .NetCommandHandler~new(dl~Length))
call ok "a second: covers the first", covered~isA(.NetCommandHandler), 1
address stack "abcd"; call ok "... the second serves", rc, 4
call ok "... .CommandHandler~handlers", .CommandHandler~handlers("STACK")~items, 2
removed = .CommandHandler~deregister("STACK")
call ok "deregister: the one removed", removed~isA(.NetCommandHandler) (removed \== covered), "1 1"
address stack "abcd"; call ok "... the first again", rc, "ABCD"
call ok "a Rexx handler over it, forwarding to it", .CommandHandler~register("STACK", .Doubler~new(covered)) == covered, 1
address stack "ab"; call ok "... it forwards", rc, "AB AB"
.CommandHandler~deregister("STACK"); .CommandHandler~deregister("STACK")
call ok "... gone", .CommandHandler~handler("STACK") == .nil, 1
call reg "STACK", dl~Length
.CommandHandler~deregister("STACK")
call reg "STACK", dl~Upper
address stack "x"; call ok "registered again after deregister", rc, "X"
call ok "the bridge's own entry is not among the environments", -
        .CommandHandler~environments~allIndexes~makeString("l", " ")~pos("REXXNET") == 0, 1
gone = .NetCommandHandler~new(dl~Upper); .CommandHandler~register("GONE", gone); gone~release
do
  address gone "x"
  call ok "a released .NetCommandHandler: FAILURE", "none", "FAILURE"
catch failure
  call ok "... RC 30, as an unknown environment", condition("C") rc, "FAILURE 30"
end
.CommandHandler~deregister("GONE")
.CommandHandler~deregister("STACK")
.CommandHandler~deregister("calc")
do
  address calc "2+3"
  call ok "deregistered: FAILURE", "none", "FAILURE"
catch failure
  call ok "deregistered: FAILURE RC 30, as unknown", condition("C") rc condition("D"), "FAILURE 30 2+3"
end
call err "a .nil handler: SYNTAX", '.NetCommandHandler~new(.nil)', "the handler is .nil"
call ok "... 93.900", code('.NetCommandHandler~new(.nil)'), "93.900"
call err "not a handler", '.NetCommandHandler~new("text")', "must be a .NET delegate taking the command and a"
call err "a .NetHandler: written in Rexx, it needs no .NET", '.NetCommandHandler~new(.net~handler(.Doubler~new(.nil), "COMMAND"))', "inherits .CommandHandler"
call ok "... 93.900", code('.NetCommandHandler~new("text")'), "93.900"
call reg "CALC", dl~Calc
address calc "2+3"; call ok "registered again", rc, 5
-- ::OPTIONS ERROR SYNTAX in the code that sends the command (ooRexx #2119,
-- fixed in r13282, turned a handler's non-ERROR condition into SYNTAX 98.970).
-- A guard: a USER from Rexx code the .NET handler calls does not reach the sender (non-SYNTAX
-- conditions are dropped at ooRexx's API, an open ooRexx bug), so it is
-- "rc 7" with the option as without it (r13278 and r13282 alike); when it
-- does arrive, it must not arrive as 98.970.
src = .array~of('use arg c', 'signal on syntax', 'address calc c', 'return "rc" rc', -
                'syntax: return "syntax" condition("O")~code', '::options error syntax')
errorSyntax = .routine~new("errorSyntax", src)
call ok "::options error syntax: a USER is not 98.970 (#2119)", errorSyntax~call("user") \== "syntax 98.970", 1
call ok "... a .NET error is still 98.900", errorSyntax~call("throw"), "syntax 98.900"
call ok "... an RC as without it", errorSyntax~call("2+3"), "rc 5"

-- A HALT that the handler's (or a callback's) Rexx code does not trap reaches
-- the bridge as SYNTAX 4.1; the sender gets a HALT again (oorexx-bridges,
-- command handlers, rule 1): through the command's context (RC 0), raised
-- for a callback, as RAISE HALT would: SIGNAL ON HALT traps it, CALL ON HALT
-- runs (for a callback at the call: haltOrder), untrapped it is SYNTAX 4.1.
halting = .net~type("System.Collections.Generic.List<int>")~new; halting~Add(2); halting~Add(1)
haltCmp = .net~handler(.HaltTester~new, "HALTCOMPARE")
call ok "a HALT from a command handler: SIGNAL ON HALT", haltSignalCmd(), "HALT"
call ok "... CALL ON HALT, RC 0", haltCallCmd(), "0 1"
call ok "... untrapped: SYNTAX 4.1", haltUntrappedCmd(), "SYNTAX 4.1"
call ok "a HALT from a callback: SIGNAL ON HALT", haltSignalCb(halting, haltCmp), "HALT"
call ok "... CALL ON HALT", haltCallCb(halting, haltCmp), "1"
call ok "... untrapped: SYNTAX 4.1", haltUntrappedCb(halting, haltCmp), "SYNTAX 4.1"
call ok "... CALL ON HALT: when the handler runs (callback)", haltOrder("callback", halting, haltCmp), "halt after"

-- A message that .NET sends (RexxObject.Send) to a Rexx method raising a
-- condition other than SYNTAX, while Rexx code waits for .NET: ooRexx looked
-- for the trap past .NET's frames, and a SIGNAL ON for it in that Rexx code
-- unwound through them (the process ended: a C++ exception through the
-- CLR). Now the message is sent nested (an attached thread context), as a
-- callback's. Rule 1 (oorexx-bridges, command handlers): the condition comes
-- back as itself, with its description and additional object (ooRexx r13320,
-- bug #2123: before, ooRexx's API dropped them); a HALT as a HALT. Not its
-- RC: the API has no way to raise one.
raiser = .Raiser~new
call ok "SIGNAL ON HALT, a .NET method sends to a method raising HALT", sendSignal(raiser, "HALT"), "HALT"
call ok "... SIGNAL ON NOTREADY, NOTREADY as itself", sendSignal(raiser, "NOTREADY"), "NOTREADY not ready a2"
call ok "... SIGNAL ON ERROR, ERROR", sendSignal(raiser, "ERROR"), "ERROR an error a3"
call ok "... SIGNAL ON FAILURE, FAILURE", sendSignal(raiser, "FAILURE"), "FAILURE a failure a4"
call ok "... SIGNAL ON USER, USER", sendSignal(raiser, "USER"), "USER OOPS a user condition a1"
call ok "... the same from a .NetHandler's method (a delegate .NET calls)", sendSignal(raiser, "USER", "handler"), "USER OOPS a user condition a1"
call ok "... NOTREADY from a .NetHandler's method", sendSignal(raiser, "NOTREADY", "handler"), "NOTREADY not ready a2"
call ok "CALL ON HALT, a .NET method sends to a method raising HALT: at the call", haltOrder("send", , , raiser), "halt after .nil"
call ok "... from a .NetHandler's method", haltOrder("handler", , , raiser), "halt after .nil"
call ok "a .NET command handler sends to a method raising HALT: SIGNAL ON HALT", sendCmd(raiser, "halt"), "HALT send halt"
call ok "... untrapped, the command: SYNTAX 4.1", sendCmdUntrapped(raiser), "SYNTAX 4.1"
call ok "... NOTREADY, SIGNAL ON NOTREADY: as itself", sendCmd(raiser, "notready"), "NOTREADY not ready a2"
call ok "... USER of Rexx code the handler runs", sendCmd(raiser, "", "user"), "USER OOPS from the handler"
-- RAISE ... RETURN value: not trapped, or after a CALL ON, the call that
-- raised it answers the value, as in plain Rexx (it is the method's result)
call ok "RAISE ... RETURN, untrapped: .NET's call answers the value", returned(raiser, "send"), "1"
call ok "... after CALL ON USER", returned(raiser, "send", "call on"), "handler 1"
call ok "... from a .NetHandler's method", returned(raiser, "handler"), "1"
call ok "... trapped, the condition object's RESULT is the value, as plain Rexx (#2174)", resultOf(raiser, "send") resultOf(raiser, "handler") resultOf(raiser, "rexx"), "1 1 1"
-- A thrown condition (THROW, ooRexx r13541; the Throw API, r13546: RFE #31)
-- that Rexx code called by .NET leaves: it goes on from caller to caller,
-- as in plain Rexx, past the Rexx code that called .NET (its condition
-- object, THROWN included, raised again as it is); CALL ON does not trap
-- it; .NET sees it as a RexxException whose Thrown is true. From r13550
-- (uncaught: error 4.901).
if .RexxInfo~revision >= 13550 then do
  thrower = .Thrower~new
  call ok "THROW, .NET sends to the method: caught two levels up", thrownUp(thrower, "send"), "USER OOPS thrown a1 1"
  call ok "... through a .NetHandler's method", thrownUp(thrower, "handler"), "USER OOPS thrown a1 1"
  call ok "... the same in plain Rexx", thrownUp(thrower, "rexx"), "USER OOPS thrown a1 1"
  call ok "... CALL ON does not trap it, through .NET", thrownCallOn(thrower, "send") thrownCallOn(thrower, "handler"), "outside outside"
  call ok "... nor in plain Rexx", thrownCallOn(thrower, "rexx"), "outside"
  call ok "... SIGNAL ON on the level that called .NET traps it", thrownSignal(thrower), "USER OOPS 1"
  call ok "THROW ERROR: its RC through .NET", thrownUp(thrower, "send", "ERROR"), "ERROR thrown error 5 1"
  call ok "THROW SYNTAX: the error through .NET, thrown", thrownUp(thrower, "send", "SYNTAX"), "SYNTAX 40.1 1"
  call ok ".NET sees it: RexxException.Thrown, Description (Send)", dl~CaughtSend(thrower, "USER"), "USER OOPS 1 thrown"
  call ok "... (a delegate)", dl~CaughtCall(.net~handler(thrower, "USER")), "USER OOPS 1 thrown"
  call ok "... a raised one: Thrown false", dl~CaughtSend(raiser, "USER"), "USER OOPS 0 a user condition"
  call ok "uncaught through .NET: error 4.901, as in plain Rexx", thrownUncaught(testlib), "4.901 Program interrupted with USER OOPS condition: thrown."
end

-- RexxException.Throw: .NET code throwing a Rexx condition to its Rexx
-- caller (rexxnet: the Throw API, ooRexx r13546, RFE #31), as the THROW
-- instruction there would. From r13550 (uncaught: error 4.901).
if .RexxInfo~revision >= 13550 then do
  th = .net~RexxNetTests~Throwing
  call ok "RexxException.Throw: caught two levels up, thrown, at the call", throwUp(th, "user"), "USER BADCONFIG [no port] [the config] 1 1"
  call ok "... with no description", throwUp(th, "bare"), "USER BARE [] [The NIL object] 1 1"
  call ok "... ERROR with its RC", throwUp(th, "error", "rc"), "ERROR 12 [it failed] 1"
  call ok "... FAILURE", throwUp(th, "failure", "rc"), "FAILURE -3 [] 1"
  call ok "... SYNTAX: the error, its message", throwUp(th, "syntax", "syntax"), "SYNTAX 40.1 External routine ""ABC"" failed. 1"
  call ok "... NOVALUE", throwUp(th, "novalue"), "NOVALUE [V] [The NIL object] 1 1"
  call ok "... an array as ADDITIONAL: an Array of its items", throwUp(th, "array", "array"), "3 1 two 1"
  call ok "... inside a wrapper exception", throwUp(th, "inner"), "USER BADCONFIG [inside] [The NIL object] 1 1"
  call ok "... a Task's (~await)", throwAwait(th), "USER BADCONFIG 1"
  call ok "... another .NET exception: 98.900, raised", throwUp(th, "plain", "syntax"), "SYNTAX 98.900 .NET error: System.InvalidOperationException: not a throw. 0"
  call ok "... SIGNAL ON on the calling level", throwSignal(th), "USER BADCONFIG 1"
  call ok "... CALL ON does not trap it", throwCallOn(th), "outside"
  call ok "... from a command handler, to the issuer", throwCmd("throw user", "user badConfig"), "USER BADCONFIG from the handler 1 The NIL object"
  call ok "... ERROR from a command handler, with its RC", throwCmd("throw error", "error"), "ERROR the command failed 1 12"
  call ok "... past a ::routine, from a method and from a command handler", throwPastRoutine(th), "1 1"
  call ok ".NET code on the way catches it as any RexxException", th~Caught("user") "|" th~Caught("syntax"), "USER BADCONFIG 1 no port  0 | SYNTAX 1 none 40.1 40"
  call ok "arguments THROW would not take: ArgumentException", th~Bad("FOO", .nil) "|" th~Bad("user", .nil) "|" th~Bad("error", .nil) "|" th~Bad("halt", 3), -
    'RexxException.Throw: "FOO" is no condition THROW takes | RexxException.Throw: USER needs one condition name, a Rexx symbol | RexxException.Throw: ERROR needs an rc | RexxException.Throw: HALT takes no rc'
  call ok "uncaught: error 4.901", throwUncaught(testlib), "4.901 Program interrupted with USER BADCONFIG condition: no port."
end

-- ERROR's and FAILURE's RC: the condition object raised again as it is
-- (RaiseConditionObject, ooRexx r13329), so the RC arrives as in plain Rexx:
-- the variable RC and the object's, with SIGNAL ON and with CALL ON
call ok "ERROR's RC, sent from .NET: SIGNAL ON ERROR", rcOf(raiser, "ERROR", "send"), "3 3"
call ok "... FAILURE's", rcOf(raiser, "FAILURE", "send"), "4 4"
call ok "... a .NetHandler's method", rcOf(raiser, "ERROR", "handler"), "3 3"
call ok "... CALL ON ERROR", rcOf(raiser, "ERROR", "send", "call on"), "3 3 x 3"
call ok "... a .NET command handler sends", rcOf(raiser, "ERROR", "command"), "3 3"
call ok "... a .NET command handler runs Rexx code", rcOf(raiser, "FAILURE", "run"), "4 4"
call ok "... plain Rexx, for reference", rcOf(raiser, "ERROR", "rexx") rcOf(raiser, "ERROR", "rexx", "call on"), "3 3 3 3 x 3"

-- A SYNTAX raised with a description (and a result) by Rexx code that .NET
-- called, raised again in the Rexx caller with all of them (the condition
-- object as it is: RaiseConditionObject, ooRexx r13329).
expect = "40.1 [the description] BOOM r"
call ok "a SYNTAX's description and result: sent from .NET", described("x = dl~SendTo(raiser, 'DESCRIBED')"), expect
call ok "... a .NetHandler's method", described("x = dl~Text(.net~handler(raiser, 'DESCRIBED'))"), expect
call ok "... a .NET command handler sends", described("address calc 'send described'"), expect
call ok "... a .NET command handler runs Rexx code", described("address calc 'run described'"), expect

-- An object that is not a string, made text by .NET (RexxObject.ToString:
-- ooRexx's requestString), with SIGNAL ON NOSTRING in the Rexx code that
-- called .NET: requestString raises NOSTRING when the caller traps it, and
-- in the context Rexx handed over that SIGNAL unwound through the CLR (the
-- process ended). Nested now: its text, no NOSTRING.
call ok "SIGNAL ON NOSTRING, .NET makes .object~new text", noString(.object~new), "an Object"
call ok "... an object of a class with no STRING method of its own", noString(.Raiser~new), "a RAISER"

-- A callback's reply (or what a message .NET sends answers) whose conversion
-- by .NET runs user code that raises a condition, with a SIGNAL ON for it in
-- the Rexx code that called .NET (oorexx-bridges, lesson 6): it reaches .NET
-- as a RexxException, .NET finishes, and the caller traps it as itself, as
-- when Rexx itself makes the object text. A SYNTAX from MAKESTRING or STRING
-- crashed the process (a null string read), and so did a SUPPLIER answering
-- no Supplier (now Error 98.994, as DO ... OVER gives).
call ok "a callback's reply made text by .NET, its MAKESTRING raising USER", reply("text", .ReplyMS~new("USER")), "USER SAYS makestring says no"
call ok "... its MAKESTRING raising SYNTAX", reply("text", .ReplyMS~new("SYNTAX")), "SYNTAX 93.900"
call ok "... its STRING raising USER", reply("text", .ReplySS~new("USER")), "USER SAYS string says no"
call ok "... its STRING raising SYNTAX", reply("text", .ReplySS~new("SYNTAX")), "SYNTAX 93.900"
call ok "... as plain Rexx makes it text", reply("rexx", .ReplyMS~new("SYNTAX")) reply("rexx", .ReplySS~new("USER")), "SYNTAX 93.900 USER SAYS string says no"
call ok "... what a message .NET sends answers, its MAKESTRING raising SYNTAX", reply("send", .ReplyMS~new("SYNTAX")), "SYNTAX 93.900"
call ok "... its STRING raising USER", reply("send", .ReplySS~new("USER")), "USER SAYS string says no"
call ok "a callback's reply copied to a dictionary, its SUPPLIER raising USER", reply("count", .ReplyDir~new("USER")), "USER SAYS supplier says no"
call ok "... raising SYNTAX", reply("count", .ReplyDir~new("SYNTAX")), "SYNTAX 93.900"
call ok "... answering nothing", reply("count", .ReplyDir~new("NOTHING")), "SYNTAX 98.994"
call ok "... answering a string", reply("count", .ReplyDir~new("WRONG")), "SYNTAX 98.994"
call ok "... copied to an array, its SUPPLIER raising USER", reply("length", .ReplyArr~new("USER")), "USER SAYS supplier says no"
call ok "... answering nothing", reply("length", .ReplyArr~new("NOTHING")), "SYNTAX 98.994"
call ok "... the process goes on", dl~TextOf(.net~handler(.Giver~new(.ReplyMS~new("FINE")), "GIVE")), "fine"

-- An argument whose own method raises while rexxnet encodes it for .NET (a
-- subclass of .LogicalWrapper, .NetRef or .NetTyped; oorexx-bridges, lesson
-- 7): the condition, before .NET runs. The encoding went on (.NET ran with a
-- wrong value, and its error replaced the condition), or read
-- ObjectToStringValue's NULL (the process ended).
call ok "an argument's own VALUE raising SYNTAX: a .LogicalWrapper subclass", encoded(.MyLogical~make("SYNTAX")), "93.900 value says no"
call ok "... VALUE answering an object whose MAKESTRING raises SYNTAX", encoded(.MyLogical~make("MS")), "93.900 makestring says no"
call ok "... VALUE answering nothing: 91.999, as plain Rexx", encoded(.MyLogical~make("NOTHING")), "91.999"
call ok "... VALUE answering 1", encoded(.MyLogical~make("ONE")), "ran True"
call ok "... a .NetRef subclass", encoded(.MyRef~new("SYNTAX")), "93.900 value says no"
call ok "... a .NetTyped subclass's VALUE", encoded(.MyTyped~new("SYNTAX")), "93.900 value says no"
call ok "... its KIND", encoded(.MyTyped~new("KIND")), "93.900 kind says no"
call ok "a .NetRef subclass whose own VALUE= raises, for an out parameter: that condition", outParam(), "93.900 value= says no"

-- CATCH clauses (ooRexx r13514, RFE #31): a block's CATCH clause catches
-- what crosses the bridge, as SIGNAL ON traps it above
do
  dl~Throw("nope")
  call ok "CATCH: a .NET exception", "not caught", "caught"
catch e = syntax
  call ok "CATCH: a .NET exception, SYNTAX 98.900", e~code condition("I"), "98.900 CATCH"
  call ok "... additional[2] the exception", .net~typeOf(e~additional[2]) e~additional[2]~Message, "System.IO.FileNotFoundException nope"
  call ok "... the variable: the condition object", e~condition e~instruction (e~message == condition("O")~message), "SYNTAX CATCH 1"
end
call ok "CATCH USER, a .NET method sends to a method raising it", caught(raiser, "USER"), "CATCH USER OOPS a user condition a1"
call ok "... NOTREADY", caught(raiser, "NOTREADY"), "CATCH NOTREADY not ready a2"
call ok "... ERROR, its RC", caught(raiser, "ERROR"), "CATCH ERROR an error a3 rc 3 3"
call ok "... FAILURE, its RC", caught(raiser, "FAILURE"), "CATCH FAILURE a failure a4 rc 4 4"
call ok "... USER from a .NetHandler's method", caught(raiser, "USER", "handler"), "CATCH USER OOPS a user condition a1"
call ok "... NOTREADY from a .NetHandler's method", caught(raiser, "NOTREADY", "handler"), "CATCH NOTREADY not ready a2"
call ok "... ERROR from a .NetHandler's method, its RC", caught(raiser, "ERROR", "handler"), "CATCH ERROR an error a3 rc 3 3"
call ok "... a .NET command handler sends: NOTREADY", caught(raiser, "notready", "command"), "CATCH NOTREADY not ready a2"
call ok "... ERROR, its RC", caught(raiser, "error", "command"), "CATCH ERROR an error a3 rc 3 3"
call ok "... with a SIGNAL ON for it set: the CATCH clause wins", catchWins(raiser), "caught"
do
  do
    x = dl~SendTo(raiser, "ERROR")
    r = "not caught"
  catch error 4                                  -- not this RC: the outer block's clause
    r = "caught by error 4"
  end
catch error 3
  r = "caught by error 3, rc" rc
end
call ok "CATCH ERROR code: the clause for the RC that came back", r, "caught by error 3, rc 3"
do
  halting~Sort(haltCmp)
  r = "not caught"
catch halt
  r = condition("C") condition("I")
end
call ok "CATCH HALT, a HALT given back for a callback", r, "HALT CATCH"
do
  address calc "halt"
  r = "not caught"
catch halt
  r = condition("C") condition("I") rc
end
call ok "... from a .NET command handler (RC 0)", r, "HALT CATCH 0"
do
  address calc "send halt"
  r = "not caught"
catch halt
  r = condition("C") condition("I")
end
call ok "... a .NET command handler sends to a method raising HALT", r, "HALT CATCH"
do
  r = .net~System~String~Concat(.object~new)
catch nostring
  r = "NOSTRING"
end
call ok "CATCH NOSTRING (a trap for requestString): .NET makes .object~new text", r, "an Object"
n = 0
do i = 1 to 3
  n += dl~Apply(.net~handler(t, "ADD"), i, 1)
  if i = 2 then dl~Run(.net~handler(t, "FAIL"))
catch syntax
  r = i n condition("O")~code
end
call ok "CATCH on a loop: a handler's error ends the loop", r, "2 5 98.900"

if .fails = 0 then say "phase 3: all" .count "tests passed"
else say "phase 3:" .fails "of" .count "tests FAILED"
exit .fails > 0

haltSignalCmd: signal on halt name haltSignalCmdTrap; address calc "halt"; return "not trapped"
  haltSignalCmdTrap: return condition("C")
haltCallCmd: halted = 0; call on halt name haltSeen; address calc "halt"; nop; nop; return rc halted
haltUntrappedCmd: do; address calc "halt"; return "nothing"; catch syntax; return "SYNTAX" condition("O")~code; end
haltSignalCb: use arg l, cmp; signal on halt name haltSignalCbTrap; l~Sort(cmp); return "not trapped"
  haltSignalCbTrap: return condition("C")
haltCallCb: use arg l, cmp; halted = 0; call on halt name haltSeen; l~Sort(cmp); nop; nop; return halted
haltUntrappedCb: use arg l, cmp; do; l~Sort(cmp); return "nothing"; catch syntax; return "SYNTAX" condition("O")~code; end
haltSeen: halted = 1; return
haltOrder: procedure expose dl      -- when CALL ON HALT's handler runs: at the call, as RAISE HALT's (a Ctrl-C's: after the next clause)
  use arg how, l, cmp, raiser
  seen = ""; x = "unset"
  call on halt name haltOrderSeen
  select
    when how = "callback" then l~Sort(cmp)
    when how = "send" then x = dl~SendTo(raiser, "HALT")
    when how = "handler" then x = dl~Text(.net~handler(raiser, "HALT"))
  end
  seen = seen "after"
  nop
  if how = "callback" then return strip(seen)
  if x == .nil then x = ".nil"
  return strip(seen) x
  haltOrderSeen: seen = seen "halt"; return
rcOf: procedure expose dl            -- the variable RC and the condition object's, a condition raised past .NET (raiser: the command handler reads it)
  use arg raiser, cond, how, trap = ""
  .local~handled = ""
  if trap = "call on" then do
    if cond = "ERROR" then call on error name rcOfHandler; else call on failure name rcOfHandler
  end
  else do
    if cond = "ERROR" then signal on error name rcOfTrap; else signal on failure name rcOfTrap
  end
  select
    when how = "send" then x = dl~SendTo(raiser, cond)
    when how = "handler" then x = dl~Text(.net~handler(raiser, cond))
    when how = "command" then address calc "send" cond~lower
    when how = "run" then address calc "run" cond~lower
    when how = "rexx" then x = raiser~send(cond)
  end
  if trap = "call on" then return .handled "x" x
  return "not trapped"
  rcOfTrap: return rc condition("O")~rc
  rcOfHandler: .local~handled = rc condition("O")~rc; return
sendSignal: procedure expose dl
  use arg o, cond, how = "send"
  select
    when cond = "HALT" then signal on halt name sendSignalTrap
    when cond = "NOTREADY" then signal on notready name sendSignalTrap
    when cond = "ERROR" then signal on error name sendSignalTrap
    when cond = "FAILURE" then signal on failure name sendSignalTrap
    when cond = "USER" then signal on user oops name sendSignalTrap
  end
  if how = "send" then r = dl~SendTo(o, cond)
  else r = dl~Text(.net~handler(o, cond))
  return "not trapped"
  sendSignalTrap: return conditionText(condition("O"))
noString: procedure
  use arg o
  signal on nostring name noStringTrap
  return .net~System~String~Concat(o)
  noStringTrap: return "NOSTRING"
sendCmd: use arg raiser, what, command = ("send" what)
  signal on halt name sendCmdTrap; signal on notready name sendCmdTrap
  signal on user oops name sendCmdTrap
  address calc command
  return "rc" rc
  sendCmdTrap: return conditionText(condition("O"))
returned: procedure expose dl        -- what x = (a .NET call reaching Raiser~user) gets
  use arg o, how, trap = ""
  .local~handled = ""
  if trap = "call on" then call on user oops name returnedHandler
  if how = "send" then x = dl~SendTo(o, "USER")
  else x = dl~Text(.net~handler(o, "USER"))
  return (.handled x)~strip
  returnedHandler: .local~handled = "handler"; return
encoded: procedure                  -- o as an argument to .NET (String.Format): what .NET made, or the condition
  use arg o
  do
    return .net~System~String~Format("ran {0}", o)
  catch c = syntax
    if c~code = "91.999" then return c~code
    return c~code c~additional[1]
  end
outParam: procedure                 -- Int32.TryParse("5", out r), r a .NetRef subclass whose VALUE= raises
  do
    .net~System~Int32~TryParse("5", .MySetRef~new)
    return "not trapped"
  catch c = syntax
    return c~code c~additional[1]
  end
reply: procedure expose dl          -- obj as a callback's reply ("text", "count", "length"), or answered to .NET's Send, or made text by Rexx
  use arg how, obj
  signal on user says name replyTrap; signal on syntax name replyTrap
  h = .net~handler(.Giver~new(obj), "GIVE")
  select
    when how = "text" then return dl~TextOf(h)
    when how = "count" then return dl~CountOf(h)
    when how = "length" then return dl~LengthOf(h)
    when how = "send" then return dl~SendText(.Giver~new(obj), "GIVE")
    when how = "rexx" then return "" || obj
  end
  replyTrap: c = condition("O")
  if c~condition == "SYNTAX" then return "SYNTAX" c~code
  return c~condition c~description
resultOf: procedure expose dl        -- RAISE USER ... RETURN, trapped by SIGNAL ON: condition("O")'s RESULT
  use arg o, how
  signal on user oops name resultOfTrap
  if how = "send" then x = dl~SendTo(o, "USER")
  else if how = "handler" then x = dl~Text(.net~handler(o, "USER"))
  else x = o~user
  return "not trapped"
  resultOfTrap: return condition("O")~result
thrownUp: procedure expose dl       -- a THROW two levels down (.NET between), caught here
  use arg o, how, cond = "USER"
  do
    call thrownMiddle dl, o, how, cond
    return "not caught"
  catch c = any
    if c~condition == "SYNTAX" then return c~condition c~code (c~thrown == .true)
    if c~condition == "ERROR" then return c~condition c~description c~rc (c~thrown == .true)
    return c~condition c~description c~additional[1] (c~thrown == .true)
  end
thrownMiddle: procedure              -- a level with no trap
  use arg dl, o, how, cond
  x = thrownVia(dl, o, how, cond)
  return "went on"
thrownVia: procedure
  use arg dl, o, how, cond
  if how = "rexx" then return o~send(cond)
  if how = "send" then return dl~SendTo(o, cond)
  return dl~Text(.net~handler(o, cond))
throwUp: procedure                   -- RexxException.Throw two levels down, caught here
  use arg th, what, show = ""
  do
    call throwMiddle th, what
    return "not caught"
  catch c = any
    if show == "rc" then return c~condition c~rc "["c~description"]" (c~thrown == .true)
    if show == "syntax" then return c~condition c~code c~message (c~thrown == .true)
    if show == "array" then return c~additional~items c~additional[1] c~additional[2] (c~additional[3] == .nil)
    return c~condition "["c~description"]" "["c~additional"]" (c~thrown == .true) (c~position == .throwAt)
  end
throwMiddle: procedure; use arg th, what
  .local~throwAt = .line; x = th~Throw(what)    -- (the line the condition is at)
  return "went on"
throwAwait: procedure
  use arg th
  do
    x = th~Later("user")~~await~result
    return "not caught"
  catch c = user badConfig
    return c~condition (c~thrown == .true)
  end
throwSignal: procedure
  use arg th
  signal on user badConfig name throwSignalTrap
  x = th~Throw("user")
  return "not trapped"
  throwSignalTrap: return condition("C") (condition("O")~thrown == .true)
throwCallOn: procedure
  use arg th
  do
    call throwCallOnLevel th
    return "went on"
  catch user badConfig
    return "outside"
  end
throwCallOnLevel: procedure
  use arg th
  call on user badConfig name throwCallOnTrap
  x = th~Throw("user")
  return
  throwCallOnTrap: return
throwCmd: procedure
  use arg command, cond
  do
    call throwCmdLevel command
    return "not caught"
  catch c = any
    return c~condition c~description (c~thrown == .true) c~rc
  end
throwCmdLevel: procedure
  use arg command
  address calc command
  return
throwUncaught: procedure             -- a child program leaves it uncaught: its error line
  use arg testlib
  file = .File~new("throw-" || date("S") || random(99999) || ".rex", .File~temporaryPath)~absolutePath
  call lineout file, "parse arg testlib; x = .net~load(testlib)"
  call lineout file, "x = .net~RexxNetTests~Throwing~Throw('user')"
  call lineout file, "say 'went on'"
  call lineout file, "::requires 'net.cls'"
  call lineout file
  out = .array~new
  address system 'rexx "'file'"' testlib with output using (out) error using (out)
  call SysFileDelete file
  do l over out
    if l~pos("Error 4.901:") > 0 then return "4.901" l~substr(l~pos(":") + 1)~strip
  end
  return "no 4.901:" out~makeString("L", " | ")
thrownCallOn: procedure expose dl
  use arg o, how
  do
    call thrownCallOnLevel dl, o, how
    return "went on"
  catch user oops
    return "outside"
  end
thrownCallOnLevel: procedure
  use arg dl, o, how
  call on user oops name thrownCallOnTrap
  x = thrownVia(dl, o, how, "USER")
  return
  thrownCallOnTrap: return
thrownSignal: procedure expose dl
  use arg o
  signal on user oops name thrownSignalTrap
  x = dl~SendTo(o, "USER")
  return "not trapped"
  thrownSignalTrap: return condition("C") (condition("O")~thrown == .true)
thrownUncaught: procedure            -- a child program leaves it uncaught: its error line
  use arg testlib
  file = .File~new("thrown-" || date("S") || random(99999) || ".rex", .File~temporaryPath)~absolutePath
  call lineout file, "parse arg testlib; x = .net~load(testlib)"
  call lineout file, "x = .net~RexxNetTests~Delegates~SendTo(.T~new, 'USER')"
  call lineout file, "say 'went on'"
  call lineout file, "::class T"
  call lineout file, "::method user; throw user oops description 'thrown'"
  call lineout file, "::requires 'net.cls'"
  call lineout file
  out = .array~new
  address system 'rexx "'file'"' testlib with output using (out) error using (out)
  call SysFileDelete file
  do l over out
    if l~pos("Error 4.901:") > 0 then return "4.901" l~substr(l~pos(":") + 1)~strip
  end
  return "no 4.901:" out~makeString("L", " | ")
conditionText: procedure            -- a condition object: its name, description and additional
  use arg o
  a = o~additional
  if a~isA(.array) then a = a~toString(, " "); else a = ""
  d = o~description; if d == .nil then d = ""
  return (o~condition d a)~space
caught: procedure expose dl          -- a condition raised by Raiser's method that .NET sends to, caught by CATCH
  use arg raiser, cond, how = "send"
  do
    select
      when how = "send" then x = dl~SendTo(raiser, cond)
      when how = "handler" then x = dl~Text(.net~handler(raiser, cond))
      when how = "command" then address calc "send" cond
    end
    return "not caught"
  catch c = user oops, notready
    return condition("I") conditionText(c)
  catch c = error, failure
    return condition("I") conditionText(c) "rc" rc c~rc
  end
catchWins: procedure expose dl      -- a SIGNAL ON for the same condition set: the block's clause wins
  use arg raiser
  signal on user oops name catchWinsLost
  do
    x = dl~SendTo(raiser, "USER")
    return "not caught"
  catch user oops
    return "caught"
  end
  catchWinsLost: return "SIGNAL ON took it"
sendCmdUntrapped: use arg raiser
  do
    address calc "send halt"
    return "nothing"
  catch syntax
    return "SYNTAX" condition("O")~code
  end


::requires "net.cls"

::routine throwPastRoutine            -- RexxException.Throw goes on past a ::routine (a native method's, a command handler's)
  use arg th
  r = ""
  do; call throwMethodRoutine th; r = "lost"; catch c = user badConfig; r = (c~thrown == .true); end
  do; call throwCmdRoutine; r = r "lost"; catch c = user badConfig; r = r (c~thrown == .true); end
  return r
::routine throwMethodRoutine; use arg th; x = th~Throw("user"); return
::routine throwCmdRoutine; address calc "throw user"; return

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

::routine reg                       -- a .NET handler as the environment name
  use strict arg name, handler
  .CommandHandler~register(name, .NetCommandHandler~new(handler))

::class Doubler inherit CommandHandler -- a handler written in Rexx, over another
::method init
  expose inner
  use strict arg inner
::method command
  expose inner
  use arg command, caller
  r = inner~command(command, caller)
  return r r
::class Raiser                    -- methods raising a condition, for .NET to send to
::method halt;     raise halt
::method notready; raise notready description "not ready" additional (.array~of("a2")) return 9
::method error;    raise error 3 description "an error" additional (.array~of("a3")) return 3
::method failure;  raise failure 4 description "a failure" additional (.array~of("a4")) return 4
::method user;     raise user oops description "a user condition" additional (.array~of("a1")) return 1
::method described; raise syntax 40.1 array("BOOM") description "the description" return "r"

::class Thrower                   -- methods throwing a condition (RFE #31), for .NET to send to
::method user;   throw user oops description "thrown" additional (.array~of("a1"))
::method error;  throw error 5 description "thrown error"
::method syntax; throw syntax 40.1 array("T")

::class Giver                     -- gives what it was made with
::method init; expose v; use arg v
::method give; expose v; return v
::class ReplyMS                   -- a reply whose MAKESTRING raises USER or SYNTAX
::method init; expose k; use arg k
::method makestring; expose k
  if k = "SYNTAX" then raise syntax 93.900 array("makestring says no")
  if k = "USER" then raise user says description "makestring says no"
  return "fine"
::class ReplySS                   -- a reply whose STRING raises USER or SYNTAX
::method init; expose k; use arg k
::method string; expose k
  if k = "SYNTAX" then raise syntax 93.900 array("string says no")
  raise user says description "string says no"
::class ReplyDir subclass directory   -- a reply whose SUPPLIER raises, or answers nothing or a string
::method init; expose k; use arg k; self~init:super; self["A"] = 1
::method supplier; expose k
  if k = "SYNTAX" then raise syntax 93.900 array("supplier says no")
  if k = "USER" then raise user says description "supplier says no"
  if k = "WRONG" then return "x"
  return
::class ReplyArr subclass array    -- the same, an Array subclass
::method new class; use arg k; o = self~new:super(2); o~k = k; o[1] = "a"; o[2] = "b"; return o
::attribute k
::method supplier; expose k
  if k = "USER" then raise user says description "supplier says no"
  return

::class MyLogical subclass LogicalWrapper   -- its own VALUE raises, answers nothing, or an object whose MAKESTRING raises
::method make class; use arg k; o = self~new(.true); o~k = k; return o
::attribute k
::method value
  if self~k = "SYNTAX" then raise syntax 93.900 array("value says no")
  if self~k = "MS" then return .ReplyMS~new("SYNTAX")
  if self~k = "NOTHING" then return
  return 1
::class MyRef subclass NetRef           -- its own VALUE raises
::method init; expose k; use arg k; self~init:super("x")
::method value; raise syntax 93.900 array("value says no")
::class MySetRef subclass NetRef        -- its own VALUE= raises
::method init; self~init:super(0)
::method "VALUE="; raise syntax 93.900 array("value= says no")
::class MyTyped subclass NetTyped       -- its own VALUE or KIND raises
::method init; expose k; use arg k; self~init:super("System.String", "x")
::method value; expose k
  if k = "SYNTAX" then raise syntax 93.900 array("value says no")
  return "x"
::method kind; expose k
  if k = "KIND" then raise syntax 93.900 array("kind says no")
  return "System.String"

::class HaltTester                -- a callback whose Rexx code is halted
::method haltCompare               -- a Comparison<int> whose Rexx code is halted
  raise halt

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

::routine described                -- the SYNTAX code raises: code [description] additional result
  use arg code
  raiser = .Raiser~new
  dl = .dl
  do
    interpret code
    return "no error"
  catch c = syntax
    return c~code "["condition("D")"]" c~additional~toString(, " ") c~result
  end

::routine code                    -- the code's error: its code, or (item 2) the type of additional[2]
  use arg code, item = 1
  do
    interpret code
    return "no error"
  catch c = syntax
    if item = 1 then return c~code
    return .net~typeOf(c~additional[2])
  end

::routine err                     -- the code must raise an error whose message contains fragment
  use arg name, code, fragment
  .local~count += 1
  do
    interpret code
    .local~fails += 1
    say "FAIL" name": no error"
  catch syntax
    msg = condition("O")~message
    if msg~pos(fragment) > 0 then return
    .local~fails += 1
    say "FAIL" name": message ["msg"], want ["fragment"]"
  end
