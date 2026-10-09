// .NET -> ooRexx, phase A (notes/rexx-from-net-design.md): an interpreter
// instance, threads, lifetime and values.
//
// Threads. Any .NET thread may call Rexx. A call uses the context this
// thread already has for the instance (one handed over by Rexx: a request of
// rexxnet, a command handler; one of Enter(); the creating thread's own: the
// frames on a thread-static stack, innermost first); otherwise it attaches
// the thread (AttachThread), runs, and detaches. One Rexx thread runs at a
// time (the interpreter's lock).
//
// Guest mode (phase C): when ooRexx is the host (rexx prog.rex) and its code
// calls .NET, the instance is not one of ours; a RexxInterpreter is made for
// it on its first request (RexxInterpreter.Current), and is never disposed.
//
// Lifetime. A RexxObject holds one global reference to its Rexx object;
// Dispose releases it, the finalizer queues the release (no context there),
// and queued releases go at the next call and at Dispose of the instance.
// One proxy per Rexx object while it lives (identity): a table from the
// object's address (ooRexx does not move objects) to a weak reference to
// its proxy; the table counts proxies, so a dead proxy's queued release and
// a new proxy's reference never mix.
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Threading;

namespace Rexx.Net;

/// Options of RexxInterpreter.Create (the API's own instance options).
public sealed class RexxOptions
{
    /// The initial ADDRESS environment.
    public string? InitialAddress { get; set; }
    /// Where external routines and ::requires files are searched for.
    public string? ExternalCallPath { get; set; }
    /// The extensions tried on external calls (".rex,.cls").
    public string? ExternalCallExtensions { get; set; }
    /// Native libraries loaded at start (their package's routines and methods).
    public IList<string> LoadLibraries { get; } = new List<string>();
    /// Where the Rexx code's output, error output (trace included) and input
    /// go (RexxInterpreter.Output, Error, Input): null, the process's own.
    public System.IO.TextWriter? Output { get; set; }
    public System.IO.TextWriter? Error { get; set; }
    public System.IO.TextReader? Input { get; set; }
    /// Rexx code may use .NET from the start: net.cls and CLR.CLS (built into
    /// Rexx.Net) and the native library rexxnet are registered with ooRexx
    /// when the instance is created, so ::requires "net.cls" needs no file.
    /// False: only when a .NET object first goes to Rexx.
    public bool Net { get; set; } = true;
}

/// An argument left out (arg(n, "O") is true in Rexx).
public static class RexxValue
{
    public static readonly object Omitted = new OmittedValue();
    sealed class OmittedValue { public override string ToString() => "(omitted)"; }
}

/// A thread's hold on an instance (Enter): calls on this thread use it
/// instead of attaching each time.
public sealed class RexxScope : IDisposable
{
    readonly RexxInterpreter? rexx;
    readonly int thread = System.Environment.CurrentManagedThreadId;
    internal RexxScope(RexxInterpreter? r) { rexx = r; }
    public void Dispose()
    {
        if (rexx == null) return;
        if (System.Environment.CurrentManagedThreadId != thread)
            throw new InvalidOperationException("a RexxScope ends on the thread that entered it");
        rexx.Leave();
    }
}

public sealed unsafe partial class RexxInterpreter : IDisposable
{
    internal readonly Inst inst;
    readonly nint home;                         // the creating thread's context
    readonly int homeThread;
    readonly bool guest;                        // an instance ooRexx made (guest mode): not ours to end
    volatile bool disposed;
    nint stringClass;                           // .String (a global reference)

    RexxInterpreter(nint instance, nint context)
    {
        inst = new Inst(instance);
        home = context;
        homeThread = System.Environment.CurrentManagedThreadId;
    }

    RexxInterpreter(nint instance)               // guest mode: no home thread
    {
        inst = new Inst(instance);
        homeThread = -1;
        guest = true;
    }

    // ------------------------------------------------------------- creation

