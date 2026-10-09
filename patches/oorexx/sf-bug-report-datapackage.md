# SourceForge bug report — ready to paste

Tracker: <https://sourceforge.net/p/oorexx/bugs/new/>

| Field | Value |
|---|---|
| **Title** | LoadPackageFromData: a later ::REQUIRES of the package's name fails after a garbage collection |
| **Milestone** | 5.3.0 |
| **Priority** | 5 |
| **Labels** | api |
| **Attachments** | `package-from-data-cache.diff`, `datapackage-repro.cpp` |

## Description (Markdown, paste as is)

A package loaded with the native API's `LoadPackageFromData(name, data, size)` is found by a later `::REQUIRES name` (in a routine created with `NewRoutine`, a program run with `CallProgram`...), but only until the next garbage collection. After one, the same `::REQUIRES` fails:

```
Error 43.901: Could not find file "x.cls" for ::REQUIRES.
```

So whether it works depends on when the collector runs: any allocation can trigger it, and so can the termination of another interpreter instance in the process (which is how we met it). It does not happen while something else keeps the package alive, for instance a routine that required it and is still referenced.

**Reproducer** (attached, `datapackage-repro.cpp`; prints `FIXED` or `BUG`): load a package from data as `x.cls`, keep no reference to it, run `return .Thing~new~hi` + `::requires 'x.cls'` (works), allocate some garbage, run it again (43.901). With `NOGARBAGE=1` the allocations are skipped and it passes.

```
g++ -I/usr/local/include datapackage-repro.cpp -o repro -lrexx -lrexxapi && VERBOSE=1 ./repro
  NewRoutine: Error 43: Could not find file "x.cls" for ::REQUIRES.
BUG: ::requires of a package from data fails after a garbage collection (43.901)
```

**Cause.** `PackageManager::loadRequires(activity, name, data, length, ...)` caches the new package with `addToRequiresCache()`, which stores a `WeakReference` in `loadedRequires`, as for every requires file. For a package from a file that is fine: once collected, `checkRequiresCache()` drops the entry and the file is read again. A package from in-store data cannot be read again, so once collected its name is simply gone. (The comment above that `loadRequires` says the package "is not cached like the other requires files", but it is cached, weakly.)

The documentation of `LoadPackageFromData` says only that `name` is "the name assigned to the package", which suggests that a `::REQUIRES` of that name should find it.

**Proposed fix** (attached, `package-from-data-cache.diff`, against trunk r13268, one file pair, `interpreter/package/PackageManager.cpp` / `.hpp`): `addToRequiresCache()` gets a parameter `weak` (default `true`); `loadRequires()` from data passes `false` and the package itself is stored in `loadedRequires`; `checkRequiresCache()` returns an entry that is not a `WeakReference` as it is. File and macrospace packages are unchanged. A package from data then lives as long as the requires cache. (If keeping them alive is not wanted, the alternative is to document that the caller must keep a reference to the package returned, e.g. a global reference, as long as `::REQUIRES` of its name must work.)

**Tested**: trunk r13268 built with CMake on Ubuntu 24.04 x86_64. The reproducer gives `BUG` without the patch and `FIXED` with it. ooRexx's test suite (test/trunk r13268, native API tests included, as root, stdin `/dev/null`, output to a file): 24143 tests, and the same 9 failures with and without the patch (environment-related: file permissions when run as root, output redirected).

Found while embedding ooRexx in .NET (<https://github.com/JosepMariaBlasco/oorexxnet>), whose assembly loads `net.cls` from data so that Rexx code run by a .NET application can `::requires "net.cls"` without any file; it now keeps a global reference to the package as a workaround.
