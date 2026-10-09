// Reproducer: entering the interpreter is slow on Linux's main thread.
//
// Times CallRoutine and RexxStart on the process's main thread and on a
// second thread, after lengthening /proc/self/maps with N separate mappings
// (default 3000; a .NET or JVM process has thousands).
//
//   g++ -O2 -I/usr/local/include stackbase-repro.cpp -L/usr/local/lib -lrexx -lpthread -o stackbase-repro
//   ./stackbase-repro [N]
//
// Before the fix, the main thread's figures grow with N (/proc/self/maps is
// read on every call: `strace -e trace=openat ./stackbase-repro` shows it);
// after it, both threads are alike.
#include <oorexxapi.h>
#include <rexx.h>
#include <sys/mman.h>
#include <unistd.h>
#include <pthread.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>

static double now() { timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e6 + t.tv_nsec / 1e3; }

static double callRoutine()                  // µs per CallRoutine
{
    RexxInstance *in; RexxThreadContext *tc;
    if (!RexxCreateInterpreter(&in, &tc, NULL)) return -1;
    RexxRoutineObject r = tc->NewRoutine("r", "return 1", 8);
    RexxArrayObject a = tc->NewArray(0);
    for (int i = 0; i < 50; i++) tc->ReleaseLocalReference(tc->CallRoutine(r, a));
    const int n = 500;
    double t0 = now();
    for (int i = 0; i < n; i++) tc->ReleaseLocalReference(tc->CallRoutine(r, a));
    double t = (now() - t0) / n;
    in->Terminate();
    return t;
}

static double rexxStart()                    // µs per RexxStart of an instore "return 1"
{
    RXSTRING instore[2] = { { 8, (char *)"return 1" }, { 0, NULL } };
    RXSTRING result; char buf[32]; short rc;
    const int n = 200;
    double t0 = 0;
    for (int i = -20; i < n; i++)
    {
        if (i == 0) t0 = now();
        result.strptr = buf; result.strlength = sizeof buf;
        instore[1].strptr = NULL; instore[1].strlength = 0;
        RexxStart(0, NULL, "repro", instore, NULL, RXCOMMAND, NULL, &rc, &result);
    }
    return (now() - t0) / n;
}

struct Times { double call, start; };
static void *other(void *p) { Times *t = (Times *)p; t->call = callRoutine(); t->start = rexxStart(); return NULL; }

int main(int argc, char **argv)
{
    int maps = argc > 1 ? atoi(argv[1]) : 3000;
    long pg = sysconf(_SC_PAGESIZE);
    char *m = (char *)mmap(NULL, 2 * (size_t)maps * pg + pg, PROT_READ, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    for (int i = 0; i < 2 * maps; i += 2) mprotect(m + (size_t)i * pg, pg, PROT_NONE);   // separate mappings

    Times main_t = { callRoutine(), rexxStart() }, other_t = { 0, 0 };
    pthread_t t; pthread_create(&t, NULL, other, &other_t); pthread_join(t, NULL);
    printf("%d extra mappings\n", maps);
    printf("  CallRoutine: main thread %9.1f us, other thread %9.1f us\n", main_t.call, other_t.call);
    printf("  RexxStart:   main thread %9.1f us, other thread %9.1f us\n", main_t.start, other_t.start);
    return 0;
}
