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
// (C), it is raised again as it was. An instance of a Rexx class extending a
// .NET class (.net~extend) comes back as p "handler id": the Rexx object it
// belongs to (its peer handler's target), not a new proxy.
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
#include <unordered_map>
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
typedef void (CORECLR_DELEGATE_CALLTYPE *init_fn)(void *, void *, void *, void *, void *);
typedef void (CORECLR_DELEGATE_CALLTYPE *classes_fn)(RexxObjectPtr, RexxObjectPtr, RexxObjectPtr, RexxObjectPtr, RexxObjectPtr);

static request_fn mRequest;
static free_fn mFree;
static release_fn mRelease;
static classes_fn mClasses;
static std::string loadError;
static std::once_flag clrOnce;
static RexxInstance *instance;          // for AttachThread (set on the first request; a handler keeps its own)

static unsigned char *rexxCallback(int handler, int flags, const unsigned char *req, int len, int *outLen);
static void nativeFree(unsigned char *p) { free(p); }
static void peerDead(int id);
static void handlerGone(int id, int seen);
static int raiseHeld(RexxThreadContext *c, int id, RexxObjectPtr *answer);

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
    mInit((void *)rexxCallback, (void *)nativeFree, (void *)peerDead, (void *)handlerGone, (void *)raiseHeld);
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
        ((init_fn)init)((void *)rexxCallback, (void *)nativeFree, (void *)peerDead, (void *)handlerGone, (void *)raiseHeld);
    });
}

// ---------------------------------------------------------------- the classes

// net.cls's classes, found once from a context inside net.cls.
struct Classes { RexxClassObject netObject, netType, netArray, netEnum, netNamespace, netTyped, netRef, netHandler, netEvent, string, logical;
                 RexxObjectPtr yes, no; };     // (ooRexx's .LogicalWrapper, and its two instances)
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
        cls.logical = find("LOGICALWRAPPER");                // (net.cls requires logicalwrapper.cls)
        if (cls.logical)
        {
            cls.yes = c->RequestGlobalReference(c->SendMessage0(cls.logical, "TRUE"));
            cls.no = c->RequestGlobalReference(c->SendMessage0(cls.logical, "FALSE"));
        }
    });
}

// ------------------------------------------------------------------ handlers

// The .NetHandlers that have gone to .NET, by id: kept (global references)
// until handler~release, or until nothing in .NET can call them any more: the
// managed side's RexxHandler, held only by what can call it, is collected and
// says so (handlerGone, on .NET's finalizer thread: no API call; the handler
// is let go with the next request, drainDead). regs counts the times it went
// to .NET (each H record carries the count): handlerGone carries the last
// count that RexxHandler saw, so that one that went meanwhile (a new
// RexxHandler for it) keeps it.
//
// Pairs. The peer handler of an instance of a Rexx class extending a .NET
// class (option "peer": its target is the instance's Rexx object, which holds
// it) is not kept: the pair, its Rexx object and its .NET object, lives while
// Rexx holds the one or .NET the other, and the link that keeps the other half
// alive points one way at a time (managed/Extend.cs, Lifetime):
//  - Rexx holds the Rexx object: it holds its .NET object (its handle), and
//    here the Rexx object is known (target) but not held;
//  - when Rexx no longer holds it, its sentinel says so (NetPeerUninit: a
//    .NetPeerSentinel, which only the Rexx object holds and which holds it,
//    so that its UNINIT runs when the Rexx object could go): it is held here
//    (pin), and .NET holds its object weakly (peerWeak): .NET's collector
//    decides. If it collects it (peerDead, on its finalizer thread: no API
//    call), the pair is over: with the next request (drainDead) the class's
//    UNINIT runs (NETFINAL), the handle is released and the pin dropped. If
//    the object goes to Rexx again (p, or an override's call: a crossing),
//    Rexx holds it again: a new sentinel (NETARM), and the pin dropped.
// The Rexx object has no UNINIT of its own meanwhile (its class's runs once,
// at the end), and each round has a new sentinel (an object's UNINIT runs
// only once). When its interpreter instance ends (ooRexx then collects with
// the program gone, and runs the UNINITs: a .NetInstanceEnd in .local says
// so, NetInstanceEnding), every pair of that instance is over, as any Rexx
// object with an UNINIT: those only .NET holds at once, the others when their
// sentinel's UNINIT runs (endPair: the .NET object, if still alive, then
// runs its base's implementations). received counts the crossings that arrived; peerWeak carries it,
// and the managed side ignores it when one is still on its way.
// No API call is made with tablesLock held: one may run UNINIT methods, on
// this thread, that need it.
struct Handler
{
    RexxObjectPtr handler, target; std::string message; RexxInstance *inst;
    bool peer = false;                              // a pair's (not held: see above)
    bool net = false;                               // only .NET holds the pair (pin holds the Rexx object)
    RexxObjectPtr pin = NULLOBJECT;
    size_t received = 0, armed = 0, sentinel = 0;   // crossings arrived; when the sentinel was made; its number
    int regs = 0;                                   // (not a pair's) its times to .NET
    bool ending = false;                            // (a pair's) its instance ends: its UNINIT running
};
static std::mutex tablesLock;
static std::map<int, Handler> handlers;
static std::atomic<int> nextHandler{1};
static std::vector<int> deadPeers;                  // pairs over, for drainDead
// (an instance as its programs' contexts see it: the UNINITs of its end may
// run with another one)
static std::vector<RexxInstance *> endingInstances; // instances ending (NetInstanceEnding)

