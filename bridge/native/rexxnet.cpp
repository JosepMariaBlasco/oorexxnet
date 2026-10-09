// rexxnet: the native half of ooRexx/.NET (notes/netobject-design.md).
//
// An ooRexx external library that hosts the .NET runtime (nethost / hostfxr)
// on first use and talks to the managed half (Rexx.Net.dll, next to this
// library) through one entry point, Bridge.Request: a request of records in,
// one record out (managed/Wire.cs). This side only knows references (handle
// ids) and Rexx values; everything .NET lives on the managed side.
//
// Rexx entry points (net.cls):
//   NetObject~unknown   -> send / set
//   NetObject~uninit    -> release of the handle
//   NetRequest(op, args...)   any other operation, from net.cls's helpers
//   NetHandlerNew / NetHandlerOf / NetHandlerDrop   .NetHandler ids
//
// Callbacks (phase 3): a .NetHandler goes to .NET as a record H; the managed
// side makes it a delegate, which calls rexxCallback (handed over at start,
// Bridge.Init) on whatever thread .NET calls it. rexxCallback attaches the
// thread to the interpreter (AttachThread nests on a Rexx thread already
// inside .NET), sends the handler's message and answers the result. A Rexx
// condition goes back as E and is kept here: if it comes back out of .NET
// (C), it is raised again as it was.
//
// Both ways in one process (phase C): every request carries the calling
// thread's context, so .NET code called from here calls Rexx back nested on
// this thread (RexxInterpreter.Current); any other Rexx object goes as X (its
// pointer: a RexxObject in .NET) and comes back as X; in a callback's result
// as G (a global reference handed over: the thread detaches before .NET reads
// it); K: a condition the managed side already raised on this context. A
// handler keeps the instance that made it (a .NET host may have several).
#include <oorexxapi.h>
#include <nethost.h>
#include <hostfxr.h>
#include <coreclr_delegates.h>
#include <string>
#include <vector>
#include <mutex>
#include <cstring>
#include <cstdlib>
#include <cstdint>
#include <map>
#include <deque>
#include <atomic>

#ifdef _WIN32
#include <windows.h>
#include <objbase.h>
#define LIBHANDLE HMODULE
static LIBHANDLE openLib(const char_t *p) { return LoadLibraryW(p); }
static void *libSym(LIBHANDLE h, const char *n) { return (void *)GetProcAddress(h, n); }
static std::basic_string<char_t> thisDir()
{
    HMODULE self = nullptr;
    GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                       (LPCWSTR)&thisDir, &self);
    wchar_t buf[MAX_PATH]; GetModuleFileNameW(self, buf, MAX_PATH);
    std::wstring p(buf); return p.substr(0, p.find_last_of(L"\\/"));
}
static bool fileExists(const std::wstring &p) { return GetFileAttributesW(p.c_str()) != INVALID_FILE_ATTRIBUTES; }
// Every Rexx thread, at its first request to .NET (and before the runtime
// starts, for the thread that starts it: the runtime would make it MTA): a
// single-threaded apartment, unless REXXNET_APARTMENT=MTA or COM is already
// initialized on it (CoInitializeEx then changes nothing). Not left to the
// managed side: there a thread with no COM yet already reads as MTA (the
// process's implicit MTA). notes/netobject-design.md, "Windows".
static void rexxThreadApartment()
{
    char v[8] = "";
    DWORD n = GetEnvironmentVariableA("REXXNET_APARTMENT", v, sizeof v);
    if (n > 0 && n < sizeof v && _stricmp(v, "MTA") == 0) return;
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
}
#define STR(s) L##s
#else
#include <dlfcn.h>
#include <unistd.h>
#define LIBHANDLE void *
static LIBHANDLE openLib(const char_t *p) { return dlopen(p, RTLD_LAZY | RTLD_LOCAL); }
static void *libSym(LIBHANDLE h, const char *n) { return dlsym(h, n); }
static std::string thisDir()
{
    Dl_info info;
    if (dladdr((void *)&thisDir, &info) && info.dli_fname)
    {
        // absolute: dli_fname is relative when found through a relative
        // LD_LIBRARY_PATH (".": "./librexxnet.so"), and hdt_load_assembly
        // wants an absolute path
        char *real = realpath(info.dli_fname, nullptr);
        std::string p(real ? real : info.dli_fname);
        free(real);
        size_t slash = p.find_last_of('/');
        return slash == std::string::npos ? "." : p.substr(0, slash);
    }
    return ".";
}
static bool fileExists(const std::string &p) { return access(p.c_str(), F_OK) == 0; }
static void rexxThreadApartment() {}
#define STR(s) s
#endif

