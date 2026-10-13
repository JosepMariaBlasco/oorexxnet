/* For tests/lifetime.rex: at the end of the program, every pair still alive
   (held by Rexx, or by .NET alone) is over: its class's UNINIT runs once,
   and its overrides still work meanwhile. Prints one line per UNINIT. */
parse arg testlib
testlib = testlib~strip~strip("B", '"')      -- (on Windows the quotes come with it)
x = .net~load(testlib)
probe = .net~RexxNetTests~GcProbe
.net~extend(.Sq, "RexxNetTests.Shape")
r = .Sq~new(2)                          -- held by Rexx
do i = 1 to 10; probe~Keep(.Sq~new(i)); end   -- held by .NET alone (once Rexx collects)
do k = 1 to 4; a = .array~new; do j = 1 to 50000; a[j] = .mutableBuffer~new("xxxxxxxxxxxxxxxxxxxxxxxx"); end; drop a; end
n = probe~Count

::requires "net.cls"
::class Sq subclass NetObject
::method init
  expose side
  use strict arg side
  self~init:super("sq")
::method Area
  expose side
  return side * side
::method uninit
  say "uninit" self~Report
