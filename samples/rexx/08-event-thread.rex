/* 08-event-thread.rex: the event thread with no user interface.
   An object that only one thread may touch (here, a model of a job's
   progress) lives on the event thread: with no windows, that is the Rexx
   thread waiting in .net~eventLoop. A worker on another Rexx thread sends it
   messages with .NetEventThread's runLater family (BSF4ooRexx's names), and
   each send returns a GUIMessage:
     runLaterLatest  progress reports: a newer one replaces any still queued,
                     so the event thread never falls behind;
     runLater        a question whose answer the worker waits for (result);
                     an error, kept in its GUIMessage (hasError);
                     at the end, .net~stopEventLoop.                        */

say "The event thread:" .NetEventThread~default~makeString
model = .Progress~new
.Worker~new~start(model, 40)                           -- on another Rexx thread
.net~eventLoop                                         -- this thread runs the messages, until stopped
say "Progress reports sent: 40; run:" model~reports "(each newer one replaced those still queued)"
exit

::requires "net.cls"

::class Progress                                       -- touched only on the event thread
::attribute reports get
::method init
  expose done total reports
  done = 0; total = 0; reports = 0
::method progress                                      -- runLaterLatest: only the newest queued one runs
  expose done total reports
  use arg done, total
  reports += 1
  say "  progress" done"/"total "(on the event thread:" .NetEventThread~isEventThread")"
  call SysSleep 0.05                                   -- showing it takes longer than a step
::method percent                                       -- runLater: the worker waits for its result
  expose done total
  return done * 100 % total
::method check                                         -- runLater: its error stays in its GUIMessage
  use arg value
  if \datatype(value, "W") then raise syntax 88.903 array ("value", value)
  return value

::class Worker
::method start unguarded
  use arg model, steps
  reply                                                -- the rest on a new Rexx thread
  say "Worker: on the event thread?" .NetEventThread~isEventThread
  do i = 1 to steps
    call SysSleep 0.01                                 -- some work
    m = .NetEventThread~runLaterLatest(model, "PROGRESS", "I", i, steps)
  end
  say "Worker: the last report has run?" m~completed "(not yet, perhaps: it is queued)"

  p = .NetEventThread~runLater(model, "PERCENT")
  say "Worker: asked for the percentage;" p~makeString
  say "Worker: percentage" p~result"% (result waits until it has run)"
  say "Worker: now" p~makeString", hasResult" p~hasResult

  e = .NetEventThread~runLater(model, "CHECK", "I", "abc")
  x = e~result                                         -- waits; no result: the error is kept
  say "Worker: check failed?" e~hasError"; error" e~errorCondition~code":" e~errorCondition~message

  .NetEventThread~runLater(.net, "STOPEVENTLOOP")      -- the event thread ends its loop