typedef unsigned char *(CORECLR_DELEGATE_CALLTYPE *request_fn)(RexxThreadContext *, const unsigned char *, int, int *);
typedef void (CORECLR_DELEGATE_CALLTYPE *free_fn)(unsigned char *);
typedef void (CORECLR_DELEGATE_CALLTYPE *release_fn)(int);
typedef void (CORECLR_DELEGATE_CALLTYPE *init_fn)(void *, void *);
typedef void (CORECLR_DELEGATE_CALLTYPE *classes_fn)(RexxObjectPtr, RexxObjectPtr, RexxObjectPtr, RexxObjectPtr);

static request_fn mRequest;
static free_fn mFree;
static release_fn mRelease;
static classes_fn mClasses;
static std::string loadError;
static std::once_flag clrOnce;
static RexxInstance *instance;          // for AttachThread (set on the first request; a handler keeps its own)

static unsigned char *rexxCallback(int handler, int flags, const unsigned char *req, int len, int *outLen);
static void nativeFree(unsigned char *p) { free(p); }

static void loadClr()
{
    char_t path[4096]; size_t size = sizeof(path) / sizeof(char_t);
    if (get_hostfxr_path(path, &size, nullptr) != 0)
    { loadError = "no .NET runtime found (.NET 8 or later is needed)"; return; }
    LIBHANDLE lib = openLib(path);
    if (!lib) { loadError = "cannot load the .NET host (hostfxr)"; return; }
    auto init = (hostfxr_initialize_for_runtime_config_fn)libSym(lib, "hostfxr_initialize_for_runtime_config");
    auto getDelegate = (hostfxr_get_runtime_delegate_fn)libSym(lib, "hostfxr_get_runtime_delegate");
    auto closeFxr = (hostfxr_close_fn)libSym(lib, "hostfxr_close");
    auto setErrorWriter = (hostfxr_set_error_writer_fn)libSym(lib, "hostfxr_set_error_writer");
    auto dir = thisDir();
    auto config = dir + STR("/Rexx.Net.runtimeconfig.json"), assembly = dir + STR("/Rexx.Net.dll");
    // Rexx.Net.core.runtimeconfig.json (build.ps1, on Windows: the config
    // without the Windows Desktop framework): the one to use when .NET is
    // already running without that framework (a .NET application hosting
    // ooRexx, phase C), with which the full config is incompatible; the first
    // attempt's complaint is then silenced
    auto core = dir + STR("/Rexx.Net.core.runtimeconfig.json");
    bool haveCore = fileExists(core);
    rexxThreadApartment();
    hostfxr_handle cx = nullptr;
    if (haveCore && setErrorWriter) setErrorWriter([](const char_t *) {});
    int rc = init(config.c_str(), nullptr, &cx);
    if (haveCore && setErrorWriter) setErrorWriter(nullptr);
    if ((rc < 0 || !cx) && haveCore) { cx = nullptr; rc = init(core.c_str(), nullptr, &cx); }
    if (rc < 0 || !cx) { loadError = "cannot start the .NET runtime (Rexx.Net.runtimeconfig.json next to rexxnet?)"; return; }
    // Rexx.Net goes to the default load context (hdt_load_assembly, .NET 8),
    // not to an isolated one (hdt_load_assembly_and_get_function_pointer):
    // so .net~load'ed assemblies and the application's own see the same
    // types, and in a .NET application that already uses Rexx.Net (hosting
    // ooRexx) the bridge is that same assembly, with one handle table.
    // First the assembly as the runtime finds it (the application's), else
    // the one next to this library.
    load_assembly_fn loadAssembly = nullptr;
    get_function_pointer_fn getFunction = nullptr;
    rc = getDelegate(cx, hdt_load_assembly, (void **)&loadAssembly);
    if (rc == 0) rc = getDelegate(cx, hdt_get_function_pointer, (void **)&getFunction);
    closeFxr(cx);
    if (rc != 0 || !loadAssembly || !getFunction) { loadError = "cannot get the .NET runtime's loader (.NET 8 or later is needed)"; return; }
    const char_t *T = STR("Rexx.Net.Bridge, Rexx.Net");
    init_fn mInit = nullptr;
    auto getAll = [&] {
        return getFunction(T, STR("Request"), UNMANAGEDCALLERSONLY_METHOD, nullptr, nullptr, (void **)&mRequest) == 0 &&
               getFunction(T, STR("Free"), UNMANAGEDCALLERSONLY_METHOD, nullptr, nullptr, (void **)&mFree) == 0 &&
               getFunction(T, STR("Release"), UNMANAGEDCALLERSONLY_METHOD, nullptr, nullptr, (void **)&mRelease) == 0 &&
               getFunction(T, STR("Init"), UNMANAGEDCALLERSONLY_METHOD, nullptr, nullptr, (void **)&mInit) == 0 &&
               getFunction(T, STR("Classes"), UNMANAGEDCALLERSONLY_METHOD, nullptr, nullptr, (void **)&mClasses) == 0;
    };
    if (!getAll() && (loadAssembly(assembly.c_str(), nullptr, nullptr) != 0 || !getAll()))
    { loadError = "cannot load Rexx.Net.dll (next to rexxnet?)"; mRequest = nullptr; return; }
    mInit((void *)rexxCallback, (void *)nativeFree);
}

