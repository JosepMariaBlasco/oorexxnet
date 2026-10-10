// The event threads, for .NetEventThread (net.cls: BSF4ooRexx's
// AbstractGUIThread for .NET; notes/netobject-design.md, "The event thread").
//
// A user interface's thread is one where a request runs with a UI
// SynchronizationContext installed (Windows Forms installs one when the
// first control is made on a thread; WPF's dispatcher, and others, do the
// same). There may be several: each window belongs to the thread that made
// it. Each is known by its managed thread id, in the order they were seen;
// the first is the default event thread. "Later on an event thread" is its
// context's Post, as JavaFX's Platform.runLater or Swing's invokeLater.
// Without any, the event thread is the Rexx thread that waits in
// .net~nextEvent / .net~eventLoop (the "loop"): Post queues a call of the
// handler in the queue that serves them.
//
// Which UI thread an object belongs to: a WPF DispatcherObject's
// Dispatcher.Thread; a Windows Forms control's window's thread (Windows:
// GetWindowThreadProcessId, matched with the threads' native ids), once its
// window exists. Anything else: none (0), the default.
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;

namespace Rexx.Net;

static class EventThread
{
    sealed record Ui(int Id, uint NativeId, SynchronizationContext Context);

    static readonly List<Ui> uis = new();                   // in the order seen; uis[0]: the default
    static int loopThread;                                  // the last thread that waited in nextEvent

    /// A request on this thread: a UI context here, if this thread is not known yet, makes it a UI thread.
    [ThreadStatic] static bool noticed;                     // this thread is a known UI thread already

    internal static void Notice()
    {
        if (noticed) return;
        var sc = SynchronizationContext.Current;
        if (sc == null || sc.GetType() == typeof(SynchronizationContext)) return;   // the default one: no UI
        int id = Environment.CurrentManagedThreadId;
        lock (uis)
        {
            if (!uis.Any(u => u.Id == id)) uis.Add(new Ui(id, OperatingSystem.IsWindows() ? GetCurrentThreadId() : 0, sc));
        }
        noticed = true;
    }

    internal static void LoopHere() => Volatile.Write(ref loopThread, Environment.CurrentManagedThreadId);

    static Ui? Find(int id) { lock (uis) return uis.FirstOrDefault(u => u.Id == id); }
    static Ui? First() { lock (uis) return uis.Count > 0 ? uis[0] : null; }

    internal static bool HasUi => First() != null;

    /// The current thread: a UI thread's id, or 0.
    static int CurrentUi => Find(Environment.CurrentManagedThreadId)?.Id ?? 0;

    static bool IsLoopThread => Environment.CurrentManagedThreadId == Volatile.Read(ref loopThread);

    /// On an event thread: a UI thread, or (none known) the loop's.
    internal static bool IsEventThread => HasUi ? CurrentUi != 0 : IsLoopThread;

    /// "isEventThread kind currentUi isLoop": 1|0, ui|loop (the default's), this thread's UI id or 0,
    /// 1|0 (this thread waits in nextEvent).
    internal static string Describe() =>
        $"{(IsEventThread ? 1 : 0)} {(HasUi ? "ui" : "loop")} {CurrentUi} {(IsLoopThread ? 1 : 0)}";

    /// The UI threads' ids, in the order seen.
    internal static string Ids() { lock (uis) return string.Join(" ", uis.Select(u => u.Id)); }

    /// Calls the handler later on an event thread (with no arguments): where
    /// "ui": that UI thread (its id), 0 the default; "loop": the loop's.
    internal static void Post(RexxHandler h, string where)
    {
        Ui? ui = where == "loop" ? null
               : int.TryParse(where, out int id) && id != 0 ? Find(id) ?? throw new BridgeException($"no UI thread {id} is known")
               : First();
        if (ui != null) ui.Context.Post(_ => Callbacks.Call(h, Array.Empty<object?>(), typeof(void)), null);
        else Callbacks.Post(h);
    }

    /// The UI thread an object belongs to: its id, or 0 (not known: the default).
    internal static int Of(object? o)
    {
        if (o == null) return 0;
        try
        {
            // WPF (and anything with a Dispatcher whose Thread is known): DispatcherObject.Dispatcher.Thread
            for (var t = o.GetType(); t != null; t = t.BaseType)
                if (t.FullName == "System.Windows.Threading.DispatcherObject")
                {
                    var d = t.GetProperty("Dispatcher")?.GetValue(o);
                    if (d?.GetType().GetProperty("Thread")?.GetValue(d) is Thread th) return Find(th.ManagedThreadId)?.Id ?? 0;
                    return 0;
                }
            // Windows Forms: a control whose window exists (reading Handle before would create it here)
            if (OperatingSystem.IsWindows() && o is System.ComponentModel.ISynchronizeInvoke)
            {
                var type = o.GetType();
                if (type.GetProperty("IsHandleCreated")?.GetValue(o) is not true) return 0;
                var hp = type.GetProperty("HandleInternal", BindingFlags.Instance | BindingFlags.NonPublic)
                         ?? type.GetProperty("Handle");     // (Handle checks the thread under a debugger)
                if (hp?.GetValue(o) is not IntPtr hwnd || hwnd == IntPtr.Zero) return 0;
                uint native = GetWindowThreadProcessId(hwnd, IntPtr.Zero);
                lock (uis) return uis.FirstOrDefault(u => u.NativeId == native)?.Id ?? 0;
            }
        }
        catch (Exception) { }                               // not known: the default
        return 0;
    }

    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, IntPtr processId);
}