static bool instanceEnding(RexxInstance *i)         // (tablesLock held)
{
    for (auto e : endingInstances) if (e == i) return true;
    return false;
}
static std::vector<std::pair<int, int>> goneHandlers;   // handlers .NET can no longer call (id, count seen), for drainDead
static std::atomic<bool> anyDead{false};

// Messages to objects that user code may stand behind: an instance of a
// subclass of the bridge's classes (or of .LogicalWrapper) with its own
// method, a value whose own MAKESTRING or STRING runs. False, with a condition
// pending, if it raised one or answered nothing (91.999, as plain Rexx), so
// that the caller stops at once: going on, a value half encoded went to .NET
// and the condition reached the Rexx caller late, after .NET had run; and
// ObjectToStringValue's NULL, read, crashed the process (oorexx-bridges,
// lesson 7).
static bool sent(RexxThreadContext *c, RexxObjectPtr o, const char *msg, RexxObjectPtr &r)
{
    r = c->SendMessage0(o, msg);
    if (c->CheckCondition()) return false;
    if (r == NULLOBJECT)
    {
        c->RaiseException1(Rexx_Error_No_result_object_message, c->String(msg));
        return false;
    }
    return true;
}
static bool textOf(RexxThreadContext *c, RexxObjectPtr o, std::string &s)
{
    CSTRING t = c->ObjectToStringValue(o);
    if (t == nullptr || c->CheckCondition()) return false;
    s = t;
    return true;
}
static bool sentText(RexxThreadContext *c, RexxObjectPtr o, const char *msg, std::string &s)
{
    RexxObjectPtr r;
    return sent(c, o, msg, r) && textOf(c, r, s);
}

// Its count of times to .NET (0 for a pair's); -1 with a condition pending
// if the handler's TARGET or MESSAGE raised one.
static int registerHandler(RexxThreadContext *c, int id, RexxObjectPtr h, bool peer)
{
    {
        std::lock_guard<std::mutex> g(tablesLock);
        auto it = handlers.find(id);
        if (it != handlers.end()) return it->second.peer ? 0 : ++it->second.regs;
    }
    RexxObjectPtr target;
    std::string message;
    if (!sent(c, h, "TARGET", target) || !sentText(c, h, "MESSAGE", message)) return -1;
    Handler e{peer ? h : c->RequestGlobalReference(h), peer ? target : c->RequestGlobalReference(target), message, c->instance};
    e.peer = peer;
    e.regs = peer ? 0 : 1;
    int n;
    bool extra = false;
    {
        std::lock_guard<std::mutex> g(tablesLock);
        auto r = handlers.emplace(id, e);
        if (r.second) n = e.regs;
        else { extra = !peer; n = r.first->second.peer ? 0 : ++r.first->second.regs; }   // another thread's first
    }
    if (extra) { c->ReleaseGlobalReference(e.handler); c->ReleaseGlobalReference(e.target); }
    return n;
}

// .NET can no longer call a handler (its finalizer thread): for drainDead.
static void handlerGone(int id, int seen)
{
    std::lock_guard<std::mutex> g(tablesLock);
    goneHandlers.push_back({id, seen});
    anyDead = true;
}

// A pair's .NET object goes to Rexx (p, or an override's call): its Rexx
// object, held by Rexx again; NULLOBJECT if id is no pair (any more).
static RexxObjectPtr peerCrossing(RexxThreadContext *c, int id)
{
    RexxObjectPtr obj, pin = NULLOBJECT;
    {
        std::lock_guard<std::mutex> g(tablesLock);
        auto it = handlers.find(id);
        if (it == handlers.end() || !it->second.peer) return NULLOBJECT;
        Handler &pe = it->second;
        pe.received++;
        obj = pe.target;
        if (pe.net && !pe.ending) { pe.net = false; pin = pe.pin; pe.pin = NULLOBJECT; }
    }
    if (pin != NULLOBJECT)
    {
        // a new sentinel (NETARM answers the object: a local reference of
        // this call) before the pin goes
        RexxObjectPtr o = c->SendMessage0(obj, "NETARM");
        if (c->CheckCondition()) c->ClearCondition();
        if (o != NULLOBJECT) obj = o;
        c->ReleaseGlobalReference(pin);
    }
    return obj;
}

// .NET collected a pair's object (its finalizer thread): over, for drainDead.
static void peerDead(int id)
{
    std::lock_guard<std::mutex> g(tablesLock);
    deadPeers.push_back(id);
    anyDead = true;
}