// Host mode (a .NET application hosting ooRexx through Rexx.Net): the managed
// side, already running, hands its entry points over before any Rexx code
// uses .net, so the runtime is not looked for through hostfxr (no
// runtimeconfig next to this library needed: in a NuGet package it lives in
// runtimes/<rid>/native/). If the runtime was started here first, nothing
// changes (it is the same runtime).
#ifdef _WIN32
#define REXXNET_EXPORT extern "C" __declspec(dllexport)
#else
#define REXXNET_EXPORT extern "C" __attribute__((visibility("default")))
#endif
REXXNET_EXPORT void RexxNetRegister(void *request, void *freeFn, void *release, void *init, void *classes)
{
    std::call_once(clrOnce, [=] {
        mRequest = (request_fn)request; mFree = (free_fn)freeFn; mRelease = (release_fn)release;
        mClasses = (classes_fn)classes;
        ((init_fn)init)((void *)rexxCallback, (void *)nativeFree);
    });
}

// ---------------------------------------------------------------- the classes

// net.cls's classes, found once from a context inside net.cls.
struct Classes { RexxClassObject netObject, netType, netArray, netEnum, netNamespace, netTyped, netRef, netHandler, netEvent, string; };
static Classes cls;
static std::once_flag clsOnce;

template <class Ctx> static void findClasses(Ctx *c)
{
    std::call_once(clsOnce, [c] {
        auto find = [c](const char *n) { return (RexxClassObject)c->RequestGlobalReference(c->FindContextClass(n)); };
        cls.netObject = find("NETOBJECT"); cls.netType = find("NETTYPE"); cls.netArray = find("NETARRAY"); cls.netEnum = find("NETENUM");
        cls.netNamespace = find("NETNAMESPACE"); cls.netTyped = find("NETTYPED"); cls.netRef = find("NETREF");
        cls.netHandler = find("NETHANDLER"); cls.netEvent = find("NETEVENT");
        cls.string = find("STRING");
    });
}

// ------------------------------------------------------------------ handlers

// The .NetHandlers that have gone to .NET, by id: kept (global references)
// until handler~release.
struct Handler { RexxObjectPtr handler, target; std::string message; RexxInstance *inst; };
static std::mutex tablesLock;
static std::map<int, Handler> handlers;
static std::atomic<int> nextHandler{1};

static void registerHandler(RexxThreadContext *c, int id, RexxObjectPtr h)
{
    {
        std::lock_guard<std::mutex> g(tablesLock);
        if (handlers.count(id)) return;
    }
    RexxObjectPtr target = c->SendMessage0(h, "TARGET");
    std::string message = c->ObjectToStringValue(c->SendMessage0(h, "MESSAGE"));
    Handler e{c->RequestGlobalReference(h), c->RequestGlobalReference(target), message, c->instance};
    std::lock_guard<std::mutex> g(tablesLock);
    if (!handlers.emplace(id, e).second) { c->ReleaseGlobalReference(e.handler); c->ReleaseGlobalReference(e.target); }
}

// Rexx conditions that ended a callback, kept so that if they come back out
// of .NET they are raised again as they were. The last few only: .NET may
// swallow the exception, and then nobody asks for it.
struct Condition { int id; std::string name; wholenumber_t code; RexxObjectPtr additional, description; };
static std::deque<Condition> conditions;
static int nextCondition = 1;
const size_t keptConditions = 32;

// -------------------------------------------------------------------- records

static void record(std::string &out, char tag, const std::string &payload)
{
    out += tag; out += std::to_string(payload.size()); out += ':'; out += payload;
}

