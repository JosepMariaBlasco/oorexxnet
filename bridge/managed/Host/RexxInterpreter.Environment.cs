// .NET -> ooRexx, phase B: the Rexx code's environment (notes/rexx-from-net-
// design.md, Commands and I/O; "Phase B: built"): command environments, the
// Rexx code's input and output, cancellation.
//
// I/O. The Rexx code's output, error output (trace output and error messages
// included: .traceoutput writes to .error) and input go through the monitors
// .output, .error and .input of the instance's .local (SAY, LINEOUT / CHAROUT
// to the default streams and "STDERR", PULL, LINEIN, .output~lineout... all
// of them do). Setting Output, Error or Input puts a forwarder (a small Rexx
// object, the RexxNetStream class below) as the monitor's destination the
// first time; the forwarder sends what Rexx writes to an internal command
// environment, whose handler writes it to the TextWriter (or reads the
// TextReader). Set back to null, the forwarder passes everything to the
// stream it replaced. Only .stdout / .stderr / .stdin used directly, and
// processes started by ADDRESS SYSTEM, bypass it.
//
// Cancellation. Run, RunFile and RexxRoutine.Call take a CancellationToken:
// cancelling it halts the Rexx code on the calling thread (RexxSetHalt, the
// classic API, which may be called from any thread; HALT then ends the call,
// as Halt() does for every thread) and the call throws
// OperationCanceledException, its InnerException the RexxException (4.1).
// Rexx code that traps HALT itself decides: if it returns, the call returns.
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Threading;

namespace Rexx.Net;

public sealed partial class RexxInterpreter
{
    // ------------------------------------------------------------- instances

    static readonly ConcurrentDictionary<nint, RexxInterpreter> instances = new();

    /// The live instance with that RexxInstance pointer (native callbacks).
    internal static RexxInterpreter? Find(nint instance) => instances.TryGetValue(instance, out var r) ? r : null;

    // -------------------------------------------------- command environments

    readonly Dictionary<string, Func<RexxCommand, object?>> commands = new(StringComparer.OrdinalIgnoreCase);

    /// An ADDRESS environment of the application: ADDRESS name 'command' (or
    /// ADDRESS name, then 'command') calls handler on the Rexx thread. Its
    /// result is RC (null: 0). Throw RexxCommandException to raise ERROR or
    /// FAILURE; any other exception raises FAILURE (RC -1). Names are not
    /// case-sensitive; adding a name again replaces its handler.
    public void AddCommandEnvironment(string name, Func<RexxCommand, object?> handler)
    {
        ArgumentException.ThrowIfNullOrEmpty(name);
        ArgumentNullException.ThrowIfNull(handler);
        if (disposed) throw new ObjectDisposedException(nameof(RexxInterpreter));
        bool first;
        lock (commands) { first = !commands.ContainsKey(name); commands[name] = handler; }
        if (first) inst.AddCommandEnvironment(name, Commands.Address, Commands.Redirecting);
    }

    /// A handler with no result (RC 0).
    public void AddCommandEnvironment(string name, Action<RexxCommand> handler)
    {
        ArgumentNullException.ThrowIfNull(handler);
        AddCommandEnvironment(name, c => { handler(c); return null; });
    }

    internal Func<RexxCommand, object?>? CommandHandler(string name)
    {
        lock (commands) return commands.TryGetValue(name, out var h) ? h : null;
    }

    // ----------------------------------------------------------------- I/O

    const string IoEnvironment = "REXXNET.IO";

    const string IoSource = """
        -- Rexx.Net: the destination of .output, .error and .input when the
        -- application takes them (RexxInterpreter.Output, Error, Input).
        ::routine install public
          out = .RexxNetStream~new('O', .output~current)
          err = .RexxNetStream~new('E', .error~current)
          in  = .RexxNetStream~new('I', .input~current)
          .output~destination(out)
          .error~destination(err)
          .input~destination(in)
          return .array~of(out, err, in)

        ::class RexxNetStream
        ::attribute active
        ::method init
          expose kind orig active busy
          use strict arg kind, orig
          active = .false; busy = .false
        ::method lineout
          expose kind orig active busy
          if \active | busy then forward to (orig)
          if arg(1, 'O') then return self~io(kind'F')
          return self~io(kind'L'arg(1))     -- (concatenation: makeString first, as SAY does; a TraceObject is its line)
        ::method say
          expose kind orig active busy
          if \active | busy then forward to (orig)
          use arg line = ''
          return self~io(kind'L'line)
        ::method charout
          expose kind orig active busy
          if \active | busy then forward to (orig)
          if arg(1, 'O') then return self~io(kind'F')
          return self~io(kind'C'arg(1))
        ::method linein
          expose orig active busy
          if \active | busy then forward to (orig)
          return self~io('IL')
        ::method charin
          expose orig active busy
          if \active | busy then forward to (orig)
          return self~io('IC')
        ::method lines
          expose orig active busy
          if \active | busy then forward to (orig)
          return self~io('IN')
        ::method chars
          expose orig active busy
          if \active | busy then forward to (orig)
          return self~io('IN')
        ::method io private
          expose busy
          use arg command
          busy = .true
          address 'REXXNET.IO' command
          busy = .false
          return rc
        ::method unknown
          expose orig
          use arg name, args
          forward to (orig) message (name) arguments (args)
        """;