    /// A new interpreter instance (RexxCreateInterpreter). This thread is
    /// attached to it until Dispose, which must run on this thread.
    public static RexxInterpreter Create(RexxOptions? options = null)
    {
        var strings = new List<nint>();
        try
        {
            var opts = new List<RexxOptionData>();
            void Add(string name, string value)
            {
                nint n = Marshal.StringToCoTaskMemUTF8(name), v = Marshal.StringToCoTaskMemUTF8(value);
                strings.Add(n); strings.Add(v);
                opts.Add(new RexxOptionData { name = n, value = v, type = Native.REXX_VALUE_CSTRING });
            }
            if (options?.InitialAddress != null) Add("InitialAddress", options.InitialAddress);
            if (options?.ExternalCallPath != null) Add("ExternalCallPath", options.ExternalCallPath);
            if (options?.ExternalCallExtensions != null) Add("ExternalCallPathExt", options.ExternalCallExtensions);
            if (options != null) foreach (var l in options.LoadLibraries) Add("LoadRequiredLibrary", l);
            opts.Add(default);                                   // the end: a null name
            var arr = opts.ToArray();
            nint ip, cp;
            int rc;
            try
            {
                fixed (RexxOptionData* p = arr) rc = Native.RexxCreateInterpreter(out ip, out cp, p);
            }
            catch (DllNotFoundException e)
            {
                throw new InvalidOperationException("ooRexx 5 is needed and was not found (librexx: set REXX_HOME to its installation)", e);
            }
            if (rc == 0 || ip == 0) throw new InvalidOperationException("ooRexx could not create an interpreter instance");
            var r = new RexxInterpreter(ip, cp);
            var c = new Ctx(cp);
            if (r.inst.Version < Native.InstanceInterfaceVersion || c.Version < Native.ThreadInterfaceVersion)
            {
                r.inst.Terminate();
                throw new InvalidOperationException($"ooRexx 5.0 or later is needed (this one's API: instance {r.inst.Version}, thread {c.Version})");
            }
            nint sc = c.FindClass("STRING");
            r.stringClass = c.Global(sc);
            c.ReleaseLocal(sc);
            instances[ip] = r;
            if (options?.Net ?? true) r.SetUpNet(c);
            if (options?.Output != null) r.Output = options.Output;
            if (options?.Error != null) r.Error = options.Error;
            if (options?.Input != null) r.Input = options.Input;
            return r;
        }
        finally { foreach (var s in strings) Marshal.FreeCoTaskMem(s); }
    }

    /// The interpreter's version, "5.3.0".
    public string Version
    {
        get { long v = inst.InterpreterVersion; return $"{(v >> 16) & 0xff}.{(v >> 8) & 0xff}.{v & 0xff}"; }
    }

    /// The language level, "6.05".
    public string LanguageLevel
    {
        get { long v = inst.LanguageLevel; return $"{(v >> 8) & 0xff}.{v & 0xff:00}"; }
    }

    // -------------------------------------------------------------- threads

    readonly struct Frame
    {
        public readonly RexxInterpreter Rexx; public readonly nint Tc;
        public Frame(RexxInterpreter r, nint tc) { Rexx = r; Tc = tc; }
    }
    [ThreadStatic] static List<Frame>? frames;

    /// A context for this thread, for one operation.
    internal readonly struct Use : IDisposable
    {
        public readonly Ctx C;
        readonly RexxInterpreter? attachedBy;
        internal Use(Ctx c, RexxInterpreter? attached) { C = c; attachedBy = attached; }
        public void Dispose() => attachedBy?.Leave();
    }

    internal Use Context()
    {
        if (disposed) throw new ObjectDisposedException(nameof(RexxInterpreter));
        var f = frames;
        if (f != null)
            for (int i = f.Count - 1; i >= 0; i--)
                if (f[i].Rexx == this) { var c0 = new Ctx(f[i].Tc); Flush(c0); return new Use(c0, null); }
        if (System.Environment.CurrentManagedThreadId == homeThread) { var h = new Ctx(home); Flush(h); return new Use(h, null); }
        var c = Attach();
        Flush(c);
        return new Use(c, this);
    }