// A Rexx value as a request record; false (and a condition raised) if it
// cannot go to .NET. The .NetRefs met are collected in refs (if given), in
// order, to receive their new values (a response R).
typedef std::vector<RexxObjectPtr> Refs;
// adopt: for a callback's result, read by .NET after this thread detaches: a
// Rexx object goes with a global reference that the managed side takes over
// (G "pointer\tinstance") instead of a plain pointer (X).
static bool encode(RexxThreadContext *c, RexxObjectPtr o, std::string &out, Refs *refs = nullptr, bool adopt = false)
{
    if (o == NULLOBJECT || o == c->Nil()) { record(out, 'N', ""); return true; }
    if (c->IsInstanceOf(o, cls.netObject))
    {
        record(out, 'O', c->ObjectToStringValue(c->SendMessage0(o, "NETID")));
        return true;
    }
    if (c->IsInstanceOf(o, cls.netRef))
    {
        std::string inner;
        if (!encode(c, c->SendMessage0(o, "VALUE"), inner)) return false;
        record(out, 'R', inner);
        if (refs) refs->push_back(o);
        return true;
    }
    if (c->IsInstanceOf(o, cls.netHandler))
    {
        int id = atoi(c->ObjectToStringValue(c->SendMessage0(o, "ID")));
        std::string options = c->ObjectToStringValue(c->SendMessage0(o, "OPTIONS"));
        if (c->SendMessage0(o, "RELEASED") == c->True()) options += " released";   // still its delegate, for -=
        else registerHandler(c, id, o);
        record(out, 'H', std::to_string(id) + '\t' + options);
        return true;
    }
    if (c->IsInstanceOf(o, cls.netTyped))
    {
        std::string inner = c->ObjectToStringValue(c->SendMessage0(o, "KIND"));
        inner += '\t';
        if (!encode(c, c->SendMessage0(o, "VALUE"), inner)) return false;
        record(out, 'T', inner);
        return true;
    }
    if (c->IsArray(o))
    {
        RexxArrayObject a = (RexxArrayObject)o;
        std::string items;
        size_t n = c->ArrayItems(a), last = c->ArraySize(a);
        if (n != last)
        {
            c->RaiseException1(Rexx_Error_Execution_user_defined,
                c->String("an Array with omitted items cannot go to .NET"));
            return false;
        }
        for (size_t i = 1; i <= last; i++) if (!encode(c, c->ArrayAt(a, i), items, refs, adopt)) return false;
        record(out, 'A', items);
        return true;
    }
    if (c->IsInstanceOf(o, cls.string))
    {
        size_t len = c->StringLength((RexxStringObject)c->ObjectToString(o));
        record(out, 'S', std::string(c->ObjectToStringValue(o), len));
        return true;
    }
    // Any other Rexx object: by reference (a RexxObject in .NET). Its pointer
    // is valid while the request runs: the caller's arguments hold it, and
    // the managed side takes its own global reference to keep it.
    if (adopt)
        record(out, 'G', std::to_string((uintptr_t)c->RequestGlobalReference(o)) + '\t' + std::to_string((uintptr_t)c->instance));
    else record(out, 'X', std::to_string((uintptr_t)o));
    return true;
}

static size_t parseRecord(const unsigned char *p, size_t len, size_t at, char &tag, std::string &payload)
{
    tag = (char)p[at++];
    size_t n = 0;
    while (at < len && p[at] != ':') n = n * 10 + (p[at++] - '0');
    at++;
    payload.assign((const char *)p + at, n);
    return at + n;
}

static std::string field(const std::string &s, int index)        // the index-th tab-separated field
{
    size_t start = 0;
    for (int i = 0; i < index; i++) { start = s.find('\t', start); if (start == std::string::npos) return ""; start++; }
    size_t end = s.find('\t', start);
    return s.substr(start, end == std::string::npos ? std::string::npos : end - start);
}

// The proxy class for a kind: "t" a type, "a" an array, "e" an enum value, "o" any other object.
static RexxClassObject proxyClass(const std::string &kind)
{
    return kind == "t" ? cls.netType : kind == "a" ? cls.netArray : kind == "e" ? cls.netEnum : cls.netObject;
}

static RexxObjectPtr newProxy(RexxThreadContext *c, RexxClassObject k, const std::string &id, const std::string &display)
{
    return c->SendMessage2(k, "NEW", c->String(id.c_str()), c->String(display.c_str()));
}

// The receiver of the message being answered, for a 97.1 (decode 'U'): set
// once the managed side has answered, so nested requests cannot change it.
static thread_local RexxObjectPtr answering = NULLOBJECT;

