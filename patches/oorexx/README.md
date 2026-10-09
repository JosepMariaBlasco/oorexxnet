# Patches for ooRexx itself

Patches proposed to ooRexx, not part of the bridge.
Reported as **#2106** (<https://sourceforge.net/p/oorexx/bugs/2106/>,
08/10/2026): "CallRoutine / CallProgram cost ~200 µs on Linux's main thread".
**Fixed in ooRexx trunk r13267** (08/10/2026), with this patch as proposed.
Kept here for the record.

## `sysactivity-stack-per-thread.diff` (08/10/2026, against trunk r13263)

One file: `interpreter/platform/unix/SysActivity.cpp`.

**Problem.** On Linux, entering the interpreter from outside is slow on the
process's main thread, and the cost grows with the number of memory
mappings of the process. `SysActivity::getStackBase()` and `getStackSize()`
call `pthread_getattr_np()` every time, and for the main thread glibc
answers that by opening and parsing `/proc/self/maps` (strace: one `openat`
and ~27 `read`s). The interpreter asks on every entry: `Activity::run
(ActivityDispatcher &)` (`CallRoutine`, `CallProgram`, `RexxStart`, the
translate APIs) recomputes `stackLimit`, and each new Activity (one per
`RexxStart`) computes it in its constructor: 1 read per `CallRoutine`, 3 per
`RexxStart`. Commands and exits are not affected (`run(CallbackDispatcher &)`
does not ask). Windows and macOS are not affected (cheap answers there).

**Fix.** `currentThreadStack()`, a `static` helper that asks
`pthread_getattr_np()` once per thread and keeps the answer in
`thread_local` storage (C++11, ooRexx's standard); `getStackBase()` and
`getStackSize()` use it. A thread's stack does not move while it lives, and
each new thread asks for its own. Only the `HAVE_PTHREAD_GETATTR_NP` branch
(Linux, AIX) changes; the AIX adjustment is kept.

**Measured** (this container, x86_64, glibc 2.39), trunk r13263 → r13263
+ the patch:

| | before | after |
|---|---|---|
| reads of `/proc/self/maps` | 1 per `CallRoutine`, 3 per `RexxStart` | 1 in the whole process |
| `CallRoutine`, main thread of a .NET host | 208 µs | 6.7 µs (another thread: 5.7) |
| `RexxStart`, plain C program | 356 µs | 192 µs |
| `RexxStart`, with 1000 / 3000 extra mappings | 2765 / 7015 µs | 209 / 206 µs |

Error 11 ("Control stack full") is still raised on deep recursion: on the
main thread and on another thread of a .NET host, and in `rexx` itself.

**Test suite**: ooRexx's test suite (test/trunk at r13263, with the native
API tests) gives 24179 tests and the same 9 environment-related failures with
and without the patch.

**Considered first** (and dropped): removing the recomputation from
`Activity::run` only. It fixes `CallRoutine` / `CallProgram`, but `RexxStart`
keeps 2 of its 3 reads (the new Activity's constructor and one more), and
it changes the interpreter's logic rather than one platform function.

**To test after building:** ooRexx's test suite, checked out at the same
revision (the suite at HEAD may have tests for later fixes: at r13265 it has
#2085's, which segfaults on r13263); the bridge's `bridge/tests/run.sh`;
and `stackbase-repro.cpp` (slow before, fast after).

## `call-testgroup-stacksize-threads.diff` (09/10/2026, against test/trunk r13267)

Tests for #2106, which was committed without them (pending work item:
tests). A timing test would be fragile; what a change to the stack limit can
break is the limit itself. Three tests added to
`ooRexx/base/keyword/CALL.testGroup`, next to `test_stacksize`: deep
recursion must end in SYNTAX 11.1 after a depth of at least 5000 (the same
threshold as `test_stacksize`) on the main thread (the framework runs the
tests there: checked, pid = tid), on a thread started with `~start`, and on
the thread that goes on after `REPLY`. `test_stacksize` itself only covers
the main thread and does not check the code.

**Results** (r13267, Linux x86_64): `testOORexx.rex -f CALL` gives 28 tests,
187 assertions, 0 failures (25 and 181 before), three runs. Depth reached:
~18 500 on each of the three threads. With the per-thread cache broken on
purpose (`static` instead of `static thread_local`), the main thread is
still fine and the process aborts as soon as another thread runs Rexx code
(`terminate called after throwing an instance of 'ActivityException'`), so
that particular mistake would also stop the rest of the suite.