    Ctx Attach()
    {
        nint tc = inst.Attach();
        if (tc == 0) throw new InvalidOperationException("this thread could not attach to the Rexx interpreter");
        (frames ??= new List<Frame>()).Add(new Frame(this, tc));
        return new Ctx(tc);
    }

    internal void Leave()
    {
        var f = frames!;
        for (int i = f.Count - 1; i >= 0; i--)
            if (f[i].Rexx == this)
            {
                var c = new Ctx(f[i].Tc);
                f.RemoveAt(i);
                Flush(c);
                c.Detach();
                return;
            }
    }

    /// A thread context handed to .NET code by Rexx (a command handler; later
    /// rexxnet's calls in guest mode): calls on this thread use it until
    /// PopFrame.
    internal void PushFrame(nint tc) => (frames ??= new List<Frame>()).Add(new Frame(this, tc));

    internal void PopFrame(nint tc)
    {
        var f = frames!;
        for (int i = f.Count - 1; i >= 0; i--)
            if (f[i].Rexx == this && f[i].Tc == tc) { f.RemoveAt(i); return; }
    }

    /// Keeps this thread attached until the scope ends (for a batch of
    /// calls: attaching costs ~20 µs, a message ~1 µs). On the creating
    /// thread, or a thread already inside Rexx, nothing to do.
    public RexxScope Enter()
    {
        if (disposed) throw new ObjectDisposedException(nameof(RexxInterpreter));
        if (System.Environment.CurrentManagedThreadId == homeThread) return new RexxScope(null);
        var f = frames;
        if (f != null) foreach (var x in f) if (x.Rexx == this) return new RexxScope(null);
        Attach();
        return new RexxScope(this);
    }

    /// Stops every Rexx thread of the instance (a HALT condition: RexxException).
    public void Halt() { if (!disposed) inst.Halt(); }

    /// Rexx's TRACE for the whole instance.
    public bool Trace { set { if (!disposed) inst.SetTrace(value); } }

    // ------------------------------------------------------------- lifetime

    sealed class Entry { public WeakReference<RexxObject>? Proxy; public int Count; }
    readonly Dictionary<nint, Entry> objects = new();
    readonly ConcurrentQueue<nint> pending = new();

    internal bool IsDisposed => disposed;

    /// One proxy fewer for p (Dispose, or a finalizer's queued release).
    internal void Drop(Ctx c, nint p)
    {
        bool release = false;
        lock (objects)
            if (objects.TryGetValue(p, out var e) && --e.Count <= 0) { objects.Remove(p); release = true; }
        if (release) c.ReleaseGlobal(p);
    }

    internal void Queue(nint p) { if (!disposed) pending.Enqueue(p); }

    void Flush(Ctx c)
    {
        while (pending.TryDequeue(out var p)) Drop(c, p);
        while (extra.TryDequeue(out var p)) c.ReleaseGlobal(p);
    }

    // Global references handed over (a callback's result, G) for an object
    // that already had one: released at the next call.
    readonly ConcurrentQueue<nint> extra = new();

    /// Proxies alive or awaiting release (diagnostics, tests).
    public int ObjectCount { get { lock (objects) return objects.Count; } }

    /// Ends the instance (Terminate). On the thread that created it. An
    /// instance that ooRexx made (guest mode, RexxInterpreter.Current) is not
    /// ended: Dispose does nothing.
    public void Dispose()
    {
        if (disposed || guest) return;
        if (System.Environment.CurrentManagedThreadId != homeThread)
            throw new InvalidOperationException("a RexxInterpreter is disposed on the thread that created it");
        Flush(new Ctx(home));
        disposed = true;
        lock (objects) objects.Clear();
        inst.Terminate();
        instances.TryRemove(inst.P, out _);
    }

    // --------------------------------------------------------------- values