    readonly object ioLock = new();
    TextWriter? output, error;
    TextReader? input;
    volatile bool inputEnded;
    RexxObject? outStream, errStream, inStream;          // the forwarders

    /// Where the Rexx code's output goes (SAY, LINEOUT, CHAROUT, .output);
    /// null: the process's standard output.
    public TextWriter? Output { get => output; set => SetStream(0, value); }

    /// Where the Rexx code's error output goes (.error, "STDERR", trace
    /// output, error messages); null: the process's standard error.
    public TextWriter? Error { get => error; set => SetStream(1, value); }

    /// Where the Rexx code reads its input (PULL, PARSE PULL / LINEIN,
    /// LINEIN(), CHARIN(), .input); null: the process's standard input. At
    /// its end, reads give "" and LINES() 0.
    public TextReader? Input { get => input; set => SetStream(2, value); }

    void SetStream(int which, object? value)
    {
        if (disposed) throw new ObjectDisposedException(nameof(RexxInterpreter));
        lock (ioLock)
        {
            switch (which)
            {
                case 0: output = (TextWriter?)value; break;
                case 1: error = (TextWriter?)value; break;
                default: input = (TextReader?)value; inputEnded = false; break;
            }
            if (outStream == null)
            {
                if (value == null) return;
                AddCommandEnvironment(IoEnvironment, Io);
                var install = (RexxRoutine)LoadPackage("Rexx.Net I/O", IoSource).Routines["INSTALL"]!;
                var streams = install.Call()!;
                outStream = (RexxObject)streams[1]!; errStream = (RexxObject)streams[2]!; inStream = (RexxObject)streams[3]!;
            }
            var forwarder = which == 0 ? outStream : which == 1 ? errStream : inStream!;
            forwarder!.Send("ACTIVE=", value != null);
        }
    }

    // The forwarders' commands: O / E (output, error) + L (a line), C
    // (characters), F (flush); I (input) + L (a line), C (a character), N
    // (whether there is more).
    object? Io(RexxCommand command)
    {
        string s = command.Command;
        if (s.Length < 2) return null;
        string text = s.Substring(2);
        switch (s[0])
        {
            case 'O':
            case 'E':
                var w = s[0] == 'O' ? output : error;
                if (w == null) return null;
                switch (s[1])
                {
                    case 'L': w.WriteLine(text); break;
                    case 'C': w.Write(text); break;
                    case 'F': w.Flush(); break;
                }
                return null;
            case 'I':
                var r = input;
                if (r == null) return "";
                switch (s[1])
                {
                    case 'L':
                        var line = r.ReadLine();
                        if (line == null) { inputEnded = true; return ""; }
                        return line;
                    case 'C':
                        int ch = r.Read();
                        if (ch < 0) { inputEnded = true; return ""; }
                        return ((char)ch).ToString();
                    case 'N':
                        return inputEnded ? 0 : 1;
                }
                return "";
        }
        return null;
    }

    // --------------------------------------------------------- cancellation

    /// Run, halted if cancel is cancelled (OperationCanceledException). The
    /// source is compiled before the token is watched: a halt only reaches
    /// Rexx code already running (see Cancellable).
    public RexxObject? Run(string source, CancellationToken cancel, params object?[] args) =>
        (RexxObject?)RunCancellable(source, cancel, args);

    public T Run<T>(string source, CancellationToken cancel, params object?[] args) =>
        RexxConvert.To<T>(RunCancellable(source, cancel, args));

    object? RunCancellable(string source, CancellationToken cancel, object?[] args)
    {
        if (!cancel.CanBeCanceled) return RunRaw(source, args);
        cancel.ThrowIfCancellationRequested();
        using var routine = Compile("RexxInterpreter.Run", source);
        return Cancellable(cancel, () => routine.CallRaw(args));
    }

    /// RunFile, halted if cancel is cancelled (OperationCanceledException).
    public RexxObject? RunFile(string path, CancellationToken cancel, params object?[] args) =>
        (RexxObject?)Cancellable(cancel, () => RunFile(path, args));

    /// Runs call on this thread; if cancel is cancelled meanwhile, the Rexx
    /// code running on this thread is halted. The registration only halts
    /// while the call runs (the gate), never Rexx code that comes after it.
    /// A halt reaches the thread's running Rexx code (its top Rexx frame):
    /// one sent before the call's first clause runs is lost (ooRexx's
    /// Activity::halt with no Rexx frame does nothing). That window is the
    /// call's start: microseconds for Run and Call (compiled before), the
    /// file's compilation for RunFile.
    internal object? Cancellable(CancellationToken cancel, Func<object?> call)
    {
        if (!cancel.CanBeCanceled) return call();
        cancel.ThrowIfCancellationRequested();
        nuint thread = Native.CurrentThread();
        var gate = new object();
        bool running = true, halted = false;
        using (cancel.Register(() => { lock (gate) if (running) { halted = true; Native.SetHalt(thread); } }))
        {
            try { return call(); }
            catch (RexxException e) when (Volatile.Read(ref halted) && e.Code == "4.1")
            {
                throw new OperationCanceledException("the Rexx code was halted: the operation was cancelled", e, cancel);
            }
            finally { lock (gate) running = false; }
        }
    }
}
