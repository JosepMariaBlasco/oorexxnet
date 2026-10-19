// .NET -> ooRexx, phase B: command environments (notes/rexx-from-net-design.md,
// Commands and I/O). rexx.AddCommandEnvironment("APP", handler): the Rexx code's
// ADDRESS APP 'command' calls handler(RexxCommand) on the Rexx thread; its
// result is RC.
//
// One fixed native entry (Entry, [UnmanagedCallersOnly]) for every
// environment of every instance, registered as a redirecting environment
// (ADDRESS ... WITH works): it finds the instance by its pointer and the
// handler by the address name. No delegate is ever handed to native code.
//
// While a handler runs, the exit context's thread context is the thread's
// current one for its instance (a frame on RexxInterpreter's stack): calls
// into Rexx from the handler run nested on that thread, as callbacks do.
//
// Conditions (ooRexx's RexxActivation::command): a handler result is RC
// (null: 0). A RexxCommandException raises ERROR (or FAILURE) with its RC; a
// RexxException that comes out of Rexx code the handler called is raised again
// as that SYNTAX error; any other .NET exception raises SYNTAX 98.900, as any
// .NET error reaching Rexx (additional: the message, the exception, its stack
// trace). A name removed (RemoveCommandEnvironment) answers FAILURE with RC
// 30, as ooRexx does for an environment that does not exist. Output and error
// written without WITH go to the console (Console.Out, Console.Error).
using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;

namespace Rexx.Net;

/// What a command handler or an application function gets (RexxCommand,
/// RexxFunctionCall): the instance and the calling Rexx code's variables.
/// Valid only while its handler runs.
public abstract class RexxCallContext
{
    readonly ExitCtx x;
    bool live = true;

    private protected RexxCallContext(RexxInterpreter rexx, ExitCtx x) { Interpreter = rexx; this.x = x; }

    /// The instance whose Rexx code made the call.
    public RexxInterpreter Interpreter { get; }

    internal void End() => live = false;

    private protected Ctx C
    {
        get
        {
            if (!live) throw new InvalidOperationException($"a {GetType().Name} is valid only while its handler runs");
            return x.Thread;
        }
    }

    // ------------------------------------------------------------ variables

    /// A variable of the calling Rexx code (null if it has no value, or is
    /// .nil). Names as Rexx writes them, uppercased: "X", "STEM.", "STEM.1".
    /// Setting null drops nothing: it sets .nil (Drop drops).
    public object? this[string name]
    {
        get
        {
            var c = C;
            nint v = x.GetVariable(name.ToUpperInvariant());
            return v == 0 ? null : RexxObject.Unwrap(Interpreter.Wrap(c, v));     // a .NetObject: its .NET object
        }
        set
        {
            var c = C;
            nint v = Interpreter.ToRexx(c, value);
            x.SetVariable(name.ToUpperInvariant(), v);
            if (RexxInterpreter.IsNewLocal(value)) c.ReleaseLocal(v);
        }
    }

    /// Whether the variable has a value.
    public bool HasVariable(string name)
    {
        var c = C;
        nint v = x.GetVariable(name.ToUpperInvariant());
        if (v == 0) return false;
        c.ReleaseLocal(v);
        return true;
    }

    /// Drops the variable (DROP).
    public void Drop(string name) { _ = C; x.DropVariable(name.ToUpperInvariant()); }

    /// Every variable of the calling Rexx code, by name (a copy).
    public IReadOnlyDictionary<string, object?> Variables
    {
        get
        {
            var c = C;
            using var all = (RexxObject)Interpreter.Wrap(c, x.AllVariables())!;
            return all.Supplier().ToDictionary(p => p.Key?.ToString() ?? "", p => p.Value);
        }
    }
}

/// A command sent to an ADDRESS environment of the application. Valid only
/// while its handler runs.
public sealed class RexxCommand : RexxCallContext
{
    readonly Redirector io;

    internal RexxCommand(RexxInterpreter rexx, ExitCtx x, Redirector io, string address, string command) : base(rexx, x)
    {
        this.io = io; Address = address; Command = command;
    }

    /// The environment as the Rexx code named it ("APP", or "app" from ADDRESS 'app').
    public string Address { get; }
    /// The command string.
    public string Command { get; }

    public override string ToString() => Command;
    /// The command string, so that a handler taking a string can be given the command.
    public static implicit operator string(RexxCommand c) => c.Command;

    // ---------------------------------------------------------- redirection

    /// Whether the command was sent with ADDRESS ... WITH.
    public bool IsRedirected { get { _ = C; return io.Requested; } }
    public bool IsInputRedirected { get { _ = C; return io.InputRedirected; } }
    public bool IsOutputRedirected { get { _ = C; return io.OutputRedirected; } }
    public bool IsErrorRedirected { get { _ = C; return io.ErrorRedirected; } }

    /// The next line of the redirected input (WITH INPUT); null at its end
    /// or when the input is not redirected.
    public string? ReadLine() { _ = C; return io.InputRedirected ? io.Read(false) : null; }

