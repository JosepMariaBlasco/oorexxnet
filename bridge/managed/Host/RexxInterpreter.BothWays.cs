// Both ways in one process, phase C (notes/rexx-from-net-design.md, "Phase C:
// built"): .NET objects to Rexx as .NetObjects (net.cls loaded on first
// need), .NetObjects back as their .NET objects, Rexx objects handed to .NET
// code called from Rexx (requests of rexxnet: X, G), guest mode
// (RexxInterpreter.Current), and a Rexx error that .NET code called from Rexx
// lets through, raised again in Rexx as it was.
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

namespace Rexx.Net;

public sealed unsafe partial class RexxInterpreter
{
    // ------------------------------------------------------------ guest mode

    /// The interpreter instance whose Rexx code is calling .NET on this
    /// thread: in .NET code called from Rexx (a .NET method, a command
    /// handler), the caller's; null when no Rexx code waits on this thread.
    /// When ooRexx is the host (rexx prog.rex), this is how .NET code reaches
    /// it: an instance made by ooRexx, which Dispose does not end.
    public static RexxInterpreter? Current
    {
        get { var f = frames; return f is { Count: > 0 } ? f[^1].Rexx : null; }
    }

    /// Whether ooRexx made this instance (guest mode) rather than Create.
    public bool IsGuest => guest;

    /// The RexxInterpreter of a thread context handed over by Rexx: one of
    /// ours, or a guest made now (the first request of an instance ooRexx
    /// made).
    internal static RexxInterpreter ForContext(nint tc)
    {
        var c = new Ctx(tc);
        nint ip = c.Instance;
        if (instances.TryGetValue(ip, out var r)) return r;
        lock (instances)
        {
            if (instances.TryGetValue(ip, out r)) return r;
            r = new RexxInterpreter(ip);
            nint sc = c.FindClass("STRING");
            r.stringClass = c.Global(sc);
            c.ReleaseLocal(sc);
            instances[ip] = r;
            return r;
        }
    }

    // ------------------------------------------------- Rexx objects in requests

    /// A Rexx object of a request (X): its proxy. The pointer is valid while
    /// the request runs (the caller's arguments hold it); the proxy takes its
    /// own global reference.
    internal static RexxObject FromRequest(nint p)
    {
        var f = frames;
        if (f is not { Count: > 0 }) throw new BridgeException("a Rexx object outside a request from Rexx");
        var top = f[^1];
        return (RexxObject)top.Rexx.Wrap(new Ctx(top.Tc), p, borrowed: true)!;
    }

    /// FromRequest for an object known to be plain (Conv.AdoptRexxPlain).
    internal static RexxObject FromRequestPlain(nint p)
    {
        var f = frames;
        if (f is not { Count: > 0 }) throw new BridgeException("a Rexx object outside a request from Rexx");
        var top = f[^1];
        return top.Rexx.WrapPlain(new Ctx(top.Tc), p);
    }

    /// A callback's result (G): a Rexx object whose global reference is
    /// handed over (rexxnet took it before detaching its thread). No context
    /// here: a plain RexxObject.
    internal static RexxObject Adopt(nint p, nint instance)
    {
        if (!instances.TryGetValue(instance, out var r))
            throw new BridgeException("a Rexx object of an unknown interpreter instance");
        lock (r.objects)
        {
            if (r.objects.TryGetValue(p, out var e) && e.Proxy != null && e.Proxy.TryGetTarget(out var live) && !live.Disposed)
            {
                r.extra.Enqueue(p);                        // it has ours already
                return live;
            }
            if (e == null) r.objects[p] = e = new Entry();
            if (e.Count++ > 0) r.extra.Enqueue(p);
            var proxy = new RexxObject(r, p);
            e.Proxy = new WeakReference<RexxObject>(proxy);
            return proxy;
        }
    }

