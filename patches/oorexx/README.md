# Patches for ooRexx itself

Patches proposed to ooRexx, not part of the bridge.
Reported as **#2106** (<https://sourceforge.net/p/oorexx/bugs/2106/>,
08/10/2026): "CallRoutine / CallProgram cost ~200 µs on Linux's main thread".

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