// The pairs that are over: their class's UNINIT, their handle, their pin.
static void drainDead(RexxThreadContext *c)
{
    if (!anyDead.exchange(false)) return;
    std::vector<std::pair<RexxObjectPtr, RexxObjectPtr>> over;    // the Rexx object, its pin
    std::vector<RexxObjectPtr> unpinned;                          // handlers' global references
    {
        std::lock_guard<std::mutex> g(tablesLock);
        for (auto &gh : goneHandlers)
        {
            auto it = handlers.find(gh.first);
            if (it == handlers.end() || it->second.peer || it->second.regs != gh.second) continue;   // gone already, or went again
            unpinned.push_back(it->second.handler);
            unpinned.push_back(it->second.target);
            handlers.erase(it);
        }
        goneHandlers.clear();
        for (int id : deadPeers)
        {
            auto it = handlers.find(id);
            if (it == handlers.end() || !it->second.peer || !it->second.net) continue;
            over.push_back({it->second.target, it->second.pin});
            handlers.erase(it);
        }
        deadPeers.clear();
    }
    for (RexxObjectPtr o : unpinned) c->ReleaseGlobalReference(o);
    for (auto &p : over)
    {
        c->SendMessage0(p.first, "NETFINAL");
        if (c->CheckCondition()) c->ClearCondition();
        c->ReleaseGlobalReference(p.second);
    }
}