// A response record as a Rexx value. NULLOBJECT: no value (void), or an error
// (then a condition is pending: c->CheckCondition()).
static RexxObjectPtr decode(RexxThreadContext *c, char tag, const std::string &payload)
{
    switch (tag)
    {
        case 'S': return c->String(payload.data(), payload.size());
        case 'N': return c->Nil();
        case 'V': return NULLOBJECT;
        case 'P': return c->SendMessage1(cls.netNamespace, "NEW", c->String(payload.c_str()));
        case 'O':
            return newProxy(c, proxyClass(field(payload, 1)), field(payload, 0), field(payload, 2));
        case 'A':
        {
            RexxArrayObject a = c->NewArray(0);
            const unsigned char *p = (const unsigned char *)payload.data();
            for (size_t at = 0; at < payload.size();)
            {
                char t; std::string pl;
                at = parseRecord(p, payload.size(), at, t, pl);
                c->ArrayAppend(a, decode(c, t, pl));
            }
            return a;
        }
        case 'X':                                   // a Rexx object coming back (held for us by the managed side)
            return (RexxObjectPtr)(uintptr_t)strtoull(payload.c_str(), nullptr, 10);
        case 'K':                                   // a condition already raised by the managed side
            return NULLOBJECT;
        case 'e':                                   // a .NetEvent: its owner and name
        {
            RexxObjectPtr owner = newProxy(c, proxyClass(field(payload, 1)), field(payload, 0), field(payload, 2));
            return c->SendMessage2(cls.netEvent, "NEW", owner, c->String(field(payload, 3).c_str()));
        }
        case 'C':                                   // a Rexx condition from a callback, raised again
        {
            int id = atoi(field(payload, 0).c_str());
            Condition k{0, "", 0, NULLOBJECT, NULLOBJECT};
            {
                std::lock_guard<std::mutex> g(tablesLock);
                for (auto it = conditions.begin(); it != conditions.end(); ++it)
                    if (it->id == id) { k = *it; conditions.erase(it); break; }
            }
            if (k.id == 0)
            {
                c->RaiseException1(Rexx_Error_Execution_user_defined, c->String(payload.substr(payload.find('\t') + 1).c_str()));
                return NULLOBJECT;
            }
            if (k.name == "SYNTAX") c->RaiseException(k.code, (RexxArrayObject)k.additional);
            else c->RaiseCondition(k.name.c_str(), k.description ? (RexxStringObject)k.description : NULLOBJECT, k.additional, NULLOBJECT);
            if (k.additional) c->ReleaseGlobalReference(k.additional);
            if (k.description) c->ReleaseGlobalReference(k.description);
            return NULLOBJECT;
        }
        case 'U':                                   // no such member: 97.1, the receiver, the name, the exception
        {
            std::string name = payload.substr(payload.find('\t', payload.find('\t') + 1) + 1);
            RexxArrayObject info = c->NewArray(3);
            c->ArrayPut(info, answering ? answering : c->Nil(), 1);
            c->ArrayPut(info, c->String(name.c_str()), 2);
            c->ArrayPut(info, newProxy(c, cls.netObject, field(payload, 0), field(payload, 1)), 3);
            c->RaiseException(Rexx_Error_No_method_name, info);
            return NULLOBJECT;
        }
        case 'Y':                                   // one of Rexx's own errors: code, substitutions
        {
            std::vector<std::string> f;
            for (size_t at = 0;;)
            {
                size_t end = payload.find('\t', at);
                f.push_back(payload.substr(at, end == std::string::npos ? std::string::npos : end - at));
                if (end == std::string::npos) break;
                at = end + 1;
            }
            RexxArrayObject subs = c->NewArray(f.size() - 1);
            for (size_t k = 1; k < f.size(); k++) c->ArrayPut(subs, c->String(f[k].c_str()), k);
            c->RaiseException((size_t)strtoul(f[0].c_str(), nullptr, 10), subs);
            return NULLOBJECT;
        }
        case 'E':
        {
            std::string id = field(payload, 0), message = payload.substr(payload.find('\t', payload.find('\t') + 1) + 1);
            if (!message.empty() && message.back() == '.') message.pop_back();   // 98.900 adds its own
            RexxArrayObject info = c->NewArray(2);
            c->ArrayPut(info, c->String(message.c_str()), 1);
            if (id != "0") c->ArrayPut(info, newProxy(c, cls.netObject, id, field(payload, 1)), 2);
            c->RaiseException(Rexx_Error_Execution_user_defined, info);
            return NULLOBJECT;
        }
    }
    c->RaiseException1(Rexx_Error_Execution_user_defined, c->String("rexxnet: bad response"));
    return NULLOBJECT;
}

