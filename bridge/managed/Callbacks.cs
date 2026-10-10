// Callbacks: Rexx methods as .NET delegates (notes/netobject-design.md,
// Callbacks; phase 3).
//
// A .NetHandler (.net~handler(object, message [, options])) comes from Rexx
// as a record H "id\toptions". Where .NET wants a delegate, it becomes a
// delegate of that exact type, built with System.Linq.Expressions, one per
// (handler, delegate type) and cached, so that adding and removing an event
// handler find the same delegate.
//
// Synchronous (default): the delegate calls the native side's callback
// (rexxnet, handed over in Init) on the calling thread; rexxnet attaches the
// thread to the interpreter (AttachThread: nested on a Rexx thread already
// inside .NET), sends the message, and answers one record: the result, V
// (none), E (a Rexx condition: RexxException) or X (no such handler / no
// interpreter: the delegate returns its type's default).
//
// A Rexx condition in a handler called on a thread where no Rexx code waits
// (not inside a Rexx -> .NET call: a timer, the thread pool, a thread the
// .NET code started) does not go up that thread, where an unhandled
// exception would end the process: rexxnet reports it on .error, as Rexx
// reports an untrapped error, and answers X (the default). With a Rexx
// caller waiting (a comparator, a GUI handler inside Application.Run) it is
// a RexxException, as above.
//
// Queued (option "queued"; "latest" implies it): the delegate queues the
// call and returns its type's default at once; a Rexx thread takes the calls
// with .net~nextEvent / .net~eventLoop. "latest" keeps at most one call of
// the handler waiting, the newest.
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Linq.Expressions;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;

namespace Rexx.Net;

/// A .NetHandler, as the managed side knows it.
public sealed class RexxHandler
{
    public readonly int Id;
    public readonly bool Queued, Latest;
    internal volatile bool Released;
    internal RexxHandler(int id, bool queued, bool latest) { Id = id; Queued = queued; Latest = latest; }
}

public static unsafe class Callbacks
{
    static delegate* unmanaged<int, int, byte*, int, int*, byte*> native;   // rexxnet's callback
    static delegate* unmanaged<byte*, void> nativeFree;

    /// rexxnet has handed its callback over (the bridge's native half is running).
    internal static bool Started => native != null;

    internal static void Init(IntPtr callback, IntPtr free)
    {
        native = (delegate* unmanaged<int, int, byte*, int, int*, byte*>)callback;
        nativeFree = (delegate* unmanaged<byte*, void>)free;
    }

    // ------------------------------------------------------------- handlers

    static readonly object gate = new();
    static readonly Dictionary<int, RexxHandler> handlers = new();
    static readonly Dictionary<(int, Type), Delegate> delegates = new();

    /// The handler of a request record H.
    public static RexxHandler HandlerOf(Rec r)
    {
        int tab = r.Text.IndexOf('\t');
        int id = int.Parse(tab < 0 ? r.Text : r.Text.Substring(0, tab));
        lock (gate)
        {
            var opts = tab < 0 ? Array.Empty<string>() : r.Text.Substring(tab + 1).Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (!handlers.TryGetValue(id, out var h))
            {
                bool latest = opts.Contains("latest");
                h = new RexxHandler(id, latest || opts.Contains("queued"), latest);
                handlers[id] = h;
            }
            if (opts.Contains("released")) h.Released = true;      // released before it ever came here
            return h;
        }
    }

    /// handler~release: its later calls do nothing (and those queued go).
    public static void Release(int id)
    {
        lock (gate)
            if (handlers.TryGetValue(id, out var h)) h.Released = true;
        lock (queueGate)
        {
            for (var n = queue.First; n != null;)
            {
                var next = n.Next;
                if (n.Value.Handler.Id == id) queue.Remove(n);
                n = next;
            }
        }
    }

    public static bool IsDelegateType(Type t) =>
        typeof(Delegate).IsAssignableFrom(t) && t != typeof(Delegate) && t != typeof(MulticastDelegate);

    /// The delegate of type d for the handler (the same one every time).
    public static Delegate DelegateFor(RexxHandler h, Type d)
    {
        lock (gate)
        {
            if (delegates.TryGetValue((h.Id, d), out var del)) return del;
            del = Build(h, d);
            delegates[(h.Id, d)] = del;
            return del;
        }
    }

    static readonly MethodInfo callMethod = typeof(Callbacks).GetMethod(nameof(Call))!;

    // (p1, ..., pn) => (R)Callbacks.Call(h, new object[] { p1, ..., pn }, typeof(R))
    static Delegate Build(RexxHandler h, Type d)
    {
        var inv = d.GetMethod("Invoke") ?? throw new BridgeException($"{Types.Display(d)} has no Invoke method");
        var ps = inv.GetParameters();
        if (ps.Any(p => p.ParameterType.IsByRef || p.ParameterType.IsPointer || p.ParameterType.IsByRefLike) ||
            inv.ReturnType.IsByRef || inv.ReturnType.IsPointer || inv.ReturnType.IsByRefLike)
            throw new BridgeException($"a Rexx handler cannot be a {Types.Display(d)}: ref, out, pointer or span parameters are not supported");
        var pars = ps.Select(p => Expression.Parameter(p.ParameterType, p.Name)).ToArray();
        var args = Expression.NewArrayInit(typeof(object), pars.Select(p => (Expression)Expression.Convert(p, typeof(object))));
        Expression body = Expression.Call(callMethod, Expression.Constant(h), args, Expression.Constant(inv.ReturnType, typeof(Type)));
        if (inv.ReturnType != typeof(void)) body = Expression.Convert(body, inv.ReturnType);
        return Expression.Lambda(d, body, pars).Compile();
    }

