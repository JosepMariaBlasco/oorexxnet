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
    internal static bool RaiseAgain(RexxException e)
    {
        var f = frames;
        if (f is not { Count: > 0 }) return false;
        var top = f[^1];
        var c = new Ctx(top.Tc);
        nint additional = 0, description = 0;
        if (e.Condition != null && !e.Condition.Disposed)
        {
            try
            {
                if (e.Condition["ADDITIONAL"] is RexxObject a && a is not RexxString) additional = a.Live;
                if (e.Condition["DESCRIPTION"] is RexxString d) description = c.Str(d.Value);
            }
            catch (Exception) { }
        }
        if (e.Code.Length > 0)
        {
            var parts = e.Code.Split('.');
            long code = long.Parse(parts[0]) * 1000 + (parts.Length > 1 ? long.Parse(parts[1]) : 0);
            if (additional == 0) additional = c.NewArray(0);
            c.RaiseException(code, additional);
        }
        else c.RaiseCondition(e.ConditionName, description, additional, 0);
        return true;
    }

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

    /// The .NET object of a .NetObject (a NetType: its System.Type); null
    /// for any other Rexx object.
    internal object? NetOf(Ctx c, nint o)
    {
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
                 k3 = c.FindPackageClass(pkg, "NETARRAY"), k4 = c.FindPackageClass(pkg, "NETENUM");
            if (k1 == 0 || k2 == 0 || k3 == 0 || k4 == 0) throw new InvalidOperationException("net.cls has no NetObject class");
            Bridge.SetClasses(c.Global(k1), c.Global(k2), c.Global(k3), c.Global(k4));
            c.ReleaseLocal(k1); c.ReleaseLocal(k2); c.ReleaseLocal(k3); c.ReleaseLocal(k4); c.ReleaseLocal(pkg);
        }
    }

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
