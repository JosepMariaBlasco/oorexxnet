/* ooRexx/.NET bridge: lifetimes the two garbage collectors decide, with
   nothing done by hand. The instances of Rexx classes extending .NET classes
   (.net~extend): each is a pair, its Rexx object and its .NET object, which
   lives while Rexx holds the one or .NET the other. And handlers
   (.net~handler): held for .NET while something there can call them. Both
   collectors are forced: Rexx's by making garbage, .NET's by GC.Collect
   (GcProbe). Run by tests/run.sh with TestLib's path. */
parse arg testlib
.local~fails = 0; .local~count = 0; .local~uninits = 0
x = .net~load(testlib)
probe = .net~RexxNetTests~GcProbe
.local~probe = probe
.net~extend(.Sq, "RexxNetTests.Shape")
.net~extend(.Plain, "RexxNetTests.Shape")       -- no UNINIT of its own
same = .net~RexxNetTests~ExtendProbe
start = .net~handleCount

-- 1. nobody holds them: released, the class's UNINIT once each
do i = 1 to 200; s = .Sq~new(i); end
drop s
call collect
call ok "dropped by both sides: all 200 released, UNINIT once each", .uninits, 200
call ok "their handles too", .net~handleCount - start, 0

-- 2. .NET holds them alone: they live, and their overrides run
.local~uninits = 0
do i = 1 to 100; probe~Keep(.Sq~new(i)); end
call collect
call ok "held by .NET alone: none released", .uninits, 0
call ok "held by .NET alone: .NET calls their overrides", probe~Reports~countStr("<sq:"), 100
call ok "... also from a thread of its own", probe~ReportsElsewhere~countStr("<sq:"), 100
call collect
call ok "after those calls, still none released", .uninits, 0
probe~Clear                                    -- then .NET lets them go too
call collect
call ok "then dropped by .NET: all 100 released", .uninits, 100
call ok "their handles too", .net~handleCount - start, 0

-- 3. Rexx holds one alone: it lives, and so does its .NET object
.local~uninits = 0
r = .Sq~new(3)
call collect
call ok "held by Rexx alone: not released, its .NET object works", .uninits r~Report, "0 <sq: 9>"

-- 4. .NET holds it, then Rexx takes it back and .NET lets go
probe~Keep(.Sq~new(4))
call collect
b = probe~Take(0)                              -- comes back to Rexx (held by .NET alone until now)
probe~Clear
call collect
call ok "taken back by Rexx: it lives, overrides and all", b~class~id .uninits b~Report, "SQ 0 <sq: 16>"
call ok "back from .NET: itself", same~Same(b) == b, 1
drop b r
call collect
call ok "then dropped by Rexx too: both released", .uninits, 2

-- 5. a class with no UNINIT of its own
do i = 1 to 50; p = .Plain~new; end
probe~Keep(p)
drop p
call collect
call ok "no UNINIT: held by .NET alone, works", probe~Reports, "plain: 1"
probe~Clear
call collect
call ok "no UNINIT: all released", .net~handleCount - start, 0

-- 6. several rounds: held by .NET, taken back, dropped, held again...
.local~uninits = 0
o = .Sq~new(5)
do round = 1 to 5
  probe~Keep(o); drop o
  call collect
  o = probe~Take(0); probe~Clear
  call collect
end
call ok "five rounds between the two sides: alive", .uninits o~Report, "0 <sq: 25>"
drop o
call collect
call ok "then released, UNINIT once", .uninits, 1

-- 7. four Rexx threads moving 300 objects back and forth while both collectors run
.local~uninits = 0
.local~moved = 0
do t = 1 to 4
  .Mover~new~start("RUN", t, 75)
end
do 60 until .moved == 4
  call collect
end
call ok "stress: four threads finished", .moved, 4
probe~Clear
call collect
call ok "stress: 300 moved, all released at the end, UNINIT once each", .uninits, 300
call ok "stress: no handles left", .net~handleCount - start, 0

-- 8. handlers: held for .NET while something there can call them
.local~targets = 0                     -- live Target objects (their UNINIT counts down)
do i = 1 to 50                         -- a synchronous use, the handler dropped by Rexx
  r = probe~SortWith(.net~handler(.Target~new, "COMPARE"))
end
call collect
call ok "handlers used once, dropped by Rexx: released", .targets r, "0 a bb ccc"
do i = 1 to 30                         -- kept by .NET alone
  probe~KeepAction(.net~handler(.Target~new, "RUN"))