    /// A Rexx object going to Rexx in a response or a callback's arguments
    /// (X): its pointer. Inside a request, also held by a local reference of
    /// the request's context (an Array holding it), so that it outlives its
    /// proxy until Rexx has it; elsewhere (a callback from another thread)
    /// the caller keeps the proxy alive during the call.
    internal static string Lend(RexxObject o)
    {
        nint p = o.Live;
        var f = frames;
        if (f is { Count: > 0 })
        {
            var c = new Ctx(f[^1].Tc);
            nint a = c.NewArray(1);                        // a local reference of the request: freed when it returns
            c.ArrayPut(a, p, 1);
        }
        return ((nuint)p).ToString();
    }

    /// Raises e (a Rexx condition that ended a call from .NET) again in the
    /// Rexx code that called .NET on this thread: recorded on its context and
    /// raised when the native call returns (never an unwinding API: see
    /// "Phase B: built", item 4). False when no Rexx code waits here.
    /// Whether the last RaiseAgain on this thread halted it (a HALT): the
    /// native call then answers .nil, so that CALL ON HALT resumes the clause.
    [ThreadStatic] internal static bool LastWasHalt;

    internal static bool RaiseAgain(RexxException e)
    {
        LastWasHalt = false;
        var f = frames;
        if (f is not { Count: > 0 }) return false;
        var top = f[^1];
        var c = new Ctx(top.Tc);
        nint additional = 0, description = 0, result = 0;
        if (e.Condition != null && !e.Condition.Disposed)
        {
            try
            {
                additional = Live(c, e.Condition["ADDITIONAL"]);
                if (e.Condition["DESCRIPTION"] is RexxString d) description = c.Str(d.Value);
                result = Live(c, e.Condition["RESULT"]);           // RAISE ... RETURN/EXIT result
            }
            catch (Exception) { }
        }
        if (e.Code == "4.1")
        {
            // a HALT the Rexx code did not trap (ooRexx makes it SYNTAX 4.1):
            // a HALT again, by halting the thread, not RaiseCondition (an
            // untrapped HALT raised so is ignored): see rexxnet's raiseHeld
            if (additional != 0) c.ReleaseLocal(additional);
            if (description != 0) c.ReleaseLocal(description);
            if (result != 0) c.ReleaseLocal(result);
            c.HaltThread();
            LastWasHalt = true;
            return true;
        }
        if (e.Code.Length > 0)
        {
            var parts = e.Code.Split('.');
            long code = long.Parse(parts[0]) * 1000 + (parts.Length > 1 ? long.Parse(parts[1]) : 0);
            if (additional == 0) additional = c.NewArray(0);
            // the DESCRIPTION is lost: no API raises a SYNTAX with one, and
            // RaiseCondition("SYNTAX", ...) would crash the process (ooRexx
            // bug, unreported: see rexxnet.cpp's raiseHeld)
            c.RaiseException(code, additional);
        }
        else c.RaiseCondition(e.ConditionName, description, additional, result);
        return true;
    }

    // A condition object's entry as a Rexx object pointer (0 for none, .nil).
    static nint Live(Ctx c, object? v) => v switch
    {
        RexxString s => c.Str(s.Value),
        RexxObject o => o.Live,
        _ => 0,
    };

    // ------------------------------------------------------- .NET -> .NetObject

    static readonly object netGate = new();

    /// Loads net.cls (as ::requires "net.cls" would), so that Rexx code run
    /// by this host can use .net without requiring it. It happens by itself
    /// the first time a .NET object goes to Rexx. .net is in .environment:
    /// for every instance of the process.
    public void RequireNet()
    {
        using var u = Context();
        EnsureNet(u.C);
    }

    /// A .NET object as a new .NetObject (a local reference): one more Rexx
    /// proxy for its handle, released by the proxy's uninit, as in the other
    /// direction.
    nint NetProxy(Ctx c, object o)
    {
        EnsureNet(c);
        int id = Handles.Add(o);
        nint cls = o is StaticOf ? Bridge.NetTypeClass : o is Array ? Bridge.NetArrayClass : o is Enum ? Bridge.NetEnumClass : Bridge.NetObjectClass;
        nint a = c.NewArray(2), s1 = c.Str(id.ToString()), s2 = c.Str(Types.Display(o is StaticOf so ? so.Type : o.GetType()));
        c.ArrayPut(a, s1, 1); c.ArrayPut(a, s2, 2);
        c.ReleaseLocal(s1); c.ReleaseLocal(s2);
        nint p = c.Send(cls, "NEW", a);
        c.ReleaseLocal(a);
        if (p == 0 || c.CheckCondition())
        {
            Handles.Release(id);
            Check(c);
            throw new InvalidOperationException("could not make a .NetObject");
        }
        return p;
    }

