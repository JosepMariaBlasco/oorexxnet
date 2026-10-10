// The event thread, for .NetEventThread (net.cls: BSF4ooRexx's
// AbstractGUIThread for .NET; notes/netobject-design.md, "The event thread").
//
// With a user interface, the event thread is its thread: the first thread
// where a request runs with a UI SynchronizationContext installed (Windows
// Forms installs one when the first control is made on a thread; WPF's
// dispatcher, and others, do the same). "Later on the event thread" is then
// that context's Post, as JavaFX's Platform.runLater or Swing's
// invokeLater. Without one, the event thread is the Rexx thread that waits
// in .net~nextEvent / .net~eventLoop: Post queues a call of the handler in
// the queue that serves them.
using System;
using System.Threading;

namespace Rexx.Net;

static class EventThread
{
    static SynchronizationContext? ui;
    static int uiThread;
    static int loopThread;                                  // the last thread that waited in nextEvent

    /// A request on this thread: a UI context here, if none is known yet, is the event thread's.
    internal static void Notice()
    {
        if (ui != null) return;
        var sc = SynchronizationContext.Current;
        if (sc == null || sc.GetType() == typeof(SynchronizationContext)) return;   // the default one: no UI
        lock (typeof(EventThread))
        {
            if (ui != null) return;
            uiThread = Environment.CurrentManagedThreadId;
            ui = sc;
        }
    }

    internal static void LoopHere() => Volatile.Write(ref loopThread, Environment.CurrentManagedThreadId);

    internal static bool HasUi => ui != null;

    internal static bool IsEventThread =>
        Environment.CurrentManagedThreadId == (ui != null ? uiThread : Volatile.Read(ref loopThread));

    /// Calls the handler later on the event thread (with no arguments).
    internal static void Post(RexxHandler h)
    {
        if (ui is { } sc) sc.Post(_ => Callbacks.Call(h, Array.Empty<object?>(), typeof(void)), null);
        else Callbacks.Post(h);
    }
}