    /// The rest of the redirected input, its lines joined by "\n"; null when
    /// not redirected.
    public string? ReadToEnd()
    {
        _ = C;
        if (!io.InputRedirected) return null;
        var lines = new List<string>();
        for (string? l; (l = io.Read(false)) != null;) lines.Add(l);
        return string.Join("\n", lines);
    }

    /// A line to the redirected output (WITH OUTPUT); without it, to the
    /// console (Console.Out), as a program's output, and false.
    public bool WriteLine(string line) { _ = C; if (!io.OutputRedirected) { Console.Out.WriteLine(line); return false; } io.Write(false, false, line); return true; }

    /// Text to the redirected output, split into lines at its line ends.
    public bool Write(string text) { _ = C; if (!io.OutputRedirected) { Console.Out.Write(text); return false; } io.Write(false, true, text); return true; }

    /// A line, or text, to the redirected error stream (WITH ERROR); without
    /// it, to Console.Error, and false.
    public bool WriteErrorLine(string line) { _ = C; if (!io.ErrorRedirected) { Console.Error.WriteLine(line); return false; } io.Write(true, false, line); return true; }
    public bool WriteError(string text) { _ = C; if (!io.ErrorRedirected) { Console.Error.Write(text); return false; } io.Write(true, true, text); return true; }
}

/// Thrown by a command handler: raises ERROR (or FAILURE) in the Rexx code,
/// with Rc as RC and the message, if any, as condition("A").
public sealed class RexxCommandException : Exception
{
    /// RC (any value: a number, a string...).
    public object? Rc { get; }
    /// FAILURE (the command could not be run) rather than ERROR (it ran and failed).
    public bool Failure { get; }

    public RexxCommandException(object? rc, string? message = null, bool failure = false)
        : base(message ?? $"command {(failure ? "failure" : "error")}, RC {rc}")
    {
        Rc = rc; Failure = failure; HasMessage = message != null;
    }

    internal bool HasMessage { get; }
}

internal static unsafe class Commands
{
    internal const int Redirecting = 2;           // REDIRECTING_COMMAND_ENVIRONMENT

    internal static nint Address => (nint)(delegate* unmanaged<nint, nint, nint, nint, nint>)&Entry;

    [UnmanagedCallersOnly]
    static nint Entry(nint exitContext, nint address, nint command, nint redirector)
    {
        var x = new ExitCtx(exitContext);
        var c = x.Thread;
        RexxInterpreter? rexx = RexxInterpreter.Find(c.Instance);
        string addr = c.ToStr(address), text = c.ToStr(command);
        Func<RexxCommand, object?>? handler = rexx?.CommandHandler(addr);
        if (rexx == null || handler == null)
        {
            // removed (or never ours): as ooRexx answers an environment that does not exist
            nint notRegistered = c.Str("30");
            Raise(x, "FAILURE", command, null, notRegistered);
            return notRegistered;
        }
        var cmd = new RexxCommand(rexx, x, new Redirector(redirector), addr, text);
        rexx.PushFrame(c.P);
        try
        {
            object? r = handler(cmd);
            if (r == null) return 0;                              // RC 0
            return rexx.ToRexx(c, r);         // (a proxy's global reference: the proxy keeps the object alive)
        }
        catch (RexxCommandException e)
        {
            nint rc = Safe(rexx, c, e.Rc);
            Raise(x, e.Failure ? "FAILURE" : "ERROR", command, e.HasMessage ? e.Message : null, rc);
            return rc;
        }
        catch (Exception e) when ((RexxException.Raised(e) ?? Callbacks.RexxCause(e)) is RexxException called && called.Code.Length > 0)
        {
            // Rexx code that the handler called failed: the same error here
            // (on this handler's context, the innermost frame).
            if (!Callbacks.RaiseHeld(c.P, called)) RexxInterpreter.RaiseAgain(called);
            return 0;
        }
        catch (Exception e)
        {
            // any other error of the handler: SYNTAX 98.900, as a .NET error
            // reaching Rexx anywhere (additional: [1] the message, [2] the
            // exception, [3] its stack trace)
            while ((e is TargetInvocationException || e is TypeInitializationException) && e.InnerException != null)
                e = e.InnerException;
            string message = ".NET error: " + e.GetType().FullName + ": " + e.Message;
            if (message.EndsWith('.')) message = message[..^1];             // 98.900 adds its own
            nint a = c.NewArray(3);
            c.ArrayPut(a, c.Str(message), 1);
            c.ArrayPut(a, Safe(rexx, c, e), 2);
            c.ArrayPut(a, c.Str((e.StackTrace ?? "").Replace("\r", "")), 3);
            c.RaiseException(98900, a);
            return 0;
        }
        finally
        {
            cmd.End();
            rexx.PopFrame(c.P);
        }
    }

    static nint Safe(RexxInterpreter rexx, Ctx c, object? v)
    {
        try { return rexx.ToRexx(c, v); }
        catch (Exception) { return c.Str(Convert.ToString(v, System.Globalization.CultureInfo.InvariantCulture) ?? ""); }
    }

    static void Raise(ExitCtx x, string condition, nint command, string? message, nint rc)
    {
        var c = x.Thread;
        nint additional = message != null ? c.Str(message) : 0;
        c.RaiseCondition(condition, command, additional, rc);
    }
}