    /// The .NET object of a .NetObject (a NetType: its System.Type), the
    /// bool of a .LogicalWrapper; null for any other Rexx object.
    internal object? NetOf(Ctx c, nint o)
    {
        EnsureLogical(c);
        if (Bridge.LogicalClass != 0 && c.IsInstanceOf(o, Bridge.LogicalClass))
        {
            if (o == logicalTrue) return true;
            if (o == logicalFalse) return false;
            nint empty = c.NewArray(0), v = c.Send(o, "VALUE", empty);  // (a subclass's own instances)
            c.ReleaseLocal(empty);
            if (v == 0 || c.CheckCondition()) { c.ClearCondition(); return null; }
            bool b = c.ToStr(v) == "1";
            c.ReleaseLocal(v);
            return b;
        }
        if (Bridge.NetObjectClass == 0 || !c.IsInstanceOf(o, Bridge.NetObjectClass)) return null;
        nint none = c.NewArray(0);
        nint id = c.Send(o, "NETID", none);
        c.ReleaseLocal(none);
        if (id == 0 || c.CheckCondition()) { c.ClearCondition(); return null; }
        var s = c.ToStr(id);
        c.ReleaseLocal(id);
        if (!int.TryParse(s, out int n)) return null;
        try
        {
            var net = Handles.Get(n);
            return net is StaticOf so ? so.Type : net;
        }
        catch (BridgeException) { return null; }
    }

    /// net.cls in the process, the first time a .NET object goes to Rexx from
    /// .NET (unless Rexx code loaded it first): found as Rexx finds it
    /// (::requires "net.cls"), else in REXXNET_DIR or next to Rexx.Net.dll.
    /// rexxnet is loaded first from that directory, so that ooRexx finds it
    /// there (the library has its name as soname).
    void EnsureNet(Ctx c)
    {
        if (Bridge.NetObjectClass != 0) return;
        SetUpNet(c);
        lock (netGate)
        {
            if (Bridge.NetObjectClass != 0) return;
            string? dir = BridgeDirectory();
            if (dir != null) PreloadRexxNet(dir);
            RexxException? why = null;
            nint Load(string name)
            {
                nint p = c.LoadPackage(name);
                if (!c.CheckCondition()) return p;
                why = RexxException.FromPending(this, c);       // (cleared)
                if (p != 0) c.ReleaseLocal(p);
                return 0;
            }
            nint pkg = Load("net.cls");
            if (pkg == 0 && dir != null && File.Exists(Path.Combine(dir, "net.cls"))) pkg = Load(Path.Combine(dir, "net.cls"));
            if (pkg == 0)
                throw new InvalidOperationException(
                    "a .NET object cannot go to Rexx: net.cls and rexxnet are needed (in ooRexx's search path, in " +
                    "REXXNET_DIR, or next to Rexx.Net.dll)" + (why != null ? ": " + why.Message : ""), why);
            nint k1 = c.FindPackageClass(pkg, "NETOBJECT"), k2 = c.FindPackageClass(pkg, "NETTYPE"),
                 k3 = c.FindPackageClass(pkg, "NETARRAY"), k4 = c.FindPackageClass(pkg, "NETENUM"),
                 k5 = c.FindPackageClass(pkg, "LOGICALWRAPPER");           // (required by net.cls)
            if (k1 == 0 || k2 == 0 || k3 == 0 || k4 == 0) throw new InvalidOperationException("net.cls has no NetObject class");
            Bridge.SetClasses(c.Global(k1), c.Global(k2), c.Global(k3), c.Global(k4), k5 != 0 ? c.Global(k5) : 0);
            c.ReleaseLocal(k1); c.ReleaseLocal(k2); c.ReleaseLocal(k3); c.ReleaseLocal(k4); c.ReleaseLocal(pkg);
            if (k5 != 0) c.ReleaseLocal(k5);
        }
    }

