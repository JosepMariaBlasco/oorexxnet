/* 06-events.rex: .NET events handled by Rexx methods.
   A timer's Elapsed event, queued: .NET's threads only queue the calls, and
   this Rexx thread runs them in .net~eventLoop, one at a time, until a
   handler calls .net~stopEventLoop. Then a FileSystemWatcher's events, taken
   one by one with .net~nextEvent.                                         */

timer = .net~System~Timers~Timer~new(200)
clock = .Clock~new(5)
handler = .net~handler(clock, "TICK", "queued")
timer~Elapsed += handler
timer~Start
say "Five ticks, 200 ms apart:"
.net~eventLoop
timer~Elapsed -= handler
timer~Dispose
say "Stopped after" clock~ticks "ticks"

-- file events: create a file in a watched directory, then wait for the call
io = .net~System~IO
dir = io~Directory~CreateTempSubdirectory("rexxnet-watch")~FullName
watcher = io~FileSystemWatcher~new(dir)
watcher~Created += .net~handler(.Watch~new, "CREATED", "queued")
watcher~EnableRaisingEvents = .true
io~File~WriteAllText(io~Path~Combine(dir, "hello.txt"), "hi")
call = .net~nextEvent(5)                   -- a queued call, or .nil after 5 seconds
if call == .nil then say "No file event within 5 seconds"
else call~dispatch                         -- runs the handler on this thread
watcher~Dispose
io~Directory~Delete(dir, .true)

::requires "net.cls"

::class Clock
::attribute ticks get
::method init
  expose left ticks
  use arg left
  ticks = 0
::method tick
  expose left ticks
  use arg sender, e                        -- the event's arguments
  ticks += 1
  say "  tick" ticks "at" e~SignalTime~ToString("HH:mm:ss.fff")
  if ticks = left then .net~stopEventLoop

::class Watch
::method created
  use arg sender, e
  say "Created:" e~Name "("e~ChangeType")"