// Sends a request to the managed side and decodes the response. A response
// R (a call with .NetRef arguments) is the result, then the refs' new values.
static RexxObjectPtr request(RexxThreadContext *c, const std::string &req, const Refs *refs = nullptr,
                             RexxObjectPtr receiver = NULLOBJECT)
{
    if (!instance) instance = c->instance;
    static thread_local bool entered = false;
    if (!entered) { entered = true; rexxThreadApartment(); }
    std::call_once(clrOnce, loadClr);
    if (!mRequest)
    {
        c->RaiseException1(Rexx_Error_Execution_user_defined, c->String((".NET: " + loadError).c_str()));
        return NULLOBJECT;
    }
    static std::once_flag classesOnce;           // net.cls's classes, for the managed side (.NetObjects in RexxObject's world)
    if (cls.netObject) std::call_once(classesOnce, [] { mClasses(cls.netObject, cls.netType, cls.netArray, cls.netEnum); });
    int len = 0;
    // The thread context goes with the request: .NET code called from here
    // calls Rexx back on this thread, nested (RexxInterpreter.Current).
    unsigned char *resp = mRequest(c, (const unsigned char *)req.data(), (int)req.size(), &len);
    answering = receiver;
    char tag; std::string payload;
    parseRecord(resp, (size_t)len, 0, tag, payload);
    mFree(resp);
    if (tag != 'R') return decode(c, tag, payload);
    const unsigned char *p = (const unsigned char *)payload.data();
    std::string first;
    size_t at = parseRecord(p, payload.size(), 0, tag, first);
    RexxObjectPtr result = decode(c, tag, first);
    for (size_t k = 0; at < payload.size() && refs && k < refs->size(); k++)
    {
        std::string v;
        at = parseRecord(p, payload.size(), at, tag, v);
        RexxObjectPtr value = decode(c, tag, v);
        c->SendMessage1((*refs)[k], "VALUE=", value ? value : c->Nil());
    }
    return result;
}

// -------------------------------------------------------------- Rexx methods

// NetObject~unknown(name, args): o~name, o~name(args), o~name = v.
RexxMethod2(RexxObjectPtr, net_unknown, CSTRING, name, RexxArrayObject, args)
{
    findClasses(context);
    RexxThreadContext *c = context->threadContext;
    std::string id = context->ObjectToStringValue(context->GetObjectVariable("NETID"));
    std::string req, n(name);
    record(req, 'O', id);
    if (!n.empty() && n.back() == '=')
    {
        req.insert(0, "S3:set");
        record(req, 'S', n.substr(0, n.size() - 1));
        record(req, 'S', "0");
        if (context->ArraySize(args) != 1)
        {
            context->RaiseException1(Rexx_Error_Execution_user_defined, context->String("o~name = value takes one value"));
            return NULLOBJECT;
        }
        RexxObjectPtr v = context->ArrayAt(args, 1);
        if (v && context->IsInstanceOf(v, cls.netEvent))
        {
            // o~Click += h is o~Click = (o~Click + h): the + did the work
            std::string evName = context->ObjectToStringValue(context->SendMessage0(v, "NAME"));
            std::string owner = context->ObjectToStringValue(context->SendMessage0(context->SendMessage0(v, "OWNER"), "NETID"));
            std::string a = evName, b = n.substr(0, n.size() - 1);
            for (auto &ch : a) ch = (char)toupper((unsigned char)ch);
            if (a == b && owner == id) return NULLOBJECT;
            context->RaiseException1(Rexx_Error_Execution_user_defined,
                context->String("an event changes only with += and -= (o~Event += handler)"));
            return NULLOBJECT;
        }
        if (!encode(c, v, req)) return NULLOBJECT;
    }
    else
    {
        req.insert(0, "S4:send");
        record(req, 'S', n);
        record(req, 'S', "0");
        Refs refs;
        if (!encode(c, args, req, &refs)) return NULLOBJECT;
        return request(c, req, &refs, context->GetSelf());
    }
    return request(c, req, nullptr, context->GetSelf());
}

// NetObject~uninit: one Rexx proxy fewer for this handle.
RexxMethod0(RexxObjectPtr, net_uninit)
{
    RexxObjectPtr id = context->GetObjectVariable("NETID");
    if (mRelease && id != NULLOBJECT && context->IsString(id)) mRelease(atoi(context->ObjectToStringValue(id)));   // (none if init failed)
    return NULLOBJECT;
}

// NetRequest(op, args...): any operation (Bridge.cs), from net.cls.
RexxRoutine2(RexxObjectPtr, NetRequest, CSTRING, op, ARGLIST, args)
{
    findClasses(context);
    RexxThreadContext *c = context->threadContext;
    std::string req;
    record(req, 'S', op);
    size_t n = context->ArraySize(args);
    Refs refs;
    for (size_t i = 2; i <= n; i++) if (!encode(c, context->ArrayAt(args, i), req, &refs)) return NULLOBJECT;
    std::string o(op);                              // .net~invoke(o, ...), .net~get, .net~set, events: o receives
    RexxObjectPtr receiver = (o == "send" || o == "set" || o == "event") && n >= 2 ? context->ArrayAt(args, 2) : NULLOBJECT;
    return request(c, req, &refs, receiver);
}

