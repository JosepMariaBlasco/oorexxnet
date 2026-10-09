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
// as that SYNTAX error; any other .NET exception raises FAILURE with RC -1 and
// the exception's message as condition("A").
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;

namespace Rexx.Net;

/// A command sent to an ADDRESS environment of the application. Valid only
/// while its handler runs.
public sealed class RexxCommand
{
    readonly ExitCtx x;
    readonly Redirector io;
    bool live = true;

    internal RexxCommand(RexxInterpreter rexx, ExitCtx x, Redirector io, string address, string command)
    {
        Interpreter = rexx; this.x = x; this.io = io; Address = address; Command = command;
    }

    /// The instance whose Rexx code sent the command.
    public RexxInterpreter Interpreter { get; }
    /// The environment as the Rexx code named it ("APP", or "app" from ADDRESS 'app').
    public string Address { get; }
    /// The command string.
    public string Command { get; }

    public override string ToString() => Command;
    /// The command string, so that a handler taking a string can be given the command.
    public static implicit operator string(RexxCommand c) => c.Command;

    internal void End() => live = false;

    Ctx C
    {
        get
        {
            if (!live) throw new InvalidOperationException("a RexxCommand is valid only while its handler runs");
            return x.Thread;
        }
    }

    // ------------------------------------------------------------ variables

    /// A variable of the Rexx code that sent the command (null if it has no
    /// value, or is .nil). Names as Rexx writes them, uppercased: "X", "STEM.",
    /// "STEM.1". Setting null drops nothing: it sets .nil (Drop drops).
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

    /// Every variable of the Rexx code that sent the command, by name (a copy).
    public IReadOnlyDictionary<string, object?> Variables
    {
        get
        {
            var c = C;
            using var all = (RexxObject)Interpreter.Wrap(c, x.AllVariables())!;
            return all.Supplier().ToDictionary(p => p.Key?.ToString() ?? "", p => p.Value);
        }
    }

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

    /// A line to the redirected output (WITH OUTPUT); false if the output is
    /// not redirected (nothing written).
    public bool WriteLine(string line) { _ = C; if (!io.OutputRedirected) return false; io.Write(false, false, line); return true; }

    /// Text to the redirected output, split into lines at its line ends.
    public bool Write(string text) { _ = C; if (!io.OutputRedirected) return false; io.Write(false, true, text); return true; }

    /// A line, or text, to the redirected error stream (WITH ERROR).
    public bool WriteErrorLine(string line) { _ = C; if (!io.ErrorRedirected) return false; io.Write(true, false, line); return true; }
    public bool WriteError(string text) { _ = C; if (!io.ErrorRedirected) return false; io.Write(true, true, text); return true; }
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
            Raise(x, "FAILURE", command, $"no handler for the environment {addr}", c.Str("-1"));
            return 0;
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
        catch (RexxException e) when (e.Code.Length > 0)
        {
            // Rexx code that the handler called failed: the same error here
            // (on this handler's context, the innermost frame).
            RexxInterpreter.RaiseAgain(e);
            return 0;
        }
        catch (Exception e)
        {
            nint rc = c.Str("-1");
            Raise(x, "FAILURE", command, e.Message, rc);
            return rc;
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
