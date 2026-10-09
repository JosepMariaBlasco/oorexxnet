// netprobe: an ooRexx external library that hosts the .NET runtime (CLR)
// with nethost/hostfxr and calls static .NET methods by reflection.
//   ::routine NetStatic external "LIBRARY netprobe NetStatic"
//   say NetStatic("System.Math", "Max", 3, 7)
#include <oorexxapi.h>
#include <nethost.h>
#include <hostfxr.h>
#include <coreclr_delegates.h>
#include <dlfcn.h>
#include <string>
#include <mutex>

typedef int (CORECLR_DELEGATE_CALLTYPE *call_static_fn)(const char *, const char *, const char *, char *, int);
static call_static_fn callStatic = nullptr;
static std::string loadError;
static std::once_flag once;

static void loadClr()
{
    char path[4096]; size_t size = sizeof(path);
    if (get_hostfxr_path(path, &size, nullptr) != 0) { loadError = "no .NET runtime found (get_hostfxr_path)"; return; }
    void *lib = dlopen(path, RTLD_LAZY | RTLD_LOCAL);
    if (!lib) { loadError = std::string("cannot load ") + path; return; }
    auto init = (hostfxr_initialize_for_runtime_config_fn)dlsym(lib, "hostfxr_initialize_for_runtime_config");
    auto getDelegate = (hostfxr_get_runtime_delegate_fn)dlsym(lib, "hostfxr_get_runtime_delegate");
    auto closeFxr = (hostfxr_close_fn)dlsym(lib, "hostfxr_close");
    const char *dir = getenv("NETPROBE_DIR");          // where Probe.dll and its runtimeconfig are
    std::string base = dir ? dir : ".";
    std::string config = base + "/Probe.runtimeconfig.json", assembly = base + "/Probe.dll";
    hostfxr_handle cx = nullptr;
    if (init(config.c_str(), nullptr, &cx) != 0 || !cx) { loadError = "hostfxr_initialize_for_runtime_config failed: " + config; return; }
    load_assembly_and_get_function_pointer_fn load = nullptr;
    if (getDelegate(cx, hdt_load_assembly_and_get_function_pointer, (void **)&load) != 0 || !load)
    { loadError = "hostfxr_get_runtime_delegate failed"; closeFxr(cx); return; }
    closeFxr(cx);
    if (load(assembly.c_str(), "Probe.Entry, Probe", "CallStatic", UNMANAGEDCALLERSONLY_METHOD, nullptr, (void **)&callStatic) != 0)
    { loadError = "load_assembly_and_get_function_pointer failed: " + assembly; callStatic = nullptr; }
}

RexxRoutine3(RexxObjectPtr, NetStatic, CSTRING, typeName, CSTRING, method, ARGLIST, args)
{
    std::call_once(once, loadClr);
    if (!callStatic) { context->RaiseException1(Rexx_Error_Execution_user_defined, context->String(loadError.c_str())); return NULLOBJECT; }
    std::string joined;
    size_t n = context->ArraySize(args);
    for (size_t i = 3; i <= n; i++)
    {
        RexxObjectPtr a = context->ArrayAt(args, i);
        if (i > 3) joined += '\t';
        if (a != NULLOBJECT) joined += context->ObjectToStringValue(a);
    }
    char out[4096];
    int len = callStatic(typeName, method, joined.c_str(), out, (int)sizeof(out));
    if (len < 0) { context->RaiseException1(Rexx_Error_Execution_user_defined, context->String((std::string(".NET: ") + out).c_str())); return NULLOBJECT; }
    return context->String(out, (size_t)len);
}

RexxRoutineEntry netprobe_routines[] = { REXX_TYPED_ROUTINE(NetStatic, NetStatic), REXX_LAST_ROUTINE() };
RexxPackageEntry netprobe_package_entry = { STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0, "netprobe", "0.1", nullptr, nullptr, netprobe_routines, nullptr };
OOREXX_GET_PACKAGE(netprobe);
