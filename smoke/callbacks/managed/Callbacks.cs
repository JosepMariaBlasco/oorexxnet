// The managed side of the callbacks probe (08/10/2026): .NET code
// that calls back into Rexx, synchronously, in the three situations the
// design needs (notes/netobject-design.md, Callbacks):
//   Block       - the calling Rexx thread sits inside a long .NET call (as in
//                 Application.Run) while another .NET thread calls Rexx;
//   Sort        - re-entrancy: .NET calls Rexx back on the same thread that
//                 called .NET (a comparator);
//   StartAsync  - a .NET thread calls Rexx while Rexx code is running.
// The native side hands us its callback (Init); a callback takes a UTF-8
// argument and returns a UTF-8 answer, or a negative length on a Rexx error.
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

namespace CbProbe;

public static unsafe class Callbacks
{
    static delegate* unmanaged<byte*, byte*, int, int> rexxCallback;
    static int asyncDone;

    [UnmanagedCallersOnly]
    public static void Init(IntPtr callback) =>
        rexxCallback = (delegate* unmanaged<byte*, byte*, int, int>)callback;

    // Calls Rexx (the registered object's CALLBACK method) with arg; returns
    // its answer, or throws if Rexx raised an error.
    static string CallRexx(string arg)
    {
        var a = Encoding.UTF8.GetBytes(arg + "\0");
        var outBuf = new byte[4096];
        int n;
        fixed (byte* pa = a, po = outBuf) n = rexxCallback(pa, po, outBuf.Length);
        if (n < 0)
        {
            int len = Array.IndexOf(outBuf, (byte)0);
            throw new InvalidOperationException("Rexx: " + Encoding.UTF8.GetString(outBuf, 0, len < 0 ? 0 : len));
        }
        return Encoding.UTF8.GetString(outBuf, 0, n);
    }

    static int Answer(string s, IntPtr outBuf, int outLen, bool error = false)
    {
        var bytes = Encoding.UTF8.GetBytes(s);
        int n = Math.Min(bytes.Length, outLen - 1);
        Marshal.Copy(bytes, 0, outBuf, n);
        Marshal.WriteByte(outBuf, n, 0);
        return error ? -1 : n;
    }

    // Sleeps ms on the calling (Rexx) thread, as a GUI loop would, while a
    // second thread calls Rexx count times. Reports how many callbacks ended
    // while we were blocked, and the thread ids.
    [UnmanagedCallersOnly]
    public static int Block(int ms, int count, IntPtr outBuf, int outLen)
    {
        int done = 0;
        var answers = new List<string>();
        int caller = Environment.CurrentManagedThreadId, worker = 0;
        var t = new Thread(() =>
        {
            worker = Environment.CurrentManagedThreadId;
            for (int i = 1; i <= count; i++)
            {
                var r = CallRexx("block " + i);
                lock (answers) answers.Add(r);
                Interlocked.Increment(ref done);
            }
        });
        t.IsBackground = true;
        t.Start();
        Thread.Sleep(ms);                       // "Application.Run"
        int duringBlock = Volatile.Read(ref done);
        bool finished = t.Join(5000);
        string last; lock (answers) last = answers.Count > 0 ? answers[^1] : "";
        return Answer($"during={duringBlock} total={done} finished={finished} " +
                      $"otherThread={worker != caller} last={last}", outBuf, outLen);
    }

    // Sorts the words with a comparator that asks Rexx (same thread).
    [UnmanagedCallersOnly]
    public static int Sort(IntPtr words, IntPtr outBuf, int outLen)
    {
        try
        {
            var list = new List<string>(Marshal.PtrToStringUTF8(words)!.Split(' ', StringSplitOptions.RemoveEmptyEntries));
            list.Sort((a, b) => int.Parse(CallRexx("compare " + a + " " + b)));
            return Answer(string.Join(' ', list), outBuf, outLen);
        }
        catch (Exception e) { return Answer(e.GetType().Name + ": " + e.Message, outBuf, outLen, true); }
    }

    // Starts a thread that calls Rexx count times, every ms; returns at once.
    [UnmanagedCallersOnly]
    public static int StartAsync(int count, int ms)
    {
        Volatile.Write(ref asyncDone, 0);
        var t = new Thread(() =>
        {
            for (int i = 1; i <= count; i++)
            {
                Thread.Sleep(ms);
                CallRexx("async " + i);
                Interlocked.Increment(ref asyncDone);
            }
        });
        t.IsBackground = true;
        t.Start();
        return 0;
    }

    [UnmanagedCallersOnly]
    public static int AsyncDone() => Volatile.Read(ref asyncDone);

    // A callback whose Rexx side raises an error: the error comes back to .NET
    // as an exception, and from there to Rexx as an error of the call.
    [UnmanagedCallersOnly]
    public static int Fail(IntPtr outBuf, int outLen)
    {
        try { return Answer(CallRexx("fail"), outBuf, outLen); }
        catch (Exception e) { return Answer(e.GetType().Name + ": " + e.Message, outBuf, outLen, true); }
    }
}
