/* select-case-repro.rex: SELECT CASE whose CASE expression runs code that
   allocates (a method of a Rexx class here: any message, or a string BIF,
   allocates). RexxInstructionSelectCase::execute creates the instruction's
   DoBlock, then evaluates the CASE expression, and only then anchors the
   block in the activation: a garbage collection during the evaluation
   reclaims the block, which the activation then uses. The heap is corrupted:
   a crash (SIGSEGV, 0xC0000005) or a hang (DeadObjectPool::findFit looping
   on a broken free chain), soon or later.

       rexx select-case-repro.rex [loops]       (default 300000)

   ooRexx 5.3.0 r13269, Linux x86_64: SIGSEGV within a second, every run.
   With the patch (select-case-gc.diff): "built 2288895". */
parse arg loops .
if loops == "" then loops = 300000
o = .Thing~new
out = .mutableBuffer~new
do i = 1 to loops
  select case o~alpha~beta~name
    when "Monday" then out~append("m")
    when "Friday" then out~append("f" i)
    otherwise out~append("o")
  end
end
say "built" out~length
::class Thing
::method unknown                     -- each message makes a new object, and some garbage
  use arg name
  t = .Thing~new
  junk = .array~of(name, name~reverse, copies(name, 3))
  return t
::method name
  return "Friday"
