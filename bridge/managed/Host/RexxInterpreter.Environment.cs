// .NET -> ooRexx, phase B: the Rexx code's environment (notes/rexx-from-net-
// design.md, Commands and I/O; "Phase B: built"): command environments, the
// Rexx code's input and output, cancellation.
//
// I/O. The Rexx code's output, error output (trace output and error messages
// included: .traceoutput writes to .error) and input go through the monitors
// .output, .error and .input of the instance's .local (SAY, LINEOUT / CHAROUT
// to the default streams and "STDERR", PULL, LINEIN, .output~lineout... all
// of them do), and .traceOutput / .debugInput. Setting Output, Error or Input,
// or StreamPrefixes, puts a forwarder (a small Rexx object, the RexxNetStream
// class below) as each monitor's destination the first time; an active
// forwarder sends what Rexx writes to an internal command environment, whose
// handler writes it to the TextWriter (or reads the TextReader). Set back to
// null, the forwarder passes everything to the stream it replaced, with
// BSF4ooRexx's prefix when StreamPrefixes is on ("REXXout>" ...; a prompt
// "REXXin?>" before a line is read). Only .stdout / .stderr / .stdin used
// directly, and processes started by ADDRESS SYSTEM, bypass it.
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
using System.Linq;
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
    readonly HashSet<string> nativeCommands = new(StringComparer.OrdinalIgnoreCase);   // added to ooRexx (never removed there)

    /// An ADDRESS environment of the application: ADDRESS name 'command' (or
    /// ADDRESS name, then 'command') calls handler on the Rexx thread. Its
    /// result is RC (null: 0), whatever its sign. Throw RexxCommandException
    /// to raise ERROR or FAILURE; any other exception raises SYNTAX 98.900
    /// (the exception is condition("O")~additional[2]). Names are not
    /// case-sensitive; adding a name again replaces its handler.
    public void AddCommandEnvironment(string name, Func<RexxCommand, object?> handler)
    {
        ArgumentException.ThrowIfNullOrEmpty(name);
        ArgumentNullException.ThrowIfNull(handler);
        if (disposed) throw new ObjectDisposedException(nameof(RexxInterpreter));
        bool first;
        lock (commands) { commands[name] = handler; first = nativeCommands.Add(name); }
        if (first) inst.AddCommandEnvironment(name, Commands.Address, Commands.Redirecting);
    }

    /// Removes an environment added by AddCommandEnvironment: ADDRESS name
    /// then raises FAILURE with RC 30, as for an environment that does not
    /// exist (ooRexx has no way to remove one: its entry stays, and answers
    /// so). A name with no handler is an InvalidOperationException.
    public void RemoveCommandEnvironment(string name)
    {
        ArgumentException.ThrowIfNullOrEmpty(name);
        if (disposed) throw new ObjectDisposedException(nameof(RexxInterpreter));
        lock (commands)
            if (!commands.Remove(name))
                throw new InvalidOperationException($"there is no command environment {name} to remove");
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
        -- Rexx.Net: the destinations of .output, .error, .traceOutput, .input
        -- and .debugInput: to the application's TextWriter / TextReader when
        -- it takes them (RexxInterpreter.Output, Error, Input; "active"), else
        -- to the streams they replaced, with BSF4ooRexx's prefixes when set
        -- (RexxInterpreter.StreamPrefixes; .output~current~prefix = .nil, or
        -- any other string, from Rexx).
        ::routine install public
          out = .RexxNetStream~new('O', .output~current)
          err = .RexxNetStream~new('E', .error~current)
          trc = .RexxNetStream~new('E', .error~current)      -- what .error wrote to, with its own prefix
          in  = .RexxNetStream~new('I', .input~current, out)
          dbg = .RexxNetStream~new('I', .input~current, out)
          .output~destination(out)
          .error~destination(err)
          .traceOutput~destination(trc)
          .input~destination(in)
          .debugInput~destination(dbg)
          return .array~of(out, err, trc, in, dbg)

        ::class RexxNetStream
        ::attribute active
        ::attribute prefix
        ::method init
          expose kind orig echo active busy prefix atStart
          use strict arg kind, orig, echo = .nil     -- echo: input only, the output its prompt goes to
          active = .false; busy = .false; prefix = .nil; atStart = .true
        ::method lineout
          expose kind orig active busy prefix atStart
          if busy then forward to (orig)
          if active then do
            if arg(1, 'O') then return self~io(kind'F')
            return self~io(kind'L'arg(1))   -- (concatenation: makeString first, as SAY does; a TraceObject is its line)
          end
          if arg(1, 'O') | prefix == .nil then forward to (orig)
          return orig~lineout(self~prefixed(arg(1), .true))
        ::method say
          expose kind orig active busy prefix
          if busy then forward to (orig)
          use arg line = ''
          if active then return self~io(kind'L'line)
          if prefix == .nil then forward to (orig)
          return orig~say(self~prefixed(line, .true))
        ::method charout
          expose kind orig active busy prefix
          if busy then forward to (orig)
          if active then do
            if arg(1, 'O') then return self~io(kind'F')
            return self~io(kind'C'arg(1))
          end
          if arg(1, 'O') | arg(2, 'E') | prefix == .nil then forward to (orig)
          text = '' || arg(1)
          if text == '' then forward to (orig)
          return orig~charout(self~prefixed(text, .false))
        ::method prefixed private            -- the prefix at the start of every line
          expose prefix atStart
          use arg text, wholeLine
          text = '' || text
          ends = wholeLine | text~right(1) == '0a'x
          if \wholeLine & ends then text = text~left(text~length - 1)
          text = text~changeStr('0a'x, '0a'x || prefix)
          if atStart then text = prefix || text
          if \wholeLine & ends then text = text || '0a'x
          atStart = ends
          return text
        ::method prompt                      -- an input's prompt, on its own line's start
          expose orig active atStart
          use arg text
          if active then return
          orig~charout(text)
          atStart = .true                    -- (the line typed ends it)
        ::method linein
          expose orig echo active busy prefix
          if busy then forward to (orig)
          if active then return self~io('IL')
          if prefix \== .nil, echo \== .nil then echo~prompt(prefix)
          forward to (orig)
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

    static readonly string[] prefixes = { "REXXout>", "REXXerr>", "REXXtrc>", "REXXin?>", "REXXdbgIn?>" };

    readonly object ioLock = new();
    TextWriter? output, error;
    TextReader? input;
    volatile bool inputEnded;
    bool streamPrefixes;
    RexxObject[]? streams;                  // the destinations: output, error, trace, input, debug input

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

    /// BSF4ooRexx's prefixes on the standard streams the application has not
    /// taken: "REXXout>", "REXXerr>", "REXXtrc>" at the start of each line,
    /// the prompts "REXXin?>" and "REXXdbgIn?>" before a line is read (see
    /// RexxOptions.StreamPrefixes, true by default for Create). Rexx code can
    /// change one: .output~current~prefix = .nil (none) or another string.
    public bool StreamPrefixes
    {
        get => streamPrefixes;
        set
        {
            if (disposed) throw new ObjectDisposedException(nameof(RexxInterpreter));
            if (guest) throw new InvalidOperationException("an instance ooRexx made (guest mode): its streams are its own");
            lock (ioLock)
            {
                streamPrefixes = value;
                if (streams == null && !value) return;
                for (int i = 0; i < 5; i++) Streams()[i].Send("PREFIX=", value ? prefixes[i] : null);
            }
        }
    }

    // The destinations, installed the first time they are needed (under ioLock).
    RexxObject[] Streams()
    {
        if (streams != null) return streams;
        AddCommandEnvironment(IoEnvironment, Io);
        var install = (RexxRoutine)LoadPackage("Rexx.Net I/O", IoSource).Routines["INSTALL"]!;
        var all = install.Call()!;
        return streams = Enumerable.Range(1, 5).Select(i => (RexxObject)all[i]!).ToArray();
    }

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
            if (streams == null && value == null) return;
            var s = Streams();
            bool on = value != null;
            switch (which)
            {
                case 0: s[0].Send("ACTIVE=", on); break;
                case 1: s[1].Send("ACTIVE=", on); s[2].Send("ACTIVE=", on); break;
                default: s[3].Send("ACTIVE=", on); s[4].Send("ACTIVE=", on); break;
            }
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