    // ------------------------------------------------------ .net from the start

    static bool netSetUp;
    static readonly Dictionary<string, nint> builtIn = new();   // net.cls and CLR.CLS: global references

    /// One of the packages built into this assembly, loaded once for the
    /// process under its name (LoadPackageFromData), so that ::requires finds
    /// it without a file; 0 if it is not built in. A global reference.
    nint BuiltIn(Ctx c, string name)
    {
        lock (netGate)
        {
            if (builtIn.TryGetValue(name, out nint kept)) return kept;
            using var s = typeof(Bridge).Assembly.GetManifestResourceStream(name);
            if (s == null) return 0;
            nint p = c.LoadPackageFromData(name, new StreamReader(s).ReadToEnd());
            if (c.CheckCondition())
            {
                var e = RexxException.FromPending(this, c);           // (cleared)
                if (p != 0) c.ReleaseLocal(p);
                throw new InvalidOperationException($"the built-in {name} could not be loaded: {e.Message}", e);
            }
            if (p == 0) return 0;
            // kept for the process: ooRexx forgets a package loaded from
            // data when nothing refers to it (a collection, as when another
            // instance terminates), and ::requires would then look for a file
            // (ooRexx bug #2108; patch: patches/oorexx/package-from-data-cache.diff)
            nint g = c.Global(p);
            c.ReleaseLocal(p);
            builtIn[name] = g;
            return g;
        }
    }

    static nint logicalTrue, logicalFalse;
    static bool logicalSought;

    /// .LogicalWrapper (ooRexx's logicalwrapper.cls) and its two instances,
    /// for .NET's bools: the one net.cls required (rexxnet or SetUpNet said
    /// which), else logicalwrapper.cls loaded now (ooRexx's search path).
    /// Sought once per process.
    void EnsureLogical(Ctx c)
    {
        if (Volatile.Read(ref logicalSought)) return;
        lock (netGate)
        {
            if (logicalSought) return;
            nint k = Bridge.LogicalClass, local = 0;
            if (k == 0)
            {
                nint p = c.LoadPackage("logicalwrapper.cls");
                if (c.CheckCondition()) c.ClearCondition();
                else if (p != 0) k = local = c.FindPackageClass(p, "LOGICALWRAPPER");
                if (p != 0) c.ReleaseLocal(p);
                if (k != 0) Bridge.LogicalClass = c.Global(k);
            }
            if (k != 0)
            {
                nint none = c.NewArray(0);
                nint t = c.Send(k, "TRUE", none), f = c.Send(k, "FALSE", none);
                c.ReleaseLocal(none);
                if (t != 0 && f != 0 && !c.CheckCondition()) { logicalTrue = c.Global(t); logicalFalse = c.Global(f); }
                else c.ClearCondition();
                if (t != 0) c.ReleaseLocal(t);
                if (f != 0) c.ReleaseLocal(f);
            }
            if (local != 0) c.ReleaseLocal(local);
            Volatile.Write(ref logicalSought, true);
        }
    }

    /// A bool as a Rexx object: .LogicalWrapper~true or ~false (.true and
    /// .false if logicalwrapper.cls cannot be had).
    internal nint BoolToRexx(Ctx c, bool b)
    {
        EnsureLogical(c);
        nint o = b ? logicalTrue : logicalFalse;
        return o != 0 ? o : b ? c.True : c.False;
    }