// NetHandlerNew(): a new handler id. NetHandlerOf(id): the handler (.nil if
// released). NetHandlerDrop(id): forget it (handler~release).
RexxRoutine0(int, NetHandlerNew) { return nextHandler++; }

RexxRoutine1(RexxObjectPtr, NetHandlerOf, int, id)
{
    std::lock_guard<std::mutex> g(tablesLock);
    auto it = handlers.find(id);
    return it == handlers.end() ? context->Nil() : it->second.handler;
}

RexxRoutine1(RexxObjectPtr, NetHandlerDrop, int, id)
{
    Handler e{NULLOBJECT, NULLOBJECT, "", nullptr};
    {
        std::lock_guard<std::mutex> g(tablesLock);
        auto it = handlers.find(id);
        if (it == handlers.end()) return NULLOBJECT;
        e = it->second;
        handlers.erase(it);
    }
    context->ReleaseGlobalReference(e.handler);
    context->ReleaseGlobalReference(e.target);
    return NULLOBJECT;
}

static unsigned char *answer(const std::string &r, int *outLen)
{
    auto p = (unsigned char *)malloc(r.size() ? r.size() : 1);
    memcpy(p, r.data(), r.size());
    *outLen = (int)r.size();
    return p;
}

// The pending condition as a record E (and kept, to be raised again).
static std::string conditionRecord(RexxThreadContext *tc)
{
    RexxDirectoryObject info = tc->GetConditionInfo();
    RexxCondition k;
    tc->DecodeConditionInfo(info, &k);
    std::string name = k.conditionName ? tc->CString(k.conditionName) : "SYNTAX";
    std::string message = k.message ? tc->CString(k.message) : k.errortext ? tc->CString(k.errortext) : name;
    std::string code;
    if (name == "SYNTAX")
    {
        char b[32]; snprintf(b, sizeof b, "%ld.%ld", (long)(k.code / 1000), (long)(k.code % 1000)); code = b;   // "41.1", as Rexx writes it
    }
    std::string exc = "0";                         // a .NET exception gone to Rexx as 98.900
    if (k.additional && tc->ArraySize(k.additional) >= 2)
    {
        RexxObjectPtr x = tc->ArrayAt(k.additional, 2);
        if (x && tc->IsInstanceOf(x, cls.netObject)) exc = tc->ObjectToStringValue(tc->SendMessage0(x, "NETID"));
    }
    RexxObjectPtr description = tc->DirectoryAt(info, "DESCRIPTION");
    Condition kept{0, name, k.code, k.additional ? tc->RequestGlobalReference(k.additional) : NULLOBJECT,
                   description && description != tc->Nil() ? tc->RequestGlobalReference(description) : NULLOBJECT};
    std::vector<Condition> dropped;
    {
        std::lock_guard<std::mutex> g(tablesLock);
        kept.id = nextCondition++;
        conditions.push_back(kept);
        while (conditions.size() > keptConditions) { dropped.push_back(conditions.front()); conditions.pop_front(); }
    }
    for (auto &d : dropped)
    {
        if (d.additional) tc->ReleaseGlobalReference(d.additional);
        if (d.description) tc->ReleaseGlobalReference(d.description);
    }
    std::string traceback;
    RexxObjectPtr tb = tc->DirectoryAt(info, "TRACEBACK");
    if (tb && tb != tc->Nil())
    {
        RexxArrayObject a = (RexxArrayObject)tc->SendMessage0(tb, "MAKEARRAY");
        for (size_t i = 1; a && i <= tc->ArraySize(a); i++)
        {
            RexxObjectPtr l = tc->ArrayAt(a, i);
            if (!l) continue;
            std::string line = tc->ObjectToStringValue(l);
            for (auto &ch : line) if (ch == '\t') ch = ' ';
            if (!traceback.empty()) traceback += '\n';
            traceback += line;
        }
    }
    std::string p = std::to_string(kept.id) + '\t' + exc + '\t' + name + '\t' + code + '\t' + std::to_string((long)k.rc) + '\t' +
                    std::to_string(k.position) + '\t' + (k.program ? tc->CString(k.program) : "") + '\t' +
                    (k.errortext ? tc->CString(k.errortext) : "") + '\t' + traceback + '\t' + message;
    tc->ClearCondition();
    std::string out;
    record(out, 'E', p);
    return out;
}

