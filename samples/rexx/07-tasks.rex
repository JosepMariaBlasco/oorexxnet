/* 07-tasks.rex: tasks and threads.
   ~await waits for a .NET Task and gives its result. Task.Run runs a Rexx
   method on .NET's thread pool: .net~handler makes it the delegate, and
   .net~as chooses which one (Task.Run has overloads for an Action and for a
   Func<T>; the Func<int> returns the method's result).                     */

tasks = .net~System~Threading~Tasks
sw = .net~System~Diagnostics~Stopwatch~StartNew
t = tasks~Task~Delay(300)
say "Started a 300 ms delay; status" t~Status
t~await
say "Awaited after" sw~ElapsedMilliseconds "ms; status" t~Status

-- four Rexx computations on the thread pool (on one thread or several, as the pool decides)
say "This Rexx thread is .NET thread" .net~System~Environment~CurrentManagedThreadId
running = .array~new
do n = 1 to 4
  work = .net~as(.net~handler(.Sum~new(n * 1000000), "RUN"), "System.Func<long>")
  running~append(tasks~Task~Run(work))
end
do t over running
  say "  result:" t~await
end

::requires "net.cls"

::class Sum
::method init
  expose limit
  use arg limit
::method run                              -- runs on a thread-pool thread
  expose limit
  numeric digits 20
  sum = limit * (limit + 1) / 2           -- (Gauss: no need to loop)
  say "  sum to" limit "on .NET thread" .net~System~Environment~CurrentManagedThreadId
  return sum