    /// Host mode, once per process (RexxOptions.Net, or the first .NET object
    /// going to Rexx): the native half, rexxnet, is looked for as the
    /// application's own native library (a NuGet package's
    /// runtimes/<rid>/native), then in REXXNET_DIR or next to Rexx.Net.dll;
    /// it gets the managed entry points directly (RexxNetRegister: no hostfxr,
    /// no runtimeconfig), and ooRexx gets it as the library "rexxnet"
    /// (RegisterLibrary: no search). net.cls and CLR.CLS, built into this
    /// assembly, are then loaded under their names (LoadPackageFromData), so
    /// that ::requires "net.cls" finds them without a file, ahead of any copy
    /// on disk (ooRexx looks for a loaded name first). Nothing is done when
    /// rexxnet is running already (ooRexx is the host, or Rexx code got there
    /// first): net.cls is then the one Rexx found. Without rexxnet, nothing
    /// either: .NET objects cannot go to Rexx (EnsureNet says so).
    void SetUpNet(Ctx c)
    {
        lock (netGate)
        {
            if (netSetUp) return;
            netSetUp = true;
            if (Callbacks.Started || Bridge.NetObjectClass != 0) return;
            nint lib = LoadRexxNet();
            if (lib == 0 ||
                !NativeLibrary.TryGetExport(lib, "RexxNetRegister", out nint register) ||
                !NativeLibrary.TryGetExport(lib, "RexxGetPackage", out nint getPackage)) return;
            ((delegate* unmanaged<nint, nint, nint, nint, nint, void>)register)(
                (nint)(delegate* unmanaged<nint, byte*, int, int*, byte*>)&Bridge.Request,
                (nint)(delegate* unmanaged<byte*, void>)&Bridge.Free,
                (nint)(delegate* unmanaged<int, void>)&Bridge.Release,
                (nint)(delegate* unmanaged<nint, nint, nint, nint, nint, void>)&Bridge.Init,
                (nint)(delegate* unmanaged<nint, nint, nint, nint, nint, void>)&Bridge.Classes);
            if (!Callbacks.Started) return;          // rexxnet had started a runtime of its own first
            c.RegisterLibrary("rexxnet", ((delegate* unmanaged<nint>)getPackage)());
            // net.cls requires logicalwrapper.cls: ooRexx's, found in its search path
            nint net = BuiltIn(c, "net.cls");
            BuiltIn(c, "CLR.CLS");
            if (net == 0) return;
            nint k1 = c.FindPackageClass(net, "NETOBJECT"), k2 = c.FindPackageClass(net, "NETTYPE"),
                 k3 = c.FindPackageClass(net, "NETARRAY"), k4 = c.FindPackageClass(net, "NETENUM"),
                 k5 = c.FindPackageClass(net, "LOGICALWRAPPER");
            if (k1 != 0 && k2 != 0 && k3 != 0 && k4 != 0)
                Bridge.SetClasses(c.Global(k1), c.Global(k2), c.Global(k3), c.Global(k4), k5 != 0 ? c.Global(k5) : 0);
            c.ReleaseLocal(k1); c.ReleaseLocal(k2); c.ReleaseLocal(k3); c.ReleaseLocal(k4);
            if (k5 != 0) c.ReleaseLocal(k5);
        }
    }

    /// rexxnet, loaded: as the application's native library, else from
    /// BridgeDirectory(); 0 if not found.
    static nint LoadRexxNet()
    {
        if (NativeLibrary.TryLoad("rexxnet", typeof(Bridge).Assembly, null, out nint h)) return h;
        string? dir = BridgeDirectory();
        if (dir == null) return 0;
        string path = Path.Combine(dir, NativeName);
        return File.Exists(path) && NativeLibrary.TryLoad(path, out h) ? h : 0;
    }

    static string NativeName =>
        OperatingSystem.IsWindows() ? "rexxnet.dll" : OperatingSystem.IsMacOS() ? "librexxnet.dylib" : "librexxnet.so";

    static string? BridgeDirectory()
    {
        var env = System.Environment.GetEnvironmentVariable("REXXNET_DIR");
        if (!string.IsNullOrEmpty(env) && Directory.Exists(env)) return env;
        var loc = typeof(Bridge).Assembly.Location;
        return string.IsNullOrEmpty(loc) ? null : Path.GetDirectoryName(loc);
    }

    static void PreloadRexxNet(string dir)
    {
        string name = OperatingSystem.IsWindows() ? "rexxnet.dll" : OperatingSystem.IsMacOS() ? "librexxnet.dylib" : "librexxnet.so";
        string path = Path.Combine(dir, name);
        if (File.Exists(path)) NativeLibrary.TryLoad(path, out _);
    }
}
