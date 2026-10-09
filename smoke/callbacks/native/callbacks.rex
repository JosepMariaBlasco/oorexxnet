/* The callbacks probe: .NET calling Rexx synchronously (see Callbacks.cs). */
h = .Handler~new
call CbInit h

-- 1. the Rexx thread inside a long .NET call; another .NET thread calls Rexx
say "block:" CbBlock(1500, 3)

-- 2. re-entrancy: a .NET comparator calling Rexx on the same thread
say "sort:" CbSort("pear apple fig banana")

-- 3. a .NET thread calling Rexx while Rexx code runs (and while it sleeps)
call CbStartAsync 5, 50
t0 = time("E")
do while CbAsyncDone() < 5 & time("E") - t0 < 5
  x = 0; do i = 1 to 20000; x = x + i; end     -- busy Rexx code
end
say "async: done" CbAsyncDone() "of 5, handled" h~asyncCount

-- 4. an error in the Rexx callback reaches .NET, and Rexx as an error
signal on syntax
say "fail:" CbFail()
exit
syntax: say "fail: error:" condition("O")~message
exit

::class Handler
::attribute asyncCount
::method init
  expose asyncCount
  asyncCount = 0
::method callback
  expose asyncCount
  parse arg kind a b
  select
    when kind = "block" then return "rexx saw block" a
    when kind = "compare" then
      if a < b then return -1; else if a > b then return 1; else return 0
    when kind = "async" then do; asyncCount += 1; return "ok"; end
    when kind = "fail" then raise syntax 98.900 array("a Rexx error in a callback")
  end

::routine CbInit       external "LIBRARY cbprobe CbInit"
::routine CbBlock      external "LIBRARY cbprobe CbBlock"
::routine CbSort       external "LIBRARY cbprobe CbSort"
::routine CbStartAsync external "LIBRARY cbprobe CbStartAsync"
::routine CbAsyncDone  external "LIBRARY cbprobe CbAsyncDone"
::routine CbFail       external "LIBRARY cbprobe CbFail"
