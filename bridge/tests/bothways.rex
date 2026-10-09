/* ooRexx/.NET bridge, phase C (both ways in one process, guest mode): tests.
   Run by tests/run.sh after phase3.rex, with TestLib's path. Rexx is the
   host here (rexx bothways.rex); the .NET code (TestLib/BothWays.cs) reaches
   this interpreter through RexxInterpreter.Current. */
parse arg testlib
.local~fails = 0; .local~count = 0
x = .net~load(testlib)
bw = .net~RexxNetTests~BothWays
.local~bw = bw

call ok "a guest instance",              bw~IsGuest, 1
call ok "the same one each time",        bw~SameInstance bw~SameInstance, "1 1"
call ok "a nested Run",                  bw~Nested, 42
d = .directory~new; d~a = 1; d~b = 2
call ok "a RexxObject parameter",        bw~ClassOf(d), "Directory"
call ok "back as itself",                bw~Echo(d) == d, 1
call ok "a stem",                        bw~ClassOf(.stem~new), "Stem"
call ok "a .NET object to Rexx (guest)", bw~LengthInRexx("abcd"), 4
call ok "a .NetObject back to .NET",     bw~BackFromRexx, "abc"
call ok "from another .NET thread",      bw~FromAnotherThread(d), 2
bw~Keep(d)
call ok "kept, used later",              bw~UseKept, 2
call ok "kept, used on another thread",  bw~UseKeptElsewhere, 2
call ok ".NET catches a nested error",   bw~Catches, "caught 40.1, then 7"
call ok "Dispose does nothing (guest)",  bw~DisposeDoesNothing, 1
call ok "a command environment (guest)", bw~Command, "7 hello"
t = .Tester~new
call ok "a handler's Rexx object",       bw~HandlerGives(.net~as(.net~handler(t, "MAKEDIR"), "System.Func<object>")), "Directory 5"
call ok "... on another thread",         bw~HandlerGivesElsewhere(.net~as(.net~handler(t, "MAKEDIR"), "System.Func<object>")), "Directory 5"
call ok "98.900 round trip (guest)",     bw~CatchesBoom, "98.900 InvalidOperationException boom"

-- a Rexx error in Rexx code that .NET called: raised here again, as it was
.local~acct = .Account~new(10)
call ok "the same error",                code(".bw~Withdraw(.acct, 100)"), "88.900"
call ok "its message",                   message(".bw~Withdraw(.acct, 100)"), "insufficient funds: 10."
call ok "and it goes on",                .acct~balance, 10

if .fails = 0 then say "bothways (phase C, guest mode): all" .count "tests passed"
else say "bothways (phase C, guest mode):" .fails "of" .count "tests FAILED"
exit .fails > 0

::requires "net.cls"

::routine ok
  use arg name, got, want
  .local~count += 1
  if got == want then return
  .local~fails += 1
  say "FAIL" name": got ["got"], want ["want"]"

::routine code
  use arg code
  signal on syntax
  interpret code
  return "no error"
syntax:
  return condition("O")~code

::routine message
  use arg code
  signal on syntax
  interpret code
  return "no error"
syntax:
  return condition("O")~message

::class Account
::attribute balance get
::method init; expose balance; use arg balance
::method withdraw; expose balance; use arg n
  if n > balance then raise syntax 88.900 array('insufficient funds:' balance)
  balance -= n; return balance

::class Tester
::method makeDir; d = .directory~new; d~x = 5; return d
