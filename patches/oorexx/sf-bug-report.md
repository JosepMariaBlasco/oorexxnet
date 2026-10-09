# SourceForge bug report — ready to paste

Tracker: <https://sourceforge.net/p/oorexx/bugs/new/>

| Field | Value |
|---|---|
| **Title** | Linux: entering the interpreter is slow on the process's main thread (pthread_getattr_np reads /proc/self/maps on every call) |
| **Milestone** | 5.3.0 |
| **Priority** | 5 |
| **Labels** | performance, linux, api |
| **Attachments** | `sysactivity-stack-per-thread.diff`, `stackbase-repro.cpp` |

## Description (Markdown, paste as is)

On Linux, every entry into the interpreter from outside (`CallRoutine`, `CallProgram`, `RexxStart`, the translate APIs) is slow when made on the process's **main** thread, and the cost grows with the number of memory mappings of the process. Other threads are not affected.

Measured with the attached reproducer (ooRexx 5.3.0 r13263, Ubuntu 24.04 x86_64, glibc 2.39), µs per call:

| | main thread | other thread |
|---|---|---|
| `CallRoutine`, plain C program | 38.7 | 2.5 |
| `CallRoutine`, 3000 extra mappings | 2466.9 | 2.6 |
| `RexxStart`, plain C program | 420.0 | 233.1 |
| `RexxStart`, 3000 extra mappings | 7382.2 | 227.1 |

A .NET or JVM process has thousands of mappings: in a .NET application hosting ooRexx, `CallRoutine` takes ~200 µs on the main thread against ~5 µs elsewhere. In .NET, as in most GUI applications, the main thread is the one that runs the program.

**Cause.** `SysActivity::getStackBase()` and `SysActivity::getStackSize()` (`platform/unix/SysActivity.cpp`) call `pthread_getattr_np()` every time. For the main thread, glibc answers that by opening and parsing `/proc/self/maps`:

```
$ strace -e trace=openat ./stackbase-repro 2>&1 | grep -c /proc/self/maps
```

shows one `openat` (and ~27 `read`s, plus `prlimit64` and `sched_getaffinity`) per call. The interpreter asks on every entry: `Activity::run(ActivityDispatcher &)` recomputes `stackLimit`, and each new `Activity` computes it in its constructor (`RexxStart` creates one per call). That makes 1 read per `CallRoutine` and 3 per `RexxStart`. Commands and exits are not affected (`Activity::run(CallbackDispatcher &)` does not ask), nor are Windows and macOS, where the answer is cheap.

**Fix (attached patch, `platform/unix/SysActivity.cpp` only).** A static helper asks `pthread_getattr_np()` once per thread and keeps the answer in `thread_local` storage (C++11); `getStackBase()` and `getStackSize()` use it. A thread's stack does not move while the thread lives, and each new thread asks for its own. Only the `HAVE_PTHREAD_GETATTR_NP` branch (Linux, AIX) changes; the AIX adjustment is kept.

With the patch (same machine, r13263 + patch), µs per call:

| | main thread | other thread |
|---|---|---|
| `CallRoutine`, plain C program | 2.7 | 2.0 |
| `CallRoutine`, 3000 extra mappings | 2.8 | 2.1 |
| `RexxStart`, plain C program | 266.3 | 223.8 |
| `RexxStart`, 3000 extra mappings | 283.1 | 215.2 |

`/proc/self/maps` is then read once in the whole process. Error 11 (*Control stack full*) is still raised on deep recursion, on the main thread and on other threads.

**Test suite** (`test/trunk` at r13263, native API tests included, run as root with output redirected to a file): 24179 tests, the same 9 failures with and without the patch, all environmental (file permissions as root; `CHAROUT`, `LINEOUT` and `Stream` tests with redirected output).

**Reproducer** (attached, `stackbase-repro.cpp`): creates an instance, maps N separate pages to lengthen `/proc/self/maps` (default 3000), and times 500 `CallRoutine` and 200 instore `RexxStart` calls on the main thread and on a second thread.

```
g++ -O2 -I/usr/local/include stackbase-repro.cpp -L/usr/local/lib -lrexx -lpthread -o stackbase-repro
./stackbase-repro        # 3000 extra mappings
./stackbase-repro 0      # a plain process
```