// Rexx conditions that ended a callback, kept so that if they come back out
// of .NET they are raised again as they were. The last few only: .NET may
// swallow the exception, and then nobody asks for it.
// object: the condition object itself (a global reference), raised again as
// it is (RaiseConditionObject: a copy with everything it holds); returned:
// what the method answered with the condition (RAISE ... RETURN value)
struct Condition { int id; std::string name; wholenumber_t code; RexxObjectPtr object, returned; };
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
// The Arrays of one value (memo: one per value encoded): each opens with I
// "n", its number in this value; one met again (an Array that contains
// itself, Arrays that contain each other, one Array twice) is Q "n", so .NET
// gets the same structure (oorexx-bridges, topic "cyclic-arrays"). Nested
// more than maxArrayDepth deep: an error (the copy recurses, here and there).
struct Memo { std::unordered_map<RexxObjectPtr, size_t> seen; int depth = 0; };
const int maxArrayDepth = 1000;
static bool encode(RexxThreadContext *c, RexxObjectPtr o, std::string &out, Refs *refs = nullptr, bool adopt = false,
                   Memo *memo = nullptr)
{
    Memo own;
    if (!memo) memo = &own;
    if (o == NULLOBJECT || o == c->Nil()) { record(out, 'N', ""); return true; }
    if (c->IsInstanceOf(o, cls.netObject))
    {
        std::string id;
        if (!sentText(c, o, "NETID", id)) return false;
        record(out, 'O', id);
        return true;
    }
    if (c->IsInstanceOf(o, cls.netRef))
    {
        std::string inner;
        RexxObjectPtr v;
        if (!sent(c, o, "VALUE", v) || !encode(c, v, inner, nullptr, false, memo)) return false;
        record(out, 'R', inner);
        if (refs) refs->push_back(o);
        return true;
    }
    if (c->IsInstanceOf(o, cls.netHandler))
    {
        std::string ids, options;
        RexxObjectPtr released;
        if (!sentText(c, o, "ID", ids) || !sentText(c, o, "OPTIONS", options) || !sent(c, o, "RELEASED", released)) return false;
        int id = atoi(ids.c_str());
        int n = 0;
        if (released == c->True()) options += " released";   // still its delegate, for -=
        else if ((n = registerHandler(c, id, o, options == "peer")) < 0) return false;
        record(out, 'H', std::to_string(id) + '\t' + options + '\t' + std::to_string(n));
        return true;
    }
    if (c->IsInstanceOf(o, cls.netTyped))
    {
        std::string inner;
        RexxObjectPtr v;
        if (!sentText(c, o, "KIND", inner)) return false;
        inner += '\t';
        if (!sent(c, o, "VALUE", v) || !encode(c, v, inner, nullptr, false, memo)) return false;
        record(out, 'T', inner);
        return true;
    }
    if (c->IsArray(o))
    {
        RexxArrayObject a = (RexxArrayObject)o;
        auto met = memo->seen.find(o);
        if (met != memo->seen.end()) { record(out, 'Q', std::to_string(met->second)); return true; }
        if (memo->depth >= maxArrayDepth)
        {
            c->RaiseException1(Rexx_Error_Execution_user_defined,
                c->String(("Arrays nested more than " + std::to_string(maxArrayDepth) + " deep cannot go to .NET").c_str()));
            return false;
        }
        size_t number = memo->seen.size();
        memo->seen[o] = number;
        std::string items;
        record(items, 'I', std::to_string(number));
        // an omitted item (a sparse Array): N, null where .NET takes one (the
        // size is kept; oorexx-bridges, topic "array-shape")
        size_t last = c->ArraySize(a);
        memo->depth++;
        // each item a local reference of the method in progress, kept until it
        // returns unless released: released once encoded (the Array holds it;
        // a million items sent three times grew the process by hundreds of MB)
        for (size_t i = 1; i <= last; i++)
        {
            RexxObjectPtr item = c->ArrayAt(a, i);
            bool ok = encode(c, item, items, refs, adopt, memo);
            if (item != NULLOBJECT) c->ReleaseLocalReference(item);
            if (!ok) { memo->depth--; return false; }
        }
        memo->depth--;
        size_t dims = c->ArrayDimension(a);
        if (dims <= 1)
        {
            // P: the Array's own pointer, valid while the request runs (as X's),
            // for a RexxObject parameter, which gets the Array itself, not a copy
            if (!adopt) record(items, 'P', std::to_string((uintptr_t)o));
            record(out, 'A', items);
            return true;
        }
        // A multidimensional Array: M "d1,d2,...\t" and its items in Rexx's
        // linear order (the first index varies fastest), for a T[,] in .NET
        std::string head;
        for (size_t d = 1; d <= dims; d++)
        {
            wholenumber_t n = 0;
            RexxObjectPtr dn = c->SendMessage1(o, "DIMENSION", c->WholeNumberToObject((wholenumber_t)d));
            if (c->CheckCondition()) return false;
            c->ObjectToWholeNumber(dn, &n);
            if (d > 1) head += ',';
            head += std::to_string(n);
        }
        record(out, 'M', head + '\t' + items);
        return true;
    }
    // .true and .false themselves (not the strings "1" and "0"): L, read as
    // an S "1" / "0" that remembers it was a logical (COM: VT_BOOL, as
    // .OLEObject sends them)
    if (o == c->True() || o == c->False()) { record(out, 'L', o == c->True() ? "1" : "0"); return true; }
    // a .LogicalWrapper (ooRexx's; JSON's and YAML's booleans, its subclasses): B,
    // "1" or "0", a bool in .NET (to a bool or an object parameter)
    if (cls.logical && c->IsInstanceOf(o, cls.logical))
    {
        RexxObjectPtr v;
        std::string t;
        if (!sent(c, o, "VALUE", v) || !textOf(c, v, t)) return false;
        record(out, 'B', t == "1" ? "1" : "0");
        return true;
    }
    if (c->IsInstanceOf(o, cls.string))
    {
        RexxStringObject s = c->ObjectToString(o);
        if (s == NULLOBJECT || c->CheckCondition()) return false;
        record(out, 'S', std::string(c->StringData(s), c->StringLength(s)));
        if ((RexxObjectPtr)s != o) c->ReleaseLocalReference(s);       // (a new string: a number's, say)
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

// A message's arguments, as a record A: an omitted argument (o~m(, 2)) goes
// as N, "not given" (COM: an optional parameter left out; .NET: null),
// where an Array as a value refuses omitted items.
static bool encodeArgs(RexxThreadContext *c, RexxArrayObject args, std::string &out, Refs *refs)
{
    std::string items;
    size_t last = c->ArraySize(args);
    for (size_t i = 1; i <= last; i++) if (!encode(c, c->ArrayAt(args, i), items, refs)) return false;
    record(out, 'A', items);
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
        case 'B': return payload == "1" ? (cls.yes ? cls.yes : c->True()) : (cls.no ? cls.no : c->False());   // a bool
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
            // (a HALT: the thread halted, the call answers .nil; else what the
            // Rexx code returned with the condition, its pending RESULT, or none)
            return payload == "halt" ? c->Nil()
                 : payload.empty() ? NULLOBJECT : (RexxObjectPtr)(uintptr_t)strtoull(payload.c_str(), nullptr, 10);
        case 'p':                                   // an instance of a Rexx class extending a .NET class: its Rexx object
        {
            RexxObjectPtr o = peerCrossing(c, atoi(payload.c_str()));
            return o == NULLOBJECT ? c->Nil() : o;
        }
        case 'e':                                   // a .NetEvent: its owner and name
        {
            RexxObjectPtr owner = newProxy(c, proxyClass(field(payload, 1)), field(payload, 0), field(payload, 2));
            return c->SendMessage2(cls.netEvent, "NEW", owner, c->String(field(payload, 3).c_str()));
        }
        case 'C':                                   // a Rexx condition from a callback, raised again
        {
            RexxObjectPtr answer;
            int raised = raiseHeld(c, atoi(field(payload, 0).c_str()), &answer);
            if (!raised)
                c->RaiseException1(Rexx_Error_Execution_user_defined, c->String(payload.substr(payload.find('\t') + 1).c_str()));
            return raised == 2 ? c->Nil() : answer;                // (a HALT: the thread halted, the call answers .nil)
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
            // id, type, the .NET stack trace, the message (the rest: it may hold tabs).
            // additional: [1] the message, [2] the exception, [3] its stack trace
            // (the bridges' common layout: oorexx-bridges, rexx-errors-in-the-host)
            size_t t1 = payload.find('\t'), t2 = payload.find('\t', t1 + 1), t3 = payload.find('\t', t2 + 1);
            std::string id = field(payload, 0), trace = payload.substr(t2 + 1, t3 - t2 - 1), message = payload.substr(t3 + 1);
            if (!message.empty() && message.back() == '.') message.pop_back();   // 98.900 adds its own
            RexxArrayObject info = c->NewArray(id != "0" ? 3 : 1);
            c->ArrayPut(info, c->String(message.c_str()), 1);
            if (id != "0")
            {
                c->ArrayPut(info, newProxy(c, cls.netObject, id, field(payload, 1)), 2);
                c->ArrayPut(info, c->String(trace.c_str()), 3);
            }
            c->RaiseException(Rexx_Error_Execution_user_defined, info);
            return NULLOBJECT;
        }
    }
    c->RaiseException1(Rexx_Error_Execution_user_defined, c->String("rexxnet: bad response"));
    return NULLOBJECT;
}

// The thread context of the request this thread is making to the managed side
// (innermost), for the calls back into Rexx that .NET makes meanwhile on this
// thread (rexxCallback) once their instance has ended: they run in it,
// nested, rather than attaching the thread to the instance. The UNINITs that
// ooRexx runs as the interpreter ends (MemoryObject::runUninits, from
// Interpreter::terminateInterpreter) run after the instances have terminated,
// and attaching to a terminated instance read freed memory (a pair's UNINIT,
// calling .NET, whose override calls Rexx back: SIGBUS / SIGSEGV on macOS).
// Only then: in every other case a call back attaches, as it always did
// (running all nested calls in the request's context made ooDialog-on-.NET
// programs, with their GUI thread, crash on Windows).
static thread_local RexxThreadContext *requesting = nullptr;

// A Rexx condition that a callback's Rexx code raised, kept by its id (the
// callback's answer E), raised again on c: by a response C, or by the managed
// side directly (a command handler, which no request answers). 0 if no such id,
// 2 if it was a HALT (raised by halting the thread: see below), else 1.
// *answer: what the native call answers, for a condition other than SYNTAX
// or HALT the value the Rexx code returned with it (RAISE ... RETURN), which
// plain Rexx gives the caller when the condition is not trapped or a CALL ON
// resumes; it goes as the condition's RESULT, so the pending condition object
// keeps it alive until the call returns. Else NULLOBJECT (none).
static int raiseHeld(RexxThreadContext *c, int id, RexxObjectPtr *answer)
{
    if (answer) *answer = NULLOBJECT;
    Condition k{0, "", 0, NULLOBJECT, NULLOBJECT};
    {
        std::lock_guard<std::mutex> g(tablesLock);
        for (auto it = conditions.begin(); it != conditions.end(); ++it)
            if (it->id == id) { k = *it; conditions.erase(it); break; }
    }
    if (k.id == 0) return 0;
    // SYNTAX 4.1 ("Program interrupted with HALT condition") is what ooRexx
    // makes of a HALT the callback's Rexx code did not trap: the Rexx caller
    // gets a HALT again (oorexx-bridges, command handlers, rule 1). Not
    // RaiseCondition: an untrapped HALT raised so is ignored and the halt
    // lost. HaltThread is a Ctrl-C on this thread: SIGNAL ON HALT traps it at
    // the end of the clause, CALL ON HALT after it (the call answers .nil
    // meanwhile), and untrapped it is SYNTAX 4.1, as in plain Rexx.
    bool halt = k.name == "SYNTAX" && k.code == Rexx_Error_Program_interrupted_condition;
    // A SYNTAX: RaiseException, not RaiseConditionObject. The copy that
    // RaiseConditionObject raises for a SYNTAX is held by nothing the
    // collector marks while the native activation is popped (ooRexx #2132: a
    // crash under threads, the family's finding); RaiseException's object is
    // the activity's condition object. Its DESCRIPTION and RESULT are put into
    // GetConditionInfo()'s object, the pending condition object itself
    // (r13297): a workaround, until #2132 is in.
    // Any other condition: the condition object as it is (RFE #883,
    // RaiseConditionObject, ooRexx r13329): ERROR and FAILURE with their RC,
    // everything it holds.
    if (halt) c->HaltThread();
    else if (k.name == "SYNTAX")
    {
        RexxDirectoryObject o = (RexxDirectoryObject)k.object;
        RexxObjectPtr additional = c->DirectoryAt(o, "ADDITIONAL");
        RexxObjectPtr description = c->DirectoryAt(o, "DESCRIPTION");
        RexxObjectPtr result = c->DirectoryAt(o, "RESULT");
        c->RaiseException(k.code, additional && c->IsArray(additional) ? (RexxArrayObject)additional : NULLOBJECT);
        RexxDirectoryObject raised = c->GetConditionInfo();
        if (raised != NULLOBJECT)
        {
            if (description && description != c->Nil()) c->DirectoryPut(raised, description, "DESCRIPTION");
            if (result && result != c->Nil()) c->DirectoryPut(raised, result, "RESULT");
            c->ReleaseLocalReference(raised);
        }
    }
    else if (c->functions->interfaceVersion < THREAD_INTERFACE_VERSION_5_3_0)       // (an ooRexx older than the minimum: no such entry)
        c->RaiseException1(Rexx_Error_Execution_user_defined,
            c->String("ooRexx/.NET needs ooRexx 5.3.0 r13329 or later to raise a Rexx condition again"));
    else
    {
        c->RaiseConditionObject((RexxDirectoryObject)k.object);
        // RAISE ... RETURN's value: not in the condition object (ooRexx
        // #2130), so the call's result kept with it is put into the pending
        // copy as its RESULT (GetConditionInfo() answers that copy itself,
        // r13297), which keeps it alive until the call returns. Workaround,
        // to drop when #2130 is in.
        {
            RexxDirectoryObject raised = c->GetConditionInfo();
            if (raised != NULLOBJECT)
            {
                RexxObjectPtr result = c->DirectoryAt(raised, "RESULT");
                if ((result == NULLOBJECT || result == c->Nil()) && k.returned)
                {
                    c->DirectoryPut(raised, k.returned, "RESULT");
                    result = k.returned;
                }
                if (answer && result != c->Nil()) *answer = result;
                c->ReleaseLocalReference(raised);
            }
        }
    }
    if (k.object) c->ReleaseGlobalReference(k.object);
    if (k.returned) c->ReleaseGlobalReference(k.returned);
    return halt ? 2 : 1;
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
    drainDead(c);
    if (!mRequest)
    {
        c->RaiseException1(Rexx_Error_Execution_user_defined, c->String((".NET: " + loadError).c_str()));
        return NULLOBJECT;
    }
    static std::once_flag classesOnce;           // net.cls's classes, for the managed side (.NetObjects in RexxObject's world)
    if (cls.netObject) std::call_once(classesOnce, [] { mClasses(cls.netObject, cls.netType, cls.netArray, cls.netEnum, cls.logical); });
    int len = 0;
    // The thread context goes with the request: .NET code called from here
    // calls Rexx back on this thread, nested (RexxInterpreter.Current).
    RexxThreadContext *outer = requesting;
    requesting = c;
    unsigned char *resp = mRequest(c, (const unsigned char *)req.data(), (int)req.size(), &len);
    requesting = outer;
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
        if (!encodeArgs(c, args, req, &refs)) return NULLOBJECT;
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

// .NetCommandHandler~command(command, caller): native, so that no Rexx
// activation stands between the code that sent the command and the .NET
// handler (oorexx-bridges, command handlers, lesson 1), and cheaper: the
// request is made directly (its id, the command, the .CommandContext by
// pointer: X), with none of encode's questions. A HALT that Rexx code the
// handler called did not trap comes back as a halt of this thread
// (raiseHeld: HaltThread), which the sender then gets, as a Ctrl-C; the
// command's RC is 0 meanwhile.
RexxMethod2(RexxObjectPtr, net_command, RexxObjectPtr, command, RexxObjectPtr, caller)
{
    findClasses(context);
    RexxObjectPtr id = context->GetObjectVariable("ID");
    if (id == NULLOBJECT || id == context->Nil())                // released: as an unknown environment
        return context->SendMessage2(caller, "RAISE", context->String("FAILURE"), context->WholeNumber(30));
    std::string req;
    record(req, 'S', "cmdRun");
    record(req, 'S', context->ObjectToStringValue(id));
    RexxStringObject s = context->ObjectToString(command);
    if (s == NULLOBJECT || context->CheckCondition()) return NULLOBJECT;     // (a command whose own MAKESTRING or STRING raised: that condition)
    record(req, 'S', std::string(context->StringData(s), context->StringLength(s)));
    record(req, 'X', std::to_string((uintptr_t)caller));
    RexxObjectPtr r = request(context->threadContext, req);
    if (context->CheckCondition()) return NULLOBJECT;
    return r == NULLOBJECT || r == context->Nil() ? (RexxObjectPtr)context->WholeNumber(0) : r;
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
    if (e.peer) { if (e.pin) context->ReleaseGlobalReference(e.pin); return NULLOBJECT; }
    context->ReleaseGlobalReference(e.handler);
    context->ReleaseGlobalReference(e.target);
    return NULLOBJECT;
}

// A pair over because its instance ends: its class's UNINIT (its overrides
// still reach it meanwhile), then no peer for its .NET object any more (if it
// is still alive: NETFINAL), its handle, and its entry here.
static void endPair(RexxThreadContext *c, int id, RexxObjectPtr obj)
{
    c->SendMessage0(obj, "NETFINAL");
    if (c->CheckCondition()) c->ClearCondition();
    RexxObjectPtr pin = NULLOBJECT;
    {
        std::lock_guard<std::mutex> g(tablesLock);
        auto it = handlers.find(id);
        if (it != handlers.end() && it->second.peer) { pin = it->second.pin; handlers.erase(it); }
    }
    if (pin != NULLOBJECT) c->ReleaseGlobalReference(pin);
}

// NetInstanceId(): this instance, for its .NetInstanceEnd.
RexxRoutine0(RexxStringObject, NetInstanceId)
{
    return context->String(std::to_string((uintptr_t)context->threadContext->instance).c_str());
}

// NetInstanceEnding(instance id): that interpreter instance ends
// (.NetInstanceEnd's UNINIT): its pairs are over.
RexxRoutine1(int, NetInstanceEnding, CSTRING, which)
{
    RexxThreadContext *c = context->threadContext;
    RexxInstance *inst = (RexxInstance *)(uintptr_t)strtoull(which, nullptr, 10);
    std::vector<std::pair<int, RexxObjectPtr>> over;              // id, the Rexx object (pinned)
    {
        std::lock_guard<std::mutex> g(tablesLock);
        if (!instanceEnding(inst)) endingInstances.push_back(inst);
        for (auto &h : handlers)
            if (h.second.peer && h.second.net && !h.second.ending && h.second.inst == inst)
            {
                h.second.ending = true;
                over.push_back({h.first, h.second.target});
            }
    }
    for (auto &p : over) endPair(c, p.first, p.second);
    return 0;
}

// NetPeerArm(handler id): a new sentinel's number (Rexx holds the pair's Rexx object).
RexxRoutine1(size_t, NetPeerArm, int, id)
{
    std::lock_guard<std::mutex> g(tablesLock);
    auto it = handlers.find(id);
    if (it == handlers.end() || !it->second.peer) return 0;
    it->second.armed = it->second.received;
    return ++it->second.sentinel;
}

// NetPeerUninit(object, handler id, sentinel): the sentinel's UNINIT, run when
// Rexx no longer held the object. "KEEP": now only .NET holds it (pinned here,
// weak there); "REARM": a crossing came meanwhile, so Rexx may hold it: a new
// sentinel; "" for an old sentinel, or no pair.
RexxRoutine3(CSTRING, NetPeerUninit, RexxObjectPtr, self, int, id, size_t, sentinel)
{
    RexxThreadContext *c = context->threadContext;
    RexxObjectPtr pin = c->RequestGlobalReference(self);    // made first (no API call with the lock), dropped if unused
    const char *answer = "";
    size_t received = 0;
    bool ending = false;
    {
        std::lock_guard<std::mutex> g(tablesLock);
        auto it = handlers.find(id);
        if (it != handlers.end() && it->second.peer)
        {
            Handler &pe = it->second;
            if (sentinel != pe.sentinel || pe.net) answer = "";
            else if (instanceEnding(pe.inst)) { ending = true; pe.ending = true; }   // its instance ends: over
            else if (pe.received != pe.armed) answer = "REARM";
            else { pe.pin = pin; pin = NULLOBJECT; pe.net = true; received = pe.received; answer = "KEEP"; }
        }
    }
    if (pin != NULLOBJECT) c->ReleaseGlobalReference(pin);
    if (ending) endPair(c, id, self);
    if (answer[0] == 'K')
    {
        // .NET to hold its object weakly, unless a crossing is still on its way
        std::string req;
        record(req, 'S', "peerWeak");
        if (encode(c, self, req)) { record(req, 'S', std::to_string(received)); request(c, req); }
        if (c->CheckCondition()) c->ClearCondition();
    }
    drainDead(c);
    return answer;
}

static unsigned char *answer(const std::string &r, int *outLen)
{
    auto p = (unsigned char *)malloc(r.size() ? r.size() : 1);
    memcpy(p, r.data(), r.size());
    *outLen = (int)r.size();
    return p;
}

// A condition object decoded into k. DecodeConditionInfo is asked only for
// SYNTAX: up to ooRexx r13286 it crashes on any other condition (it reads a
// CODE they do not have; ooRexx #2123's first step fixes it). For the others,
// k is filled as #2123's fix fills it: rc the RC when a whole number (ERROR,
// FAILURE), else 0; code 0; description and additional only when a String and
// an Array, else NULLOBJECT (the condition object keeps them as RAISE gave
// them). The same on every revision, with or without the fix.
static void decodeCondition(RexxThreadContext *tc, RexxDirectoryObject info, RexxCondition &k)
{
    RexxObjectPtr name = tc->DirectoryAt(info, "CONDITION");
    if (name && tc->IsString(name) && strcmp(tc->ObjectToStringValue(name), "SYNTAX") == 0)
    {
        tc->DecodeConditionInfo(info, &k);
        return;
    }
    memset(&k, 0, sizeof k);
    k.conditionName = name && tc->IsString(name) ? (RexxStringObject)name : NULLOBJECT;
    wholenumber_t n;
    RexxObjectPtr x = tc->DirectoryAt(info, "RC");
    if (x && tc->ObjectToWholeNumber(x, &n)) k.rc = n;
    x = tc->DirectoryAt(info, "POSITION");
    if (x && tc->ObjectToWholeNumber(x, &n)) k.position = n;
    x = tc->DirectoryAt(info, "PROGRAM");
    if (x && tc->IsString(x)) k.program = (RexxStringObject)x;
    x = tc->DirectoryAt(info, "DESCRIPTION");
    if (x && tc->IsString(x)) k.description = (RexxStringObject)x;
    x = tc->DirectoryAt(info, "ADDITIONAL");
    if (x && tc->IsArray(x)) k.additional = (RexxArrayObject)x;
}

// The pending condition as a record E (and kept, to be raised again).
static std::string conditionRecord(RexxThreadContext *tc, RexxObjectPtr returned = NULLOBJECT)
{
    RexxDirectoryObject info = tc->GetConditionInfo();
    RexxCondition k;
    decodeCondition(tc, info, k);
    std::string name = k.conditionName ? tc->CString(k.conditionName) : "SYNTAX";
    std::string message = k.message ? tc->CString(k.message) : k.errortext ? tc->CString(k.errortext) : name;
    std::string code;
    if (name == "SYNTAX")
    {
        char b[32]; snprintf(b, sizeof b, "%ld.%ld", (long)(k.code / 1000), (long)(k.code % 1000)); code = b;   // "41.1", as Rexx writes it
    }
    std::string exc = "0";                         // a .NET exception gone to Rexx as 98.900
    if (k.additional && tc->IsArray(k.additional) && tc->ArraySize(k.additional) >= 2)
    {
        RexxObjectPtr x = tc->ArrayAt(k.additional, 2);
        if (x && tc->IsInstanceOf(x, cls.netObject)) exc = tc->ObjectToStringValue(tc->SendMessage0(x, "NETID"));
    }
    // the condition object itself, kept (rule 1: raised again as it was)
    Condition kept{0, name, k.code, tc->RequestGlobalReference(info),
                   returned && returned != tc->Nil() && name != "SYNTAX" ? tc->RequestGlobalReference(returned) : NULLOBJECT};
    std::vector<Condition> dropped;
    {
        std::lock_guard<std::mutex> g(tablesLock);
        kept.id = nextCondition++;
        conditions.push_back(kept);
        while (conditions.size() > keptConditions) { dropped.push_back(conditions.front()); conditions.pop_front(); }
    }
    for (auto &d : dropped)
    {
        if (d.object) tc->ReleaseGlobalReference(d.object);
        if (d.returned) tc->ReleaseGlobalReference(d.returned);
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
    decodeCondition(tc, info, k);
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
    if (!h.target || !in) return answer("X1:u", outLen);                              // u: it never reached Rexx
    // the instance ended, and nested in a request of this thread: in that
    // request's context (see requesting; its instance is the one ooRexx runs
    // the last UNINITs in, not the ended one); else attached to the instance
    bool nested = false;
    if (requesting)
    {
        std::lock_guard<std::mutex> g(tablesLock);
        nested = instanceEnding(in);
    }
    if (nested) tc = requesting;
    else if (!in->AttachThread(&tc)) return answer("X1:u", outLen);
    auto done = [&] { if (!nested) tc->DetachThread(); };
    drainDead(tc);
    if (h.peer)                                     // an override: a crossing (its Rexx object held by Rexx again)
    {
        RexxObjectPtr o = peerCrossing(tc, id);
        if (o == NULLOBJECT) { done(); return answer("X1:u", outLen); }
        h.target = o;
    }
    std::string out;
    char tag; std::string payload;
    parseRecord(req, (size_t)len, 0, tag, payload);
    RexxObjectPtr args = decode(tc, tag, payload);
    RexxObjectPtr r = NULLOBJECT;
    // (a condition other than SYNTAX that the method lets out reaches here
    // since ooRexx r13320, #2123, with what the method returned: RAISE ...
    // RETURN value, kept with it)
    if (!tc->CheckCondition()) r = tc->SendMessage(h.target, h.message.c_str(), (RexxArrayObject)args);
    if (!tc->CheckCondition())
    {
        if (r == NULLOBJECT) record(out, 'V', "");
        else if (!encode(tc, r, out, nullptr, true)) out.clear();
    }
    if (tc->CheckCondition()) out = (flags & 1) ? reportCondition(tc) : conditionRecord(tc, r);
    if (nested)                                     // (the outer method's context: no local references left behind)
    {
        if (args) tc->ReleaseLocalReference(args);
        if (r) tc->ReleaseLocalReference(r);
    }
    done();
    return answer(out, outLen);
}

RexxMethodEntry rexxnet_methods[] = {
    REXX_METHOD(net_unknown, net_unknown),
    REXX_METHOD(net_command, net_command),
    REXX_METHOD(net_uninit, net_uninit),
    REXX_LAST_METHOD() };
RexxRoutineEntry rexxnet_routines[] = {
    REXX_TYPED_ROUTINE(NetRequest, NetRequest),
    REXX_TYPED_ROUTINE(NetHandlerNew, NetHandlerNew),
    REXX_TYPED_ROUTINE(NetHandlerOf, NetHandlerOf),
    REXX_TYPED_ROUTINE(NetHandlerDrop, NetHandlerDrop),
    REXX_TYPED_ROUTINE(NetPeerArm, NetPeerArm),
    REXX_TYPED_ROUTINE(NetPeerUninit, NetPeerUninit),
    REXX_TYPED_ROUTINE(NetInstanceEnding, NetInstanceEnding),
    REXX_TYPED_ROUTINE(NetInstanceId, NetInstanceId),
    REXX_LAST_ROUTINE() };
RexxPackageEntry rexxnet_package_entry = {
    STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0, "rexxnet", "0.1",
    nullptr, nullptr, rexxnet_routines, rexxnet_methods };
OOREXX_GET_PACKAGE(rexxnet);