    static object? Default(Type t) =>
        t == typeof(void) ? null : t == typeof(Task) ? Task.CompletedTask : t.IsValueType ? Activator.CreateInstance(t) : null;

    /// The body of every handler delegate. Public for the compiled
    /// expressions only.
    [EditorBrowsable(EditorBrowsableState.Never)]
    public static object? Call(RexxHandler h, object?[] args, Type ret)
    {
        if (h.Released) return Default(ret);
        if (h.Queued) { Enqueue(h, args); return Default(ret); }
        if (native == null) return Default(ret);

        var list = new Writer();
        foreach (var a in args) Conv.ToRexx(list, a);
        var w = new Writer();
        w.Add('A', list.ToArray());
        var req = w.ToArray();
        int len = 0;
        byte* resp;
        int flags = Bridge.Depth == 0 ? 1 : 0;              // 1: no Rexx caller waits on this thread
        fixed (byte* p = req) resp = native(h.Id, flags, p, req.Length, &len);
        GC.KeepAlive(args);                                 // RexxObject arguments (X) hold their Rexx objects until Rexx has them
        Rec r;
        try { r = Wire.Parse(new ReadOnlySpan<byte>(resp, len))[0]; }
        finally { nativeFree(resp); }

        switch (r.Tag)
        {
            case 'X': return Default(ret);
            case 'E': throw ToException(r.Text);
            case 'V':
                if (ret == typeof(void) || ret == typeof(object)) return null;
                if (ret == typeof(Task)) return Task.CompletedTask;
                throw new InvalidOperationException($"the Rexx handler returned nothing; its delegate needs a {Types.Display(ret)}");
        }
        if (ret == typeof(void)) return null;
        if (Conv.TryConvert(r, ret, out var v) == Conv.Fail)
            throw new InvalidCastException($"the Rexx handler returned \"{Conv.Describe(r)}\"; its delegate needs a {Types.Display(ret)}");
        return v;
    }

    // E: "conditionId\texceptionId\tname\tcode\trc\tline\tprogram\terrortext\ttraceback\tmessage"
    // (the traceback's lines joined by \n)
    static RexxException ToException(string payload)
    {
        var f = payload.Split('\t', 10);
        int exc = int.Parse(f[1]);
        Exception? inner = null;
        if (exc != 0) try { inner = Handles.Get(exc) as Exception; } catch (BridgeException) { }
        return new RexxException(f[9], inner, f[2], f[3], int.TryParse(f[4], out var rc) ? rc : 0, f[7], f[6],
                                 int.TryParse(f[5], out var line) ? line : 0, f[8], int.Parse(f[0]));
    }

    /// A RexxException in e's chain that rexxnet can raise again in Rexx.
    public static RexxException? RexxCause(Exception e)
    {
        for (Exception? x = e; x != null; x = x.InnerException)
            if (x is RexxException re && re.ConditionId > 0) return re;
        return null;
    }

    // ---------------------------------------------------------------- queue

    sealed record Pending(RexxHandler Handler, object?[] Args);
    static readonly object queueGate = new();
    static readonly LinkedList<Pending> queue = new();
    static int generation;

    /// A call of the handler, with no arguments, into the queue (whatever its options).
    internal static void Post(RexxHandler h) => Enqueue(h, Array.Empty<object?>());

    static void Enqueue(RexxHandler h, object?[] args)
    {
        lock (queueGate)
        {
            if (h.Latest)
                for (var n = queue.First; n != null; n = n.Next)
                    if (n.Value.Handler == h) { queue.Remove(n); break; }
            queue.AddLast(new Pending(h, args));
            Monitor.PulseAll(queueGate);
        }
    }

    /// The next queued call: A [S handler id, A arguments], or N when the
    /// time is over (seconds < 0: no limit) or, if gen >= 0, when
    /// .net~stopEventLoop has been called since generation gen.
    public static void NextEvent(double seconds, int gen, Writer w)
    {
        Pending? p = null;
        EventThread.LoopHere();                             // this thread serves the queue
        var deadline = seconds < 0 ? DateTime.MaxValue : DateTime.UtcNow.AddSeconds(seconds);
        lock (queueGate)
        {
            while (true)
            {
                if (gen >= 0 && gen != generation) break;
                if (ComEvents.HasPending) break;            // a COM event's handler failed here: its error goes up
                if (queue.First != null) { p = queue.First.Value; queue.RemoveFirst(); break; }
                if (seconds < 0) Monitor.Wait(queueGate);
                else
                {
                    var left = deadline - DateTime.UtcNow;
                    if (left <= TimeSpan.Zero) break;
                    Monitor.Wait(queueGate, left);
                }
            }
        }
        if (p == null) { w.Add('N', ""); return; }
        var args = new Writer();
        foreach (var a in p.Args) Conv.ToRexx(args, a);
        var pair = new Writer();
        pair.Add('S', p.Handler.Id.ToString());
        pair.Add('A', args.ToArray());
        w.Add('A', pair.ToArray());
    }

    /// Wakes the threads waiting in NextEvent (they look again).
    internal static void Wake()
    {
        lock (queueGate) Monitor.PulseAll(queueGate);
    }

    public static int Generation { get { lock (queueGate) return generation; } }

    public static void StopLoops()
    {
        lock (queueGate) { generation++; Monitor.PulseAll(queueGate); }
    }

    public static int QueuedCount { get { lock (queueGate) return queue.Count; } }
}
