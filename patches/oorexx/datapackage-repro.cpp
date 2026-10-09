// A package loaded with the native API's LoadPackageFromData(name, data,
// size) satisfies a later ::REQUIRES of that name only until the next
// garbage collection: then ::REQUIRES fails with 43.901 ("Could not find
// file"), because the requires cache holds the package through a
// WeakReference and a package from data cannot be read again.
//
//   g++ -I<ooRexx include> datapackage-repro.cpp -o repro -lrexx -lrexxapi && ./repro
//
// Prints FIXED or BUG. VERBOSE=1 shows the condition; NOGARBAGE=1 skips the
// allocations that make the collection (then it passes: the collection is
// the cause).
#include <oorexxapi.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
// runs "::requires 'x.cls'" code in the instance: 1 if it worked
static int requiresWorks(RexxThreadContext *tc)
{
    const char *src = "return .Thing~new~hi\n::requires 'x.cls'\n";
    // (every local reference released: a routine kept alive keeps the
    // package it requires alive too)
    RexxRoutineObject r = tc->NewRoutine("t", src, strlen(src));
    if (r == NULLOBJECT)                          // the ::requires is resolved here
    {
        if (getenv("VERBOSE") && tc->CheckCondition())
        {
            RexxCondition c;
            tc->DecodeConditionInfo(tc->GetConditionInfo(), &c);
            printf("  NewRoutine: Error %zd: %s\n", (ssize_t)c.rc, c.message ? tc->CString(c.message) : "");
        }
        tc->ClearCondition();
        return 0;
    }
    RexxArrayObject none = tc->NewArray(0);
    RexxObjectPtr v = tc->CallRoutine(r, none);
    int ok = !tc->CheckCondition() && v != NULLOBJECT && strcmp(tc->ObjectToStringValue(v), "hi") == 0;
    if (tc->CheckCondition() && getenv("VERBOSE"))
    {
        RexxCondition c;
        tc->DecodeConditionInfo(tc->GetConditionInfo(), &c);
        printf("  condition %zd.%zd: %s\n", (ssize_t)c.rc, (ssize_t)(c.code % 1000), c.message ? tc->CString(c.message) : "");
    }
    tc->ClearCondition();
    if (v != NULLOBJECT) tc->ReleaseLocalReference(v);
    tc->ReleaseLocalReference(none);
    tc->ReleaseLocalReference(r);
    return ok;
}
int main()
{
    RexxInstance *a; RexxThreadContext *ta;
    if (!RexxCreateInterpreter(&a, &ta, NULL)) { puts("BUG: no interpreter"); return 1; }
    const char *pkg = "::class Thing public\n::method hi; return 'hi'\n";
    RexxPackageObject p = ta->LoadPackageFromData("x.cls", pkg, strlen(pkg));
    if (p == NULLOBJECT) { puts("BUG: LoadPackageFromData failed"); return 1; }
    ta->ReleaseLocalReference(p);                 // the caller keeps no reference
    int before = requiresWorks(ta);
    // garbage enough for a collection (any collection does it; in the bridge
    // it was another instance's Terminate, after loading more packages)
    const char *g = getenv("NOGARBAGE") ? "nop\n" : "do i = 1 to 20000; x = .array~new(100)~fill(copies('x', 100)); end\n";
    RexxRoutineObject gr = ta->NewRoutine("g", g, strlen(g));
    RexxArrayObject none = ta->NewArray(0);
    ta->ReleaseLocalReference(ta->CallRoutine(gr, none));
    ta->ReleaseLocalReference(none);
    ta->ReleaseLocalReference(gr);
    int after = requiresWorks(ta);
    if (before && after) puts("FIXED");
    else if (!before) puts("BUG: ::requires of a package from data fails at once");
    else puts("BUG: ::requires of a package from data fails after a garbage collection (43.901)");
    a->Terminate();
    return 0;
}
