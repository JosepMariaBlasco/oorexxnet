// cbprobe: the native side of the callbacks probe (08/10/2026).
// Hosts the CLR as netprobe does, hands the managed side a callback that
// enters Rexx through AttachThread (from any thread) and sends CALLBACK to a
// registered Rexx object, and exposes the managed probes as Rexx routines.
#include <oorexxapi.h>
#include <nethost.h>
#include <hostfxr.h>
#include <coreclr_delegates.h>
#include <dlfcn.h>
#include <cstring>
#include <string>

typedef int (CORECLR_DELEGATE_CALLTYPE *block_fn)(int, int, char *, int);
typedef int (CORECLR_DELEGATE_CALLTYPE *sort_fn)(const char *, char *, int);
typedef int (CORECLR_DELEGATE_CALLTYPE *start_fn)(int, int);
typedef int (CORECLR_DELEGATE_CALLTYPE *done_fn)();
typedef int (CORECLR_DELEGATE_CALLTYPE *fail_fn)(char *, int);
typedef void (CORECLR_DELEGATE_CALLTYPE *init_fn)(void *);

static block_fn mBlock; static sort_fn mSort; static start_fn mStart;
static done_fn mDone; static fail_fn mFail;
static RexxInstance *instance;          // the interpreter instance, for AttachThread
static RexxObjectPtr target;            // the registered object (a global reference)
static std::string loadError;

// Called by .NET, on any thread: target~callback(arg).
static int rexxCallback(const char *arg, char *out, int outLen)
{
    RexxThreadContext *tc;
    if (!instance->AttachThread(&tc)) { strncpy(out, "AttachThread failed", outLen); return -1; }
    RexxObjectPtr r = tc->SendMessage1(target, "CALLBACK", tc->String(arg));
    int n;
    if (tc->CheckCondition())
    {
        RexxCondition c;
        tc->DecodeConditionInfo(tc->GetConditionInfo(), &c);
        std::string msg = std::to_string(c.rc) + ": " +
            (c.message != NULLOBJECT ? tc->CString(c.message) : tc->CString(c.errortext));
        tc->ClearCondition();
        snprintf(out, outLen, "%s", msg.c_str());
        n = -1;
    }
    else
    {
        const char *s = r != NULLOBJECT ? tc->ObjectToStringValue(r) : "";
        n = (int)strlen(s); if (n > outLen - 1) n = outLen - 1;
        memcpy(out, s, n); out[n] = 0;
    }
    tc->DetachThread();
    return n;
}

static bool loadClr()
{
    char path[4096]; size_t size = sizeof(path);
    if (get_hostfxr_path(path, &size, nullptr) != 0) { loadError = "no .NET runtime"; return false; }
    void *lib = dlopen(path, RTLD_LAZY | RTLD_LOCAL);
    auto init = (hostfxr_initialize_for_runtime_config_fn)dlsym(lib, "hostfxr_initialize_for_runtime_config");
    auto getDelegate = (hostfxr_get_runtime_delegate_fn)dlsym(lib, "hostfxr_get_runtime_delegate");
    auto closeFxr = (hostfxr_close_fn)dlsym(lib, "hostfxr_close");
    const char *dir = getenv("CBPROBE_DIR");
    std::string base = dir ? dir : ".";
    std::string config = base + "/CbProbe.runtimeconfig.json", assembly = base + "/CbProbe.dll";
    hostfxr_handle cx = nullptr;
    if (init(config.c_str(), nullptr, &cx) != 0 || !cx) { loadError = "hostfxr init failed"; return false; }
    load_assembly_and_get_function_pointer_fn load = nullptr;
    getDelegate(cx, hdt_load_assembly_and_get_function_pointer, (void **)&load);
    closeFxr(cx);
    const char *T = "CbProbe.Callbacks, CbProbe";
    init_fn mInit = nullptr;
    #define GET(name, var) if (load(assembly.c_str(), T, name, UNMANAGEDCALLERSONLY_METHOD, nullptr, (void **)&var) != 0) { loadError = std::string("cannot get ") + name; return false; }
    GET("Init", mInit) GET("Block", mBlock) GET("Sort", mSort) GET("StartAsync", mStart)
    GET("AsyncDone", mDone) GET("Fail", mFail)
    mInit((void *)rexxCallback);
    return true;
}

static RexxObjectPtr answer(RexxCallContext *context, int n, const char *out)
{
    if (n < 0) { context->RaiseException1(Rexx_Error_Execution_user_defined, context->String(out)); return NULLOBJECT; }
    return context->String(out, (size_t)n);
}

// CbInit(object): load the CLR and register the object that gets CALLBACK.
RexxRoutine1(RexxObjectPtr, CbInit, RexxObjectPtr, obj)
{
    instance = context->threadContext->instance;
    target = context->RequestGlobalReference(obj);
    if (!loadClr()) { context->RaiseException1(Rexx_Error_Execution_user_defined, context->String(loadError.c_str())); return NULLOBJECT; }
    return context->True();
}

RexxRoutine2(RexxObjectPtr, CbBlock, int, ms, int, count)
{ char out[4096]; return answer(context, mBlock(ms, count, out, sizeof(out)), out); }

RexxRoutine1(RexxObjectPtr, CbSort, CSTRING, words)
{ char out[4096]; return answer(context, mSort(words, out, sizeof(out)), out); }

RexxRoutine2(int, CbStartAsync, int, count, int, ms) { return mStart(count, ms); }
RexxRoutine0(int, CbAsyncDone) { return mDone(); }

RexxRoutine0(RexxObjectPtr, CbFail)
{ char out[4096]; return answer(context, mFail(out, sizeof(out)), out); }

RexxRoutineEntry cbprobe_routines[] = {
    REXX_TYPED_ROUTINE(CbInit, CbInit), REXX_TYPED_ROUTINE(CbBlock, CbBlock),
    REXX_TYPED_ROUTINE(CbSort, CbSort), REXX_TYPED_ROUTINE(CbStartAsync, CbStartAsync),
    REXX_TYPED_ROUTINE(CbAsyncDone, CbAsyncDone), REXX_TYPED_ROUTINE(CbFail, CbFail),
    REXX_LAST_ROUTINE() };
RexxPackageEntry cbprobe_package_entry = { STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0, "cbprobe", "0.1", nullptr, nullptr, cbprobe_routines, nullptr };
OOREXX_GET_PACKAGE(cbprobe);