    /// A Rexx object (a local reference of c) as a .NET value: .nil or none
    /// -> null; a String -> RexxString; anything else -> its proxy (for a
    /// .NetObject, a proxy that knows its .NET object: NetValue). Borrowed:
    /// o is not a local reference of ours (a request's argument): not released.
    internal object? Wrap(Ctx c, nint o, bool borrowed = false)
    {
        if (o == 0 || o == c.Nil) return null;
        // A String: IsString knows only the class String itself; numbers made
        // by arithmetic are instances of an internal subclass (RexxInteger,
        // RexxNumberString), and so is anything subclassing .String.
        if (c.IsString(o) || c.IsInstanceOf(o, stringClass))
        {
            var s = new RexxString(c.ToStr(o), this);          // (StringData wants a real String: ObjectToString first)
            if (!borrowed) c.ReleaseLocal(o);
            return s;
        }
        lock (objects)
        {
            if (objects.TryGetValue(o, out var e) && e.Proxy != null && e.Proxy.TryGetTarget(out var live) && !live.Disposed)
            {
                if (!borrowed) c.ReleaseLocal(o);
                return live;
            }
        }
        RexxObject proxy = c.IsRoutine(o) ? new RexxRoutine(this, o)
                         : c.IsOfType(o, "CLASS") ? new RexxClass(this, o)
                         : c.IsOfType(o, "PACKAGE") ? new RexxPackage(this, o)
                         : new RexxObject(this, o) { Net = NetOf(c, o) };
        bool request;
        lock (objects)
        {
            if (!objects.TryGetValue(o, out var e)) objects[o] = e = new Entry();
            request = e.Count++ == 0;
            e.Proxy = new WeakReference<RexxObject>(proxy);
        }
        if (request) c.Global(o);
        if (!borrowed) c.ReleaseLocal(o);
        return proxy;
    }

    internal RexxObject? WrapObject(Ctx c, nint o) => (RexxObject?)Wrap(c, o);

    static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

    /// A .NET value as a Rexx object.
    internal nint ToRexx(Ctx c, object? v)
    {
        switch (v)
        {
            case null: return c.Nil;
            case RexxString s: return c.Str(s.Value);
            case RexxObject r:
                if (r.Interpreter != this) throw new ArgumentException("a Rexx object of another interpreter instance");
                return r.Live;
            case string s: return c.Str(s);
            case char ch: return c.Str(ch.ToString());
            case bool b: return b ? c.True : c.False;
            case double d: return c.Str(d.ToString("R", Inv));
            case float f: return c.Str(f.ToString("R", Inv));
            case decimal m: return c.Str(m.ToString(Inv));
            case sbyte or byte or short or ushort or int or uint or long or ulong or nint or nuint or System.Numerics.BigInteger:
                return c.Str(Convert.ToString(v, Inv)!);
        }
        if (ReferenceEquals(v, RexxValue.Omitted)) throw new ArgumentException("RexxValue.Omitted is only for arguments");
        return NetProxy(c, v);                              // any other .NET object: a .NetObject, by reference
    }

    /// The arguments of a call as a Rexx Array (RexxValue.Omitted: left
    /// out). The caller releases the Array (Done) after the call. Local
    /// references matter: the creating thread's context lives as long as the
    /// instance, and every local reference left there is a leak that also
    /// makes the next releases slower.
    internal nint Args(Ctx c, object?[]? args)
    {
        int n = args?.Length ?? 0;
        nint a = c.NewArray(n);
        for (int i = 0; i < n; i++)
            if (!ReferenceEquals(args![i], RexxValue.Omitted)) Put(c, a, args[i], i + 1);
        return a;
    }

    /// a[index] = v converted; the new local reference released at once (the
    /// Array keeps the object alive).
    internal void Put(Ctx c, nint a, object? v, int index)
    {
        nint x = ToRexx(c, v);
        c.ArrayPut(a, x, index);
        if (IsNewLocal(v)) c.ReleaseLocal(x);
    }

    /// Whether ToRexx(v) made a new local reference (a string), rather than
    /// giving a constant (.nil, .true, .false) or a proxy's global reference.
    internal static bool IsNewLocal(object? v) => v is not null and not bool && (v is RexxString || v is not RexxObject);

    /// Throws the pending condition, if any.
    internal void Check(Ctx c)
    {
        if (c.CheckCondition()) throw RexxException.FromPending(this, c);
    }

    // ----------------------------------------------------------- operations

