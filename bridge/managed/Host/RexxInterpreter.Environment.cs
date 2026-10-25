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
// forwarder sends what Rexx writes to an internal application function
// (REXXNET.IO, not an ADDRESS environment), which writes it to the TextWriter
// (or reads the TextReader). Set back to
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

    // ooRexx's own command environments (.CommandHandler, RFE #882, r13288):
    // a handler of the application is a .NetCommandHandler (net.cls; a
    // .CommandHandler) registered with .CommandHandler~register, as Rexx code
    // registers one: it stacks over the handler in use and
    // .CommandHandler~deregister uncovers it; ~environments, ~handler and
    // ~handlers show it. ooRexx sends it command(command, caller); it calls
    // .NET (a request, as any .NET call from Rexx), and the handler gets the
    // command and caller as a RexxCommandContext. The table below holds the
    // delegates, by id (Bridge's cmdHandler / cmdRun / cmdRelease).

    const string CommandsSource = """
        -- Rexx.Net: the application's command environments, through ooRexx's
        -- own (.CommandHandler), with net.cls's .NetCommandHandler.
        ::requires "net.cls"
        ::routine register public            -- the handler covered, or .nil
          use strict arg name, handler       -- handler: the .NET delegate
          return .CommandHandler~register(name, .NetCommandHandler~new(handler))
        ::routine deregister public          -- the handler removed
          use strict arg name
          removed = .CommandHandler~deregister(name)
          if removed~isA(.NetCommandHandler) then do
            inUse = .false
            envs = .CommandHandler~environments
            do n over envs~allIndexes
              do h over .CommandHandler~handlers(n)
                if h == removed then inUse = .true    -- registered under another name too
              end
            end
            if \inUse then removed~release            -- its delegate released
          end
          return removed
        """;

    readonly Dictionary<int, Func<string, RexxCommandContext, object?>> commands = new();
    int lastCommand;
    readonly object commandsLock = new();
    (RexxRoutine Register, RexxRoutine Deregister)? commandRoutines;

    (RexxRoutine Register, RexxRoutine Deregister) CommandRoutines()
    {
        lock (commandsLock)
        {
            if (commandRoutines is { } m) return m;
            var routines = LoadPackage("Rexx.Net commands", CommandsSource).Routines;
            m = ((RexxRoutine)routines["REGISTER"]!, (RexxRoutine)routines["DEREGISTER"]!);
            commandRoutines = m;
            return m;
        }
    }

    /// An ADDRESS environment of the application: ADDRESS name 'command' (or
    /// ADDRESS name, then 'command') calls handler(command, context) on the
    /// Rexx thread, the context ooRexx's own .CommandContext
    /// (RexxCommandContext). Its result is RC (null: 0), whatever its sign;
    /// context.RaiseError(rc), RaiseFailure(rc) or Raise(...) raise a
    /// condition; any exception raises SYNTAX 98.900 (the exception is
    /// condition("O")~additional[2]). Names are not case-sensitive. As
    /// ooRexx's .CommandHandler~register (the handler is registered so, as a
    /// .NetCommandHandler): it covers the handler in use for that name,
    /// which RemoveCommandEnvironment uncovers; the covered handler's object
    /// is returned (null if none): its COMMAND method forwards to it.
    public RexxObject? AddCommandEnvironment(string name, Func<string, RexxCommandContext, object?> handler)
    {
        ArgumentException.ThrowIfNullOrEmpty(name);
        ArgumentNullException.ThrowIfNull(handler);
        if (disposed) throw new ObjectDisposedException(nameof(RexxInterpreter));
        return CommandRoutines().Register.Call(name, handler);
    }

    /// A handler with no result (RC 0).
    public RexxObject? AddCommandEnvironment(string name, Action<string, RexxCommandContext> handler)
    {
        ArgumentNullException.ThrowIfNull(handler);
        return AddCommandEnvironment(name, (c, x) => { handler(c, x); return null; });
    }

    /// Removes the handler in use for ADDRESS name, as ooRexx's
    /// .CommandHandler~deregister: any handler (the application's, one
    /// written in Rexx, a native one), uncovering the one it covered; with
    /// none left, ADDRESS name raises FAILURE with RC 30, as for an
    /// environment that does not exist. Returns the object removed. A name
    /// with no handler is an InvalidOperationException.
    public RexxObject RemoveCommandEnvironment(string name)
    {
        ArgumentException.ThrowIfNullOrEmpty(name);
        if (disposed) throw new ObjectDisposedException(nameof(RexxInterpreter));
        try { return CommandRoutines().Deregister.Call(name)!; }
        catch (RexxException e) when (e.Code == "93.900")
        {
            throw new InvalidOperationException($"there is no command environment {name} to remove", e);
        }
    }

    // The table (net.cls's .NetCommandHandler, through Bridge).
    internal int NewCommandHandler(Func<string, RexxCommandContext, object?> handler)
    {
        lock (commands) { int id = ++lastCommand; commands[id] = handler; return id; }
    }

    internal Func<string, RexxCommandContext, object?>? CommandHandler(int id)
    {
        lock (commands) return commands.TryGetValue(id, out var h) ? h : null;
    }

    internal void ReleaseCommandHandler(int id)
    {
        lock (commands) commands.Remove(id);
    }

    // ----------------------------------------------------------------- I/O

    const string IoFunction = "REXXNET.IO";

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
          r = 'REXXNET.IO'(command)
          busy = .false
          return r
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
        // an application function (RXOFNC), not an ADDRESS environment: Rexx
        // code does not see it among .CommandHandler~environments, nor can it
        // deregister it
        lock (functions) functions[IoFunction] = f => Io((string)(RexxString)f.Arguments[0]!) ?? "";
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
    object? Io(string s)
    {
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
    /// while the call runs, never Rexx code that comes after it. A halt
    /// reaches the thread's running Rexx code (its top Rexx frame); one sent
    /// before the call's first clause would be lost (ooRexx's Activity::halt
    /// with no Rexx frame does nothing, and says it did), so for a program or
    /// a routine (Run, Call, RunFile) the cancellation is also kept, and the
    /// RXINI exit, called right before the first clause, halts it there
    /// (HaltWatch). A method (Send) has no RXINI: a cancellation in that
    /// window is still lost.
    internal object? Cancellable(CancellationToken cancel, Func<object?> call)
    {
        if (!cancel.CanBeCanceled) return call();
        cancel.ThrowIfCancellationRequested();
        var watch = new HaltWatch(Native.CurrentThread());
        var outer = HaltWatch.Current;
        HaltWatch.Current = watch;
        using (cancel.Register(watch.Cancel))
        {
            try { return call(); }
            catch (RexxException e) when (watch.Halted && e.Code == "4.1")
            {
                throw new OperationCanceledException("the Rexx code was halted: the operation was cancelled", e, cancel);
            }
            finally { watch.End(); HaltWatch.Current = outer; }
        }
    }
}

/// A cancellable call's halt (RexxInterpreter.Cancellable). Cancel comes
/// from any thread; Started from RXINI, on the call's thread, before its
/// first clause. A halt sent while a halt is still pending is refused by
/// ooRexx (RexxActivation::halt), so the two never make two HALTs.
internal sealed class HaltWatch
{
    [ThreadStatic] internal static HaltWatch? Current;     // the innermost cancellable call on this thread
    readonly nuint thread;
    bool running = true, started, requested;
    volatile bool halted;

    internal HaltWatch(nuint thread) { this.thread = thread; }
    internal bool Halted => halted;

    internal void Cancel()
    {
        lock (this)
        {
            if (!running) return;
            requested = true;
            halted = true;
            Native.SetHalt(thread);         // lost if the first clause has not started: Started halts then
        }
    }

    internal void Started(Ctx c)
    {
        lock (this)
        {
            if (started) return;            // (later routines of the same call)
            started = true;
            if (requested && running) c.HaltThread();
        }
    }

    internal void End() { lock (this) running = false; }
}