end
call collect
call ok "handlers kept by .NET alone: held", .targets, 30
.local~runs = 0
call ok "... and .NET calls them", probe~RunActions .runs, "30 30"
probe~ClearActions                     -- then .NET lets them go
call collect
call ok "then dropped by .NET: released", .targets, 0
h = .net~handler(.Target~new, "COMPARE")    -- held by Rexx, given many times
do i = 1 to 20; r = probe~SortWith(h); call collect; end
call ok "a handler Rexx holds, given again after .NET let it go", .targets r, "1 a bb ccc"
lst = .net~new(.net~type("System.Collections.Generic.List<string>"))
lst~Add("bb"); lst~Add("a")
lst~Sort(h)
call ok "... still the same handler", lst~Item(0) .targets, "a 1"
drop h
call collect
call ok "then dropped by Rexx too: released", .targets, 0
q = .net~handler(.Target~new, "RUN", "queued")   -- queued: the queue holds it
probe~KeepAction(q); x = probe~RunActions; probe~ClearActions
drop q
call collect
call ok "a queued call, its handler dropped by both: still held", .targets .net~queuedCalls, "1 1"
.local~runs = 0
c = .net~nextEvent(1)
c~dispatch
drop c
call collect
call ok "... dispatched, then released", .runs .targets, "1 0"

-- 9. classes made at run time and extended: collected with their .NET types
kept = probe~ExtendedTypes             -- Sq, Plain (::CLASS: they live with the program)
do i = 1 to 5
  c = .NetObject~subclass("DYN"i)
  c~define("AREA", "return" i)
  .net~extend(c, "RexxNetTests.Shape")
  o = c~new
  r = o~Report
end
call ok "classes made at run time, extended: their .NET types", probe~ExtendedTypes - kept r, "5 shape: 5"
drop c o
call collect
call ok "... collected with the classes and their instances", probe~ExtendedTypes, kept
call ok "the ::CLASS ones live on", .Sq~new(6)~Report, "<sq: 36>"

-- 10. the end of the program: the pairs still alive are over, UNINIT once each
parse source . . me
cmd = 'rexx "'me~left(me~lastPos(.file~separator))'lifetime-end.rex" "'testlib'"'
address system cmd with output stem out.
got = 0; bad = 0
do i = 1 to out.0
  if out.i~word(1) == "uninit" then do
    got += 1
    parse var out.i . "sq:" v
    if \datatype(v~strip, "W") | v~strip = 0 then bad += 1
  end
end
call ok "at the end: all 11 pairs over, UNINIT once each, their overrides working", got bad, "11 0"

say
if .fails = 0 then say "lifetime: all" .count "tests passed"
else say "lifetime:" .fails "of" .count "tests FAILED"
exit .fails > 0

ok: procedure
  use arg name, got, want
  .local~count += 1
  if got == want then return
  .local~fails += 1
  say "FAIL" name": got" got", expected" want
  return

-- both collectors, a few rounds: Rexx's (garbage), .NET's, then a request
-- (the pairs .NET found over are finished with the next one)
collect: procedure
  do 3
    do k = 1 to 4; a = .array~new; do j = 1 to 50000; a[j] = .mutableBuffer~new("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"); end; drop a; end
    .probe~Collect
    n = .net~handleCount
    call SysSleep 0.02
  end
  return

::requires "net.cls"

::class Sq subclass NetObject
::method init
  expose side
  use strict arg side
  self~init:super("sq")
::method Area
  expose side
  return side * side
::method Describe
  return "<" || self~base.Describe || ">"
::method uninit                         -- the class's UNINIT: once, when the pair is over
  self~class~counted
::method counted class                  -- (guarded: UNINITs run on any thread)
  .local~uninits += 1

::class Plain subclass NetObject
::method init
  self~init:super("plain")
::method Area
  return 1

::class Target                          -- a handler's target, counted while alive
::method init
  self~class~alive(1)
::method uninit
  self~class~alive(-1)
::method alive class                    -- (guarded)
  use arg n
  .local~targets += n
::method compare unguarded
  use arg a, b
  return sign(a~length - b~length)
::method run unguarded
  self~class~ran
::method ran class
  .local~runs += 1

::class Mover
::method run unguarded
  use arg t, n
  probe = .probe
  do i = 1 to n
    o = .Sq~new(i)
    probe~Keep(o)                       -- .NET holds it too
    if i // 3 = 0 then drop o           -- some: .NET alone
    else if o~Report \== "<sq:" i*i">" then say "Mover" t": bad report" o~Report
    if i // 5 = 0 then do               -- some taken back
      k = probe~Count
      if k > 0 then x = probe~Take(random(0, k - 1))
      if x~Report~left(4) \== "<sq:" then say "Mover" t": bad report taken back"
      drop x
    end
  end
  self~class~finished
::method finished class                 -- (guarded)
  .local~moved += 1