    /// Runs source as a routine (use arg, return) with args; its result.
    public RexxObject? Run(string source, params object?[] args) => (RexxObject?)RunRaw(source, args);

    /// Run, its result converted (Run<int>, Run<string>...).
    public T Run<T>(string source, params object?[] args) => RexxConvert.To<T>(RunRaw(source, args));

    object? RunRaw(string source, object?[] args)
    {
        using var u = Context();
        var c = u.C;
        nint r = c.NewRoutine("RexxInterpreter.Run", source);
        Check(c);
        nint a = Args(c, args);
        nint result = c.CallRoutine(r, a);
        c.ReleaseLocal(a);
        c.ReleaseLocal(r);
        Check(c);
        return Wrap(c, result);
    }

    /// A program file run with args (CallProgram); its result.
    public RexxObject? RunFile(string path, params object?[] args)
    {
        using var u = Context();
        var c = u.C;
        nint a = Args(c, args);
        nint result = c.CallProgram(path, a);
        c.ReleaseLocal(a);
        Check(c);
        return (RexxObject?)Wrap(c, result);
    }

    /// Source as a routine, to call many times.
    public RexxRoutine Compile(string name, string source)
    {
        using var u = Context();
        var c = u.C;
        nint r = c.NewRoutine(name, source);
        Check(c);
        return (RexxRoutine)Wrap(c, r)!;
    }

    /// A package from a file (::requires as Rexx does it).
    public RexxPackage LoadPackage(string path)
    {
        using var u = Context();
        var c = u.C;
        nint p = c.LoadPackage(path);
        Check(c);
        if (p == 0) throw new RexxException($"cannot load the package {path}", null, "SYNTAX", "", 0, "", path, 0, "", 0);
        return (RexxPackage)Wrap(c, p)!;
    }

    /// A package from source, under a name.
    public RexxPackage LoadPackage(string name, string source)
    {
        using var u = Context();
        var c = u.C;
        nint p = c.LoadPackageFromData(name, source);
        Check(c);
        return (RexxPackage)Wrap(c, p)!;
    }

    /// A class by name, as Rexx finds .Name (the environment); null if none.
    public RexxClass? FindClass(string name)
    {
        using var u = Context();
        var c = u.C;
        nint k = c.FindClass(name.ToUpperInvariant());
        Check(c);
        return Wrap(c, k) as RexxClass;
    }

    /// .environment and .local.
    public RexxObject Environment { get { using var u = Context(); return (RexxObject)Wrap(u.C, u.C.GlobalEnvironment)!; } }
    public RexxObject Local { get { using var u = Context(); return (RexxObject)Wrap(u.C, u.C.LocalEnvironment)!; } }

    /// A new Rexx Array of the items (converted as arguments are).
    public RexxObject NewArray(params object?[] items)
    {
        using var u = Context();
        var c = u.C;
        nint a = c.NewArray(items.Length);
        for (int i = 0; i < items.Length; i++) Put(c, a, items[i], i + 1);
        return (RexxObject)Wrap(c, a)!;
    }

    /// A new Rexx Directory / StringTable of the pairs.
    public RexxObject NewDirectory(IEnumerable<KeyValuePair<string, object?>> pairs) => NewCollection("DIRECTORY", pairs);
    public RexxObject NewStringTable(IEnumerable<KeyValuePair<string, object?>> pairs) => NewCollection("STRINGTABLE", pairs);

    RexxObject NewCollection(string cls, IEnumerable<KeyValuePair<string, object?>> pairs)
    {
        using var u = Context();
        var c = u.C;
        nint k = c.FindClass(cls), none = c.NewArray(0);
        nint d = c.Send(k, "NEW", none);
        c.ReleaseLocal(none); c.ReleaseLocal(k);
        Check(c);
        foreach (var kv in pairs)
        {
            nint a = c.NewArray(2);
            Put(c, a, kv.Value, 1);
            Put(c, a, kv.Key, 2);
            c.ReleaseLocal(c.Send(d, "[]=", a));
            c.ReleaseLocal(a);
            Check(c);
        }
        return (RexxObject)Wrap(c, d)!;
    }
}