// The pending condition reported on .error, as Rexx reports an untrapped
// error (traceback, then "Error rc running program line n: text" and, for
// SYNTAX, "Error code: message"), plus a line saying the program goes on:
// for a handler called where no Rexx code waits (a timer, the thread pool),
// whose error would otherwise end the process. Answers X (the default).
static std::string reportCondition(RexxThreadContext *tc)
{
    RexxDirectoryObject info = tc->GetConditionInfo();
    RexxCondition k;
    tc->DecodeConditionInfo(info, &k);
    std::string name = k.conditionName ? tc->CString(k.conditionName) : "SYNTAX";
    std::vector<std::string> lines;
    RexxObjectPtr tb = tc->DirectoryAt(info, "TRACEBACK");
    if (tb && tb != tc->Nil())
    {
        RexxArrayObject a = (RexxArrayObject)tc->SendMessage0(tb, "MAKEARRAY");
        for (size_t i = 1; a && i <= tc->ArraySize(a); i++)
        {
            RexxObjectPtr l = tc->ArrayAt(a, i);
            if (l) lines.push_back(tc->ObjectToStringValue(l));
        }
    }
    std::string program = k.program ? tc->CString(k.program) : "";
    if (name == "SYNTAX")
    {
        char b[64];
        snprintf(b, sizeof b, "Error %ld running ", (long)k.rc);
        lines.push_back(b + program + " line " + std::to_string(k.position) + ":  " + (k.errortext ? tc->CString(k.errortext) : ""));
        snprintf(b, sizeof b, "Error %ld.%ld:  ", (long)(k.code / 1000), (long)(k.code % 1000));
        if (k.message) lines.push_back(b + std::string(tc->CString(k.message)));
    }
    else lines.push_back("Condition " + name + " raised in " + program + " line " + std::to_string(k.position) +
                         (k.description ? std::string(":  ") + tc->CString(k.description) : std::string()));
    lines.push_back("(in a .NET handler that no Rexx code waits on: reported; the call returned its delegate's default, and the program goes on)");
    tc->ClearCondition();
    RexxObjectPtr err = tc->DirectoryAt(tc->GetLocalEnvironment(), "ERROR");
    for (auto &l : lines)
    {
        if (err && err != tc->Nil()) tc->SendMessage1(err, "LINEOUT", tc->String(l.c_str()));
        else fprintf(stderr, "%s\n", l.c_str());
        if (tc->CheckCondition()) { tc->ClearCondition(); fprintf(stderr, "%s\n", l.c_str()); }
    }
    return "X0:";
}

// Called by .NET (Callbacks.Call), on any thread: handler's target~message(args).
static unsigned char *rexxCallback(int id, int flags, const unsigned char *req, int len, int *outLen)
{
    Handler h{NULLOBJECT, NULLOBJECT, "", nullptr};
    {
        std::lock_guard<std::mutex> g(tablesLock);
        auto it = handlers.find(id);
        if (it != handlers.end()) h = it->second;
    }
    RexxThreadContext *tc = nullptr;
    RexxInstance *in = h.inst ? h.inst : instance;
    if (!h.target || !in || !in->AttachThread(&tc)) return answer("X0:", outLen);
    std::string out;
    char tag; std::string payload;
    parseRecord(req, (size_t)len, 0, tag, payload);
    RexxObjectPtr args = decode(tc, tag, payload);
    RexxObjectPtr r = NULLOBJECT;
    if (!tc->CheckCondition()) r = tc->SendMessage(h.target, h.message.c_str(), (RexxArrayObject)args);
    if (!tc->CheckCondition())
    {
        if (r == NULLOBJECT) record(out, 'V', "");
        else if (!encode(tc, r, out, nullptr, true)) out.clear();
    }
    if (tc->CheckCondition()) out = (flags & 1) ? reportCondition(tc) : conditionRecord(tc);
    tc->DetachThread();
    return answer(out, outLen);
}

RexxMethodEntry rexxnet_methods[] = {
    REXX_METHOD(net_unknown, net_unknown),
    REXX_METHOD(net_uninit, net_uninit),
    REXX_LAST_METHOD() };
RexxRoutineEntry rexxnet_routines[] = {
    REXX_TYPED_ROUTINE(NetRequest, NetRequest),
    REXX_TYPED_ROUTINE(NetHandlerNew, NetHandlerNew),
    REXX_TYPED_ROUTINE(NetHandlerOf, NetHandlerOf),
    REXX_TYPED_ROUTINE(NetHandlerDrop, NetHandlerDrop),
    REXX_LAST_ROUTINE() };
RexxPackageEntry rexxnet_package_entry = {
    STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0, "rexxnet", "0.1",
    nullptr, nullptr, rexxnet_routines, rexxnet_methods };
OOREXX_GET_PACKAGE(rexxnet);
